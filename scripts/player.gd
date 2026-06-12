class_name Player
extends CharacterBody2D

## Core player: movement, dash, ability targeting, status effects, crop buffs,
## damage, death/respawn/spectate. UI lives in PlayerHud, crop interaction in
## PlayerCrops; both get `self` injected in _ready().

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
var hud: PlayerHud = null
var crops: PlayerCrops = null
# Spawners can pre-set this to override the default hero used in _ready(),
# avoiding a wasted instantiate-then-replace cycle.
var pending_hero: String = ""

# Node refs shared with components / heroes
var health_bar: Control = null
var camera: Camera2D = null

const MarkProjectileHitFxScene = preload("res://scenes/heroes/loanshark/mark_projectile_hit_fx.tscn")
const XylerSlashFxScene = preload("res://scenes/heroes/xylerfergus/xyler_slash_fx.tscn")
const BurpleTargetScene = preload("res://scenes/heroes/burple/grenade_target.tscn")
const SfxEvent = preload("res://scripts/audio/sfx_event.gd")
const SfxBus = preload("res://scripts/audio/sfx_bus.gd")

# State
var aim_dir: Vector2 = Vector2.RIGHT
const TARGET_NONE := ""
const TARGET_A1 := "a1"
const TARGET_ULT := "ult"
var _target_mode := TARGET_NONE
var _target_marker: Sprite2D = null
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO

# Drug effect state
var is_drugged: bool = false
var drug_timer: float = 0.0

# Loan Shark Mark 
var is_marked: bool = false
var marked_timer: float = 0.0
# Blind effect state
var is_blinded: bool = false
var blind_timer: float = 0.0

# Stun state
var is_stunned: bool = false
var stun_timer: float = 0.0

# FIE suppression (incremented/decremented by FIE zones)
var fie_suppress_count: int = 0

# Crop state (manipulated by PlayerCrops and GameManager)
var crop_count: int = 0
var held_crop: Crop = null
var drop_cd: float = 0.0
const DROP_CD_TIME := 0.5
var farm = null
var _crop_shoot_cd_pct: float = 0.0
var _crop_a1_cd_pct: float = 0.0
var _crop_ult_req_pct: float = 0.0
var _crop_mag_pct: float = 0.0
var _crop_heal_on_hit: float = 0.0
var _crop_rush_px_per_point: float = 0.0
var _crop_hypno_dps: float = 0.0
var _crop_hypno_radius: float = 0.0
var _crop_acid_resist: float = 0.0
var _crop_star_slow_pct: float = 0.0
var _crop_star_radius: float = 0.0
var _rush_dist_acc: float = 0.0
var _rush_prev_pos: Vector2 = Vector2.ZERO
var _base_shoot_cd: float = 0.0
var _base_a1_cd: float = 0.0
var _base_ult_max: int = 1
var _base_mag: int = 1

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
	
	# Camera follows only local players
	camera = get_node_or_null("Camera2D")
	
	hud = PlayerHud.new(self)
	crops = PlayerCrops.new(self)
	
	# Default hero for testing (or whatever the spawner pre-selected)
	if hero == null:
		var first_hero := pending_hero if pending_hero != "" else TestConfig.DEFAULT_HERO
		pending_hero = ""
		set_hero(first_hero)
	
	# Enable camera/UI only for local human players
	hud.setup_local_ui()
	hud.setup_ability_icon_text_ui()
	crops.setup()
	hud.setup_nametag()
	_rush_prev_pos = global_position

func set_hero(hero_name: String) -> void:
	var prev = hero
	_set_target_mode(TARGET_NONE)
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
	
	# Update hitbox if we have one
	var hitbox = get_node_or_null("CollisionShape2D")
	if hitbox:
		hitbox.shape = hero.get_hitbox_shape()

	hud.notify_hero_changed(prev)
	_cache_crop_base_stats()
	_apply_crop_hero_stats()
	
	hud.refresh_ability2_charge_ui_visibility()
	hud.refresh_movement_dash_ui_visibility()
	hud.refresh_gun_ui_visibility()

func _load_hero_scene(hero_name: String) -> PackedScene:
	var res := HeroRegistry.load_scene(hero_name)
	if res == null:
		push_error("Failed to load hero scene for hero '%s'" % hero_name)
		return null
	return res as PackedScene

# --- DELEGATES (UI in PlayerHud, crops in PlayerCrops; kept for external callers) ---

func _refresh_world_health_bar() -> void:
	hud.refresh_world_health_bar()

func _refresh_hero_ui() -> void:
	hud.refresh_hero_ui()

