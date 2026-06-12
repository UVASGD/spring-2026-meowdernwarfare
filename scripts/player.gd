class_name Player
extends CharacterBody2D

## Core player: movement, dash, status effects, damage, death/respawn/spectate.
## UI lives in PlayerHud (scripts/player/player_hud.gd), crop interaction in
## PlayerCrops (scripts/player/player_crops.gd); both get `self` injected.

const HudScript = preload("res://scripts/player/player_hud.gd")
const CropsScript = preload("res://scripts/player/player_crops.gd")

@export var player_id: int = 0

# Movement tuning
@export var max_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1800.0
@export var sprint_mult: float = 1.5

# Dash tuning
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8

# Rotation
@export var rotation_speed: float = 15.0
@export var rotation_offset: float = -PI/2 

var input: InputProvider = null
var hero: Hero = null
var hud = null  # PlayerHud
var crops = null  # PlayerCrops

# Node refs shared with components / heroes
var health_bar: Control = null
var camera: Camera2D = null

# State
var aim_dir: Vector2 = Vector2.RIGHT
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO

# Status effects
var is_drugged: bool = false
var drug_timer: float = 0.0
var is_marked: bool = false
var marked_timer: float = 0.0
var is_blinded: bool = false
var blind_timer: float = 0.0
var is_stunned: bool = false
var stun_timer: float = 0.0

# FIE suppression (incremented/decremented by FIE zones)
var fie_suppress_count: int = 0

# Crop state (manipulated by PlayerCrops and GameManager)
var crop_count: int = 0
var held_crop: Crop = null
var farm = null

# Meta states
var in_spectate_mode: bool = false
var is_ai_player: bool = false
var is_awaiting_respawn: bool = false
var is_dying: bool = false
var respawn_countdown: float = 0.0
var is_invulnerable: bool = false
var _suppress_shoot_until_release := false
const FARM_RADIUS := 600.0
var last_attacker: Player = null

signal took_damage(amount: float)
signal died
signal dashed

# Hero name -> Hero scene path mapping
const HERO_SCENE_PATHS = {
	"Dealer": "res://scenes/heroes/dealer/dealer.tscn",
	"Burple": "res://scenes/heroes/burple/burple.tscn",
	"LoanShark": "res://scenes/heroes/loanshark/loanshark.tscn",
	"Gooblin": "res://scenes/heroes/gooblin/gooblin.tscn",
	"Garebare": "res://scenes/heroes/garebare/garebare.tscn",
	"AnimeGirl": "res://scenes/heroes/animegirl/animegirl.tscn",
	"XylerFergus": "res://scenes/heroes/xylerfergus/xylerfergus.tscn",
	"ElonMusk": "res://scenes/heroes/elonmusk/elonmusk.tscn",

	# Backward-compat names
	"Anime Girl": "res://scenes/heroes/animegirl/animegirl.tscn",
	"Xyler and Fergus": "res://scenes/heroes/xylerfergus/xylerfergus.tscn",
	"Elon. Musk.": "res://scenes/heroes/elonmusk/elonmusk.tscn",
	"Alien": "res://scenes/heroes/animegirl/animegirl.tscn",
	"Xyler": "res://scenes/heroes/xylerfergus/xylerfergus.tscn",
	"Fergus": "res://scenes/heroes/xylerfergus/xylerfergus.tscn",
}

func _ready() -> void:
	add_to_group("players")
	
	# Default input for testing
	if input == null:
		var local = LocalInput.new(player_id, player_id == 0)
		local.set_player_node(self)
		input = local

	health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.top_level = true
	camera = get_node_or_null("Camera2D")
	
	hud = HudScript.new(self)
	crops = CropsScript.new(self)
	
	# Default hero for testing
	if hero == null:
		set_hero(TestConfig.DEFAULT_HERO)
	
	# Camera/UI only for local human players
	hud.setup_local_ui()
	hud.setup_nametag()