func clear_elimination_ui() -> void:
	hud.clear_elimination_ui()

func pickup_world_crop(crop: Crop) -> void:
	crops.pickup_world_crop(crop)

func drop_held_crop() -> void:
	crops.drop_held_crop()

func can_receive_held_crop() -> bool:
	return crops.can_receive_held_crop()

func get_any_held_crop_data() -> Dictionary:
	return crops.get_any_held_crop_data()

func force_clear_held_crop_local() -> void:
	crops.force_clear_held_crop_local()

func receive_stolen_crop(type_id: String, stg: int) -> void:
	crops.receive_stolen_crop(type_id, stg)

func set_remote_held_crop(type_id: String, stg: int) -> void:
	crops.set_remote_held_crop(type_id, stg)

func clear_remote_held_crop() -> void:
	crops.clear_remote_held_crop()

func _physics_process(delta: float) -> void:
	if input == null:
		return
	
	var is_local = _is_local_player()
	var physics_owner = _is_physics_owner()
	
	input.update(delta)
	
	if in_spectate_mode:
		if is_local:
			_handle_spectate_movement(delta)
			move_and_slide()
		input.end_frame()
		return
	
	if is_awaiting_respawn:
		_update_death_countdown(delta)
		input.end_frame()
		return

	if is_dying:
		velocity = Vector2.ZERO
		_refresh_world_health_bar()
		input.end_frame()
		return
	
	_update_timers(delta)
	
	if physics_owner:
		_handle_movement(delta)
		move_and_slide()
		_process_rush_room(delta)
		_process_hypnoflower(delta)
	
	_handle_rotation(delta)
	_update_target_marker()
	var consumed_shoot := crops.handle(delta)
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
	
	if drop_cd > 0:
		drop_cd -= delta
	
	# Drug effect timer
	if drug_timer > 0:
		drug_timer -= delta
		if drug_timer <= 0:
			_end_drug_effect()

	# Blind effect timer
	if blind_timer > 0:
		blind_timer -= delta
		if blind_timer <= 0:
			_end_blind_effect()

	# Marked effect (Loan Shark)
	if marked_timer > 0:
		marked_timer -= delta
		if marked_timer <= 0:
			_end_marked_effect()

	# Stun timer
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
	var star_slow = _get_star_slow_factor()
	speed *= max(0.05, 1.0 - star_slow)
	
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
		# Strip the spent click before the end-of-frame network send, so the
		# host's sim of this player doesn't fire a shot that never happened here.
		input.shoot = false
		input.shoot_just = false

	if hero and _target_mode != TARGET_NONE:
		if input.shoot_just:
			var pos := _get_target_pos()
			var dir := pos - global_position
			if dir.length_squared() > 0.01:
				aim_dir = dir.normalized()
			var mode := _target_mode
			_set_target_mode(TARGET_NONE)
			if mode == TARGET_A1:
				hero.ability1(aim_dir, pos)
			elif mode == TARGET_ULT:
				hero.ult(aim_dir, pos)
			_suppress_shoot_until_release = true
			return
		if input.reload_just or input.drop_just:
			_set_target_mode(TARGET_NONE)
			return
		if _target_mode == TARGET_A1 and input.ability1_just:
			_set_target_mode(TARGET_NONE)
			return
		if _target_mode == TARGET_ULT and input.ult_just:
			_set_target_mode(TARGET_NONE)
			return

	if is_stunned:
		if hero and input.ult_just:
			if hero.uses_ult_targeting():
				_set_target_mode(TARGET_ULT if hero.can_ult() else TARGET_NONE)
			else:
				hero.ult(aim_dir, get_aim_position())
		return

	if is_dying or is_dead():
		return

	# Dash (disabled for heroes that only use ability-based dashes, e.g. Loan Shark)
	if input.dash_just:
		if dash_cd_timer <= 0 and not is_dashing and not is_dead():
			if hero == null or hero.allows_movement_dash():
				_start_dash()
		elif _is_local_player():
			_play_skill_cd_blocked()
	
	if hero == null:
		return

	if hero.uses_ability1_targeting() and input.ability1_just:
		_set_target_mode(TARGET_NONE if _target_mode == TARGET_A1 else (TARGET_A1 if hero.can_ability1() else TARGET_NONE))
		return
	if hero.uses_ult_targeting() and input.ult_just:
		_set_target_mode(TARGET_NONE if _target_mode == TARGET_ULT else (TARGET_ULT if hero.can_ult() else TARGET_NONE))
		return

	if _is_local_player():
		if input.shoot_just and not consumed_shoot and not hero.can_shoot():
			_play_skill_cd_blocked()
		if input.ability1_just and not hero.can_ability1():
			_play_skill_cd_blocked()
		if input.ability2_just and hero.has_hero_ability2() and not hero.can_ability2():
			_play_skill_cd_blocked()
		if input.ult_just and not hero.can_ult():
			_play_skill_cd_blocked()
		if input.reload_just and hero.uses_gun_ammo() and (hero.reload_cd > 0.0 or hero.ammo >= hero.mag_size):
			_play_skill_cd_blocked()
	
	# Delegate to hero
	if input.shoot and not consumed_shoot:
		hero.shoot(aim_dir, get_aim_position())
	if input.ability1_just:
		hero.ability1(aim_dir, get_aim_position())
	if input.ability2_just and hero.has_hero_ability2():
		hero.ability2(aim_dir, get_aim_position())
	if input.ult_just:
		hero.ult(aim_dir, get_aim_position())
	if input.reload_just and hero.uses_gun_ammo():
		hero.reload()

func _play_skill_cd_blocked() -> void:
	SfxBus.play_ui(SfxEvent.UI_SKILL_ON_CD)

func _start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cd_timer = dash_cooldown
	dash_dir = aim_dir if input.move_input.length() < 0.1 else input.move_input.normalized()
	SfxBus.play_world(SfxEvent.PLAYER_DASH, global_position)
	dashed.emit()

func _on_hero_died() -> void:
	_set_target_mode(TARGET_NONE)
	clear_mark_effect()
	died.emit()
	is_dying = true
	velocity = Vector2.ZERO
	_refresh_world_health_bar()
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

func _on_hero_health_changed(current: float, max_hp: float) -> void:
	_update_health_bar()

func _on_hero_used_ult() -> void:
	var gm = GameManager.instance
	if gm == null:
		return
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

## Returns whether the hit was host-authoritatively applied.
## Non-host callers emit a local flinch but return `false` so downstream side effects (mark clear,
## cooldown refresh, chomp VFX for Loan Shark's dash) don't fire on peers that can't confirm the hit.
## Those side effects are replayed on clients via host-driven broadcasts.
func take_damage(amount: float, attacker: Player = null) -> bool:
	if is_dead() or in_spectate_mode or is_awaiting_respawn or is_invulnerable:
		return false
	if is_dashing:
		on_bullet_dodged()
		return false
	if hero == null:
		return false
	
	var gm = GameManager.instance
	var host_auth = gm == null or gm.is_host()
	
	if not host_auth:
		took_damage.emit(amount)
		SfxBus.play_world(SfxEvent.PLAYER_HURT, global_position)
		return false
	
	if attacker:
		last_attacker = attacker
	hero.take_damage(amount)
	took_damage.emit(amount)
	SfxBus.play_world(SfxEvent.PLAYER_HURT, global_position)
	if attacker and attacker.hero:
		attacker.hero.add_ult_points(attacker.hero.ult_points_on_hit)
		if attacker._crop_heal_on_hit > 0.0:
			attacker.heal(attacker._crop_heal_on_hit)
	return true

func take_acid_damage(amount: float, attacker: Player = null) -> bool:
	var mult = max(0.0, 1.0 - _crop_acid_resist)
	return take_damage(amount * mult, attacker)

func on_bullet_dodged() -> void:
	var gm = GameManager.instance
	if gm != null and not gm.is_host():
		return
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

func _update_health_bar() -> void:
	hud.update_health_bar()

func _get_target_pos() -> Vector2:
	if hero == null:
		return get_aim_position()
	var pos := get_aim_position()
	var range := _get_target_range()
	if range <= 0:
		return pos
	var off := pos - global_position
	if off.length() <= range:
		return pos
	return global_position + off.normalized() * range

func _get_target_range() -> float:
	if hero == null:
		return 0.0
	if _target_mode == TARGET_A1:
		return hero.get_ability1_range()
	if _target_mode == TARGET_ULT:
		return hero.get_ult_range()
	return 0.0

func _set_target_mode(mode: String) -> void:
	# Target mode is a purely local decision (aim-reticle UX). Remote sims must never enter it,
	# otherwise the host re-fires hero.ability1 / hero.ult when shoot_just arrives, on top of
	# the owning client's own request -> duplicate casts. See sync_bugs #1/#2.
	if not _is_local_player():
		return
	if _target_mode == mode:
		return
	var prev := _target_mode
	_target_mode = mode
	if hero and prev != TARGET_NONE and hero.has_method("target_mode_cancelled"):
		hero.target_mode_cancelled(prev)
	if hero and _target_mode != TARGET_NONE and hero.has_method("target_mode_started"):
		hero.target_mode_started(_target_mode)
	if _target_mode != TARGET_NONE:
		_ensure_target_marker()
		Cursor.switch_mode("GRENADE")
		Cursor.enable()
		_update_target_marker()
	else:
		if _target_marker:
			_target_marker.visible = false
		Cursor.switch_mode("BATTLE")