func set_hero(hero_name: String) -> void:
	var prev = hero
	if hero:
		hud.unbind_hero_ui_signals(hero)
		hero.queue_free()
		hero = null
	
	var hero_scene := _load_hero_scene(hero_name)
	if hero_scene == null:
		push_warning("Unknown hero: ", hero_name, ", defaulting to Dealer")
		hero_scene = _load_hero_scene("Dealer")
		if hero_scene == null:
			push_error("Failed to load fallback hero scene Dealer")
			return

	var inst = hero_scene.instantiate()
	if inst == null or not (inst is Hero):
		push_error("Failed to instantiate hero '%s', defaulting to Dealer" % hero_name)
		if hero_name != "Dealer":
			var dealer_scene := _load_hero_scene("Dealer")
			if dealer_scene:
				inst = dealer_scene.instantiate()
		if inst == null or not (inst is Hero):
			push_error("Failed to instantiate fallback hero Dealer")
			return

	hero = inst as Hero
	hero.player = self
	add_child(hero)

	hero.died.connect(_on_hero_died)
	hero.health_changed.connect(_on_hero_health_changed)
	hero.used_ult.connect(_on_hero_used_ult)
	
	var hitbox = get_node_or_null("CollisionShape2D")
	if hitbox:
		hitbox.shape = hero.get_hitbox_shape()

	hud.on_hero_changed(prev)

func _load_hero_scene(hero_name: String) -> PackedScene:
	var path := String(HERO_SCENE_PATHS.get(hero_name, ""))
	if path.is_empty():
		return null
	var res := load(path)
	if res == null:
		push_error("Failed to load hero scene path '%s' for hero '%s'" % [path, hero_name])
		return null
	if not (res is PackedScene):
		push_error("Hero scene path '%s' is not a PackedScene for hero '%s'" % [path, hero_name])
		return null
	return res as PackedScene

func _physics_process(delta: float) -> void:
	if input == null:
		return
	
	var is_local = _is_local_player()
	
	input.update(delta)
	
	if in_spectate_mode:
		if is_local:
			_handle_spectate_movement(delta)
			move_and_slide()
		input.end_frame()
		return
	
	if is_awaiting_respawn:
		respawn_countdown -= delta
		hud.update_death_timer(respawn_countdown)
		input.end_frame()
		return

	if is_dying:
		velocity = Vector2.ZERO
		hud.refresh_world_health_bar()
		input.end_frame()
		return
	
	_update_timers(delta)
	
	if is_local:
		_handle_movement(delta)
		move_and_slide()
	
	_handle_rotation(delta)
	var consumed_shoot: bool = crops.handle(delta)
	_handle_actions(consumed_shoot)
	
	hud.physics_update(delta)
	
	if is_invulnerable:
		_check_farm_invulnerability()
	
	input.end_frame()

func _update_timers(delta: float) -> void:
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	
	if drug_timer > 0:
		drug_timer -= delta
		if drug_timer <= 0:
			_end_drug_effect()

	if blind_timer > 0:
		blind_timer -= delta
		if blind_timer <= 0:
			_end_blind_effect()

	# Marked effect (Loan Shark)
	if marked_timer > 0:
		marked_timer -= delta
		if marked_timer <= 0:
			clear_mark_effect()

	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false