func _ensure_target_marker() -> void:
	if _target_marker:
		return
	_target_marker = BurpleTargetScene.instantiate() as Sprite2D
	if _target_marker == null:
		return
	_target_marker.top_level = true
	_target_marker.visible = false
	add_child(_target_marker)

func _update_target_marker() -> void:
	if _target_mode == TARGET_NONE or not _is_local_player():
		if _target_marker:
			_target_marker.visible = false
		return
	_ensure_target_marker()
	if _target_marker == null:
		return
	_target_marker.visible = true
	_target_marker.global_position = _get_target_pos()

const INTERACT_RANGE := 400.0
const UPROOT_RANGE := INTERACT_RANGE / 3.0
const TILE_HALF := 80.0

func _has_damage_authority() -> bool:
	var gm = GameManager.instance
	return gm == null or gm.is_host()

func _cache_crop_base_stats() -> void:
	if hero == null:
		return
	_base_shoot_cd = hero.shoot_cooldown
	_base_a1_cd = hero.ability1_cooldown
	_base_ult_max = max(1, hero.max_ult_points)
	_base_mag = max(1, hero.mag_size)

func _apply_crop_hero_stats() -> void:
	if hero == null:
		return
	if _base_shoot_cd <= 0.0:
		_cache_crop_base_stats()
	var shoot_mult = max(0.1, 1.0 - _crop_shoot_cd_pct)
	var a1_mult = max(0.1, 1.0 - _crop_a1_cd_pct)
	var ult_mult = max(0.1, 1.0 - _crop_ult_req_pct)
	var mag_mult = max(0.1, 1.0 + _crop_mag_pct)
	hero.shoot_cooldown = max(0.02, _base_shoot_cd * shoot_mult)
	hero.ability1_cooldown = max(0.05, _base_a1_cd * a1_mult)
	hero.max_ult_points = max(1, int(round(_base_ult_max * ult_mult)))
	hero.mag_size = max(1, int(round(_base_mag * mag_mult)))
	if hero.ammo > hero.mag_size:
		hero.ammo = hero.mag_size
	if hero.ult_points > hero.max_ult_points:
		hero.ult_points = hero.max_ult_points
		hero.ult_changed.emit(hero.ult_points, hero.max_ult_points)

func mod_crop_stat(stat: String, delta: float) -> void:
	match stat:
		"shoot_cd_pct":
			_crop_shoot_cd_pct = max(0.0, _crop_shoot_cd_pct + delta)
			_apply_crop_hero_stats()
		"ability1_cd_pct":
			_crop_a1_cd_pct = max(0.0, _crop_a1_cd_pct + delta)
			_apply_crop_hero_stats()
		"ult_req_pct":
			_crop_ult_req_pct = max(0.0, _crop_ult_req_pct + delta)
			_apply_crop_hero_stats()
		"mag_pct":
			_crop_mag_pct = max(0.0, _crop_mag_pct + delta)
			_apply_crop_hero_stats()
		"heal_on_hit":
			_crop_heal_on_hit = max(0.0, _crop_heal_on_hit + delta)
		"rush_pts_per_300":
			# Backward compatibility for older crop stat key.
			_crop_rush_px_per_point = max(0.0, _crop_rush_px_per_point + delta)
		"rush_px_per_point":
			_crop_rush_px_per_point = max(0.0, _crop_rush_px_per_point + delta)
		"hypno_dps":
			_crop_hypno_dps = max(0.0, _crop_hypno_dps + delta)
		"hypno_radius":
			_crop_hypno_radius = max(0.0, _crop_hypno_radius + delta)
		"acid_resist":
			_crop_acid_resist = clamp(_crop_acid_resist + delta, 0.0, 0.95)
		"star_slow_pct":
			_crop_star_slow_pct = clamp(_crop_star_slow_pct + delta, 0.0, 0.95)
		"star_radius":
			_crop_star_radius = max(0.0, _crop_star_radius + delta)