func _handle_movement(delta: float) -> void:
	if is_stunned:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		return

	if is_dashing:
		velocity = dash_dir * dash_speed
		return

	var hero_mult = hero.move_speed_mult if hero else 1.0
	var speed = max_speed * hero_mult * (sprint_mult if input.sprint else 1.0)
	
	var move = input.move_input
	if is_drugged:
		move = -move  # Invert movement when drugged
	
	if move.length() > 0.1:
		velocity = velocity.move_toward(move * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _handle_rotation(delta: float) -> void:
	if input.aim_input.length() > 0.1:
		var aim = input.aim_input.normalized()
		if is_drugged:
			aim = -aim  # Invert aim when drugged
		aim_dir = aim
	
	var target_rot = aim_dir.angle() + rotation_offset
	rotation = lerp_angle(rotation, target_rot, rotation_speed * delta)

func _handle_actions(consumed_shoot := false) -> void:
	if consumed_shoot:
		_suppress_shoot_until_release = true
	if _suppress_shoot_until_release:
		if not input.shoot:
			_suppress_shoot_until_release = false
		else:
			consumed_shoot = true
	if consumed_shoot:
		# Strip the consumed click so the outgoing network packet doesn't make
		# remote peers simulate a shot that never happened here.
		input.shoot = false
		input.shoot_just = false
	if is_stunned:
		if hero and input.ult_just:
			hero.ult(aim_dir, get_aim_position())
		return

	if is_dying or is_dead():
		return

	# Dash (disabled for heroes that only use ability-based dashes, e.g. Loan Shark)
	if input.dash_just and dash_cd_timer <= 0 and not is_dashing:
		if hero == null or hero.allows_movement_dash():
			_start_dash()
	
	if hero == null:
		return
	
	# Delegate to hero
	if input.shoot and not consumed_shoot:
		hero.shoot(aim_dir, get_aim_position())
	if input.ability1_just:
		hero.ability1(aim_dir, get_aim_position())
	if input.ability2_just:
		hero.ability2(aim_dir, get_aim_position())
	if input.ult_just:
		hero.ult(aim_dir, get_aim_position())
	if input.reload_just and hero.uses_gun_ammo():
		hero.reload()

func _start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cd_timer = dash_cooldown
	dash_dir = aim_dir if input.move_input.length() < 0.1 else input.move_input.normalized()
	dashed.emit()

func _on_hero_died() -> void:
	clear_mark_effect()
	print("[PLAYER] _on_hero_died: pid=", player_id, " crop_count=", crop_count, " is_local=", _is_local_player())
	died.emit()
	is_dying = true
	velocity = Vector2.ZERO
	hud.refresh_world_health_bar()
	await _wait_for_death_anim()
	is_dying = false
	if crop_count <= 0:
		enter_spectate_mode()
	else:
		_enter_death_state()

func _wait_for_death_anim() -> void:
	if hero == null or hero.sprite == null or hero.sprite.sprite_frames == null:
		return
	if not hero.sprite.sprite_frames.has_animation("death"):
		return
	if String(hero.sprite.animation) != "death":
		hero.sprite.play("death")
	if hero.sprite.sprite_frames.get_animation_loop("death"):
		return
	if hero.sprite.is_playing():
		await hero.sprite.animation_finished

func _on_hero_health_changed(_current: float, _max_hp: float) -> void:
	hud.update_health_bar()

func _on_hero_used_ult() -> void:
	var gm = GameManager.instance
	if gm:
		gm.notify_ult_used(player_id)

# --- PUBLIC API ---

func get_aim_direction() -> Vector2:
	return aim_dir

func get_aim_position() -> Vector2:
	if input:
		return input.aim_position
	return global_position + aim_dir * 100

func is_moving() -> bool:
	return input != null and input.move_input.length() > 0.1

## Returns whether damage was applied (false if dead, invulnerable, dashing with i-frames, etc.).
func take_damage(amount: float, attacker: Player = null) -> bool:
	if is_dead() or in_spectate_mode or is_awaiting_respawn or is_invulnerable:
		return false
	if is_dashing:
		on_bullet_dodged()
		return false
	
	if hero:
		if attacker:
			last_attacker = attacker
		hero.take_damage(amount)
		took_damage.emit(amount)
		if attacker and attacker.hero:
			attacker.hero.add_ult_points(attacker.hero.ult_points_on_hit)
		return true
	return false

func on_bullet_dodged() -> void:
	if hero:
		hero.add_ult_points(hero.ult_points_on_dodge)

func heal(amount: float) -> void:
	if hero:
		hero.heal(amount)

func get_health() -> float:
	return hero.health if hero else 0.0

func get_max_health() -> float:
	return hero.max_health if hero else 100.0

func get_health_percent() -> float:
	return hero.get_health_percent() if hero else 0.0

func is_dead() -> bool:
	return hero.is_dead if hero else true

# --- CROP FACADE (state shared with GameManager; behavior in PlayerCrops) ---

func pickup_world_crop(crop: Crop) -> void:
	crops.pickup_world_crop(crop)

func drop_held_crop() -> void:
	crops.drop_held_crop()

func set_remote_held_crop(type_id: String, stg: int) -> void:
	crops.set_remote_held_crop(type_id, stg)

func clear_remote_held_crop() -> void:
	crops.clear_remote_held_crop()

# --- STATUS EFFECTS ---

func apply_drug_effect(duration: float) -> void:
	is_drugged = true
	drug_timer = duration
	if _is_local_player():
		hud.show_drug_overlay()

func _end_drug_effect() -> void:
	is_drugged = false
	drug_timer = 0.0
	hud.hide_drug_overlay()

func apply_blind_effect(duration: float) -> void:
	is_blinded = true
	blind_timer = duration
	if _is_local_player():
		hud.show_blind_overlay()

func _end_blind_effect() -> void:
	is_blinded = false
	blind_timer = 0.0
	hud.hide_blind_overlay()

func apply_mark_effect(duration: float) -> void:
	is_marked = true
	marked_timer = duration
	hud.refresh_mark_indicator()

## Clears Loan Shark mark (timer, UI). Safe to call when not marked.
func clear_mark_effect() -> void:
	if not is_marked:
		return
	is_marked = false
	marked_timer = 0.0
	hud.refresh_mark_indicator()

func spawn_mark_projectile_hit_fx() -> void:
	hud.spawn_mark_projectile_hit_fx()

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = max(stun_timer, duration)

# ---------- Death / Respawn ----------

func _enter_death_state() -> void:
	is_awaiting_respawn = true
	respawn_countdown = 10.0
	
	hud.hide_for_death()
	if held_crop:
		drop_held_crop()
	crops.set_pickup_enabled(false)
	_disable_collision()
	if hero:
		hero.enter_spectate_mode()
	
	if _is_local_player():
		hud.show_death_timer()

func respawn_at(pos: Vector2) -> void:
	is_dying = false
	is_awaiting_respawn = false
	respawn_countdown = 0.0
	
	global_position = pos
	
	if hero:
		hero.health = hero.max_health
		hero.is_dead = false
		hero.health_changed.emit(hero.health, hero.max_health)
		var hero_sprite = hero.get_node_or_null("Sprite")
		if hero_sprite:
			hero_sprite.visible = true
	
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", false)
	
	crops.set_pickup_enabled(true)
	hud.on_respawn()
	
	is_invulnerable = true
	hud.update_health_bar()

func _check_farm_invulnerability() -> void:
	if farm == null:
		is_invulnerable = false
		return
	if global_position.distance_to(farm.global_position) > FARM_RADIUS:
		is_invulnerable = false

# ---------- Spectate Mode ----------

const SPECTATE_SPEED := 500.0

func _handle_spectate_movement(delta: float) -> void:
	var move = input.move_input
	if move.length() > 0.1:
		velocity = move * SPECTATE_SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func enter_spectate_mode() -> void:
	print("[PLAYER] enter_spectate_mode: pid=", player_id, " already=", in_spectate_mode, " is_local=", _is_local_player(), " game_over=", GameManager.instance.game_over if GameManager.instance else "no_gm")
	if in_spectate_mode:
		return
	is_dying = false
	in_spectate_mode = true
	
	hud.hide_for_death()
	
	# Drop any held crop back into the world
	if held_crop:
		drop_held_crop()
	
	crops.set_pickup_enabled(false)
	_disable_collision()
	
	if hero:
		hero.enter_spectate_mode()
	
	var gm = GameManager.instance
	if _is_local_player() and (gm == null or not gm.game_over):
		hud.show_elimination_ui()

func clear_elimination_ui() -> void:
	hud.clear_elimination_ui()

func _disable_collision() -> void:
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

func _is_local_player() -> bool:
	if input is LocalInput:
		return player_id == 0
	elif input is NetworkInput:
		return input.is_local
	return false

## True when this peer controls the player (always true offline, including AI/bots;
## online only for the owning client). Remote copies are input-driven simulations.
func is_locally_controlled() -> bool:
	if input is NetworkInput:
		return input.is_local
	return true