func _process_rush_room(_delta: float) -> void:
	if hero == null or _crop_rush_px_per_point <= 0.0 or not _has_damage_authority():
		if _crop_rush_px_per_point <= 0.0:
			_rush_dist_acc = 0.0
		_rush_prev_pos = global_position
		return
	var moved = global_position.distance_to(_rush_prev_pos)
	_rush_prev_pos = global_position
	if moved <= 0.0:
		return
	_rush_dist_acc += moved
	var threshold: float = maxf(1.0, _crop_rush_px_per_point)
	var pulses = int(floor(_rush_dist_acc / threshold))
	if pulses <= 0:
		return
	_rush_dist_acc -= float(pulses) * threshold
	hero.add_ult_points(pulses)

func _process_hypnoflower(delta: float) -> void:
	if _crop_hypno_dps <= 0.0 or _crop_hypno_radius <= 0.0 or not _has_damage_authority():
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not (p is Player) or not is_instance_valid(p) or p.is_dead():
			continue
		if p.global_position.distance_to(global_position) > _crop_hypno_radius:
			continue
		p.take_damage(_crop_hypno_dps * delta, self)

func _get_star_slow_factor() -> float:
	var slow := 0.0
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not (p is Player) or not is_instance_valid(p):
			continue
		if p.is_dead() or p._crop_star_slow_pct <= 0.0 or p._crop_star_radius <= 0.0:
			continue
		if global_position.distance_to(p.global_position) <= p._crop_star_radius:
			slow = max(slow, p._crop_star_slow_pct)
	return slow

# --- DRUG EFFECT ---

func apply_drug_effect(duration: float) -> void:
	is_drugged = true
	drug_timer = duration
	
	if hud.should_show_local_ui():
		hud.show_drug_overlay()

func _end_drug_effect() -> void:
	is_drugged = false
	drug_timer = 0.0
	hud.hide_drug_overlay()

# --- MARKED EFFECT (LOAN SHARK) ---

func apply_mark_effect(duration: float) -> void:
	is_marked = true
	marked_timer = duration
	hud.refresh_mark_indicator()

func _end_marked_effect() -> void:
	clear_mark_effect()

## Clears Loan Shark mark (timer, UI). Safe to call when not marked.
func clear_mark_effect() -> void:
	if not is_marked:
		return
	is_marked = false
	marked_timer = 0.0
	hud.refresh_mark_indicator()

## World-space pop when Loan Shark's mark projectile connects (visible to all players).
func spawn_mark_projectile_hit_fx() -> void:
	var fx: Node2D = MarkProjectileHitFxScene.instantiate()
	add_child(fx)
	fx.global_position = global_position + Vector2(0, -72)

## World-space Xyler attack animation when Fergus's mark threshold procs.
func spawn_xyler_slash_fx() -> void:
	var fx: Node2D = XylerSlashFxScene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position


# --- BLIND EFFECT ---

func apply_blind_effect(duration: float) -> void:
	is_blinded = true
	blind_timer = duration
	
	if hud.should_show_local_ui():
		hud.show_blind_overlay()

func _end_blind_effect() -> void:
	is_blinded = false
	blind_timer = 0.0
	hud.hide_blind_overlay()

# --- STUN ---

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = max(stun_timer, duration)


# ---------- Death / Respawn ----------

func _enter_death_state() -> void:
	_set_target_mode(TARGET_NONE)
	is_awaiting_respawn = true
	respawn_countdown = 10.0
	
	hud.hide_world_ui()
	if held_crop:
		drop_held_crop()
	crops.set_pickup_enabled(false)
	_disable_collision()
	if hero:
		hero.enter_spectate_mode()
	
	if _is_local_player():
		hud.show_death_timer()

func _update_death_countdown(delta: float) -> void:
	respawn_countdown -= delta
	hud.update_death_timer(respawn_countdown)

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
	_update_health_bar()
	SfxBus.play_world(SfxEvent.PLAYER_RESPAWN, global_position)

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
	if in_spectate_mode:
		return
	_set_target_mode(TARGET_NONE)
	is_dying = false
	in_spectate_mode = true
	
	hud.hide_world_ui()
	
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

## True on peers that own this body's physics. In LOCAL mode every player runs locally; in
## ONLINE_HOST the host simulates all players from streamed inputs; in ONLINE_CLIENT only the
## local player is simulated and remotes are interpolated from state_sync.
func _is_physics_owner() -> bool:
	var gm = GameManager.instance
	if gm == null:
		return _is_local_player()
	if gm.mode == GameManager.Mode.ONLINE_HOST:
		return true
	return _is_local_player()

func _on_spectate_pressed() -> void:
	clear_elimination_ui()
