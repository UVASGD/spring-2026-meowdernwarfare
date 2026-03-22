class_name Player
extends CharacterBody2D

# Use self.input.X to get input

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

# UI
var health_bar: Control = null
var health_bar_fill: ColorRect = null
var camera: Camera2D = null
var cooldown_ui: CanvasLayer = null
var shoot_cd_bar: ProgressBar = null
var ability1_cd_bar: ProgressBar = null
var ability2_cd_bar: ProgressBar = null
var ability2_charge_bar_1: ProgressBar = null
var ability2_charge_bar_2: ProgressBar = null
var loan_shark_charge_row: Control = null
var reload_cd_bar: ProgressBar = null
var dash_cd_bar: ProgressBar = null
var ammo_label: Label = null
var ult_bar: ProgressBar = null
var ult_label: Label = null
var tooltip_layer: CanvasLayer = null
var tooltip_label: RichTextLabel = null
var nametag: Label = null
var mark_indicator: CanvasItem = null

const MarkProjectileHitFxScene = preload("res://scenes/heroes/loanshark/mark_projectile_hit_fx.tscn")
const _ULT_BANNER_PORTRAIT_SHADER = preload("res://assets/shaders/electric_wrap.gdshader")

@onready var local_health_bar = $CooldownUI/HealthBar
var target_health_bar_value : float;
var target_health_bar_color : Color = Color.WHITE;;
@onready var local_health_bar_label = $CooldownUI/HealthBar/Label

@onready var ability_1_bar = $CooldownUI/Ability1
@onready var ability_1_icon = $CooldownUI/Ability1/TextureRect
@onready var ability_1_animation = $CooldownUI/Ability1/AnimationPlayer

@onready var ability_2_bar = $CooldownUI/Ability2
@onready var ability_2_icon = $CooldownUI/Ability2/TextureRect

@onready var character_profile = $CooldownUI/Profile
@onready var ult_percent_label = $CooldownUI/Profile/Label
var _profile_base_pos: Vector2 = Vector2.ZERO
var _ult_ready_mat: ShaderMaterial
var _ui_bound_hero: Hero = null

@onready var reload_bar = $HealthBar/ReloadBar
@onready var reload_bar_animation = $HealthBar/ReloadBar/AnimationPlayer
@onready var reload_bar_finish_animation = $HealthBar/ReloadBar/Finish

@onready var reload_prompt = $HealthBar/ReloadPrompt
@onready var reload_prompt_animation = $HealthBar/ReloadPrompt/AnimationPlayer

@onready var ammo_left = $HealthBar/AmmoLeft
@onready var ammo_left_animation = $HealthBar/AmmoLeft/AnimationPlayer





# State
var aim_dir: Vector2 = Vector2.RIGHT
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO

# Drug effect state
var is_drugged: bool = false
var drug_timer: float = 0.0
var drug_effect_layer: CanvasLayer = null
var drug_effect_rect: ColorRect = null

# Loan Shark Mark 
var is_marked: bool = false
var marked_timer: float = 0.0
# Blind effect state
var is_blinded: bool = false
var blind_timer: float = 0.0
var blind_effect_layer: CanvasLayer = null
var blind_effect_rect: ColorRect = null

# Stun state
var is_stunned: bool = false
var stun_timer: float = 0.0

# FIE suppression (incremented/decremented by FIE zones)
var fie_suppress_count: int = 0

# Crop state
var crop_count: int = 0
var held_crop: Crop = null
var drop_cd: float = 0.0
const DROP_CD_TIME := 0.5
var held_sprite: Sprite2D = null
var _remote_held_sprite: Sprite2D = null
var _remote_held_type: String = ""
var farm = null

# Meta states
var in_spectate_mode: bool = false
var is_ai_player: bool = false
var is_awaiting_respawn: bool = false
var is_dying: bool = false
var _show_aux_ui: bool = false
var respawn_countdown: float = 0.0
var _death_ui: CanvasLayer = null
var _death_timer_label: Label = null
var is_invulnerable: bool = false
var _suppress_shoot_until_release := false
const FARM_RADIUS := 600.0
var last_attacker: Player = null

signal took_damage(amount: float)
signal died
signal dashed

#debug 

var reasonable_timer = 0.0
var reasonable_timer_max = 1.0
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
	_profile_base_pos = character_profile.position
	_ult_ready_mat = ShaderMaterial.new()
	_ult_ready_mat.shader = _ULT_BANNER_PORTRAIT_SHADER
	_ult_ready_mat.set_shader_parameter("edge_px", 2.2)
	_ult_ready_mat.set_shader_parameter("glow_strength", 1.4)
	_ult_ready_mat.set_shader_parameter("speed", 1.5)
	_ult_ready_mat.set_shader_parameter("noise_scale", 48.0)
	_ult_ready_mat.set_shader_parameter("pulse", 0.35)
	_ult_ready_mat.set_shader_parameter("progress", 1.0)
	_ult_ready_mat.set_shader_parameter("edge_width", 0.05)
	_ult_ready_mat.set_shader_parameter("edge_color", Color(1.0, 0.5, 0.1, 1.0))
	_ult_ready_mat.set_shader_parameter("edge_color_inner", Color(1.0, 0.9, 0.3, 1.0))
	_ult_ready_mat.set_shader_parameter("alpha_cutoff", 0.01)
	add_to_group("players")
	
	# Default input for testing
	if input == null:
		var local = LocalInput.new(player_id, player_id == 0)
		local.set_player_node(self)
		input = local

	health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.top_level = true
		health_bar_fill = health_bar.get_node_or_null("Fill")
		mark_indicator = health_bar.get_node_or_null("MarkIndicator")
	
	# Camera follows only local players
	camera = get_node_or_null("Camera2D")
	
	# Cooldown UI
	cooldown_ui = get_node_or_null("CooldownUI")
	if cooldown_ui:
		var container = cooldown_ui.get_node_or_null("Container")
		if container:
			shoot_cd_bar = container.get_node_or_null("ShootCD/Bar")
			ability1_cd_bar = container.get_node_or_null("Ability1CD/Bar")
			ability2_cd_bar = container.get_node_or_null("Ability2CD/Bar")
			loan_shark_charge_row = container.get_node_or_null("Ability2CD/LoanSharkCharges")
			ability2_charge_bar_1 = container.get_node_or_null("Ability2CD/LoanSharkCharges/Charge1")
			ability2_charge_bar_2 = container.get_node_or_null("Ability2CD/LoanSharkCharges/Charge2")
			reload_cd_bar = container.get_node_or_null("ReloadCD/Bar")
			dash_cd_bar = container.get_node_or_null("DashCD/Bar")
			ammo_label = container.get_node_or_null("Ammo/Count")
			ult_bar = container.get_node_or_null("UltCD/Bar")
			ult_label = container.get_node_or_null("UltCD/Count")
	
	# Default hero for testing
	if hero == null:
		set_hero(TestConfig.DEFAULT_HERO)
	
	# Enable camera/UI only for local human players
	_setup_local_ui()
	_setup_crop_area()
	_setup_nametag()

func set_hero(hero_name: String) -> void:
	var prev = hero
	if hero:
		_unbind_hero_ui_signals(hero)
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

	if prev == _ui_bound_hero:
		_ui_bound_hero = null
	if _should_show_local_ui():
		_bind_hero_ui_signals(hero)
		_refresh_hero_ui()
	
	_refresh_ability2_charge_ui_visibility()
	_refresh_movement_dash_ui_visibility()
	_refresh_gun_ui_visibility()

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

func _refresh_gun_ui_visibility() -> void:
	if hero == null:
		return
	var gun := hero.uses_gun_ammo()
	if cooldown_ui:
		var c := cooldown_ui.get_node_or_null("Container")
		if c:
			var rc := c.get_node_or_null("ReloadCD")
			if rc:
				rc.visible = gun and _show_aux_ui
			var am := c.get_node_or_null("Ammo")
			if am:
				am.visible = gun and _show_aux_ui
	if reload_bar:
		reload_bar.visible = gun and _show_aux_ui
	if reload_prompt:
		reload_prompt.visible = gun and _show_aux_ui
	if ammo_left:
		ammo_left.visible = gun and _show_aux_ui
	if not gun:
		if reload_bar_animation and reload_bar_animation.is_playing():
			reload_bar_animation.stop()
		if reload_prompt_animation and reload_prompt_animation.is_playing():
			reload_prompt_animation.stop()
		if ammo_left_animation and ammo_left_animation.is_playing():
			ammo_left_animation.stop()

func _refresh_ability2_charge_ui_visibility() -> void:
	if ability2_cd_bar == null:
		return
	var a2_parent := ability2_cd_bar.get_parent()
	if a2_parent == null:
		return
	if hero is HeroLoanShark:
		a2_parent.visible = hero.ability2_cooldown > 0
		ability2_cd_bar.visible = false
		if loan_shark_charge_row:
			loan_shark_charge_row.visible = true
	elif hero != null:
		a2_parent.visible = hero.ability2_cooldown > 0
		ability2_cd_bar.visible = hero.ability2_cooldown > 0
		if loan_shark_charge_row:
			loan_shark_charge_row.visible = false
	else:
		a2_parent.visible = false
		if loan_shark_charge_row:
			loan_shark_charge_row.visible = false

func _refresh_movement_dash_ui_visibility() -> void:
	if dash_cd_bar == null:
		return
	var dash_parent := dash_cd_bar.get_parent()
	if dash_parent == null:
		return
	if hero and not hero.allows_movement_dash():
		dash_parent.visible = false
	else:
		dash_parent.visible = _show_aux_ui

func _setup_local_ui() -> void:
	var show_ui = false
	var show_aux = false
	if input is LocalInput:
		show_ui = (player_id == 0)
		show_aux = show_ui
	elif input is NetworkInput:
		show_ui = input.is_local
		show_aux = show_ui
	else:
		show_aux = false
	
	_show_aux_ui = show_aux
	
	if camera:
		camera.enabled = show_ui
	
	if cooldown_ui:
		cooldown_ui.visible = show_ui
	_refresh_world_health_bar()
	
	if show_ui:
		_create_tooltip()
		if hero:
			_bind_hero_ui_signals(hero)
			_refresh_hero_ui()

func _should_show_local_ui() -> bool:
	if input is LocalInput:
		return player_id == 0
	if input is NetworkInput:
		return input.is_local
	return false

func _bind_hero_ui_signals(h: Hero) -> void:
	if h == null:
		return
	if _ui_bound_hero != null and _ui_bound_hero != h:
		_unbind_hero_ui_signals(_ui_bound_hero)
	_ui_bound_hero = h

	var cb_a1_use := Callable(self, "ability_1_use_animation")
	if not h.used_ability_1.is_connected(cb_a1_use):
		h.used_ability_1.connect(cb_a1_use)
	var cb_a1_ref := Callable(self, "ability_1_refresh_animation")
	if not h.ability_1_refreshed.is_connected(cb_a1_ref):
		h.ability_1_refreshed.connect(cb_a1_ref)
	if h.uses_gun_ammo():
		var cb_out := Callable(self, "prompt_reload")
		if not h.ran_out_of_ammo.is_connected(cb_out):
			h.ran_out_of_ammo.connect(cb_out)
		var cb_start := Callable(self, "show_reload_bar")
		if not h.started_reload.is_connected(cb_start):
			h.started_reload.connect(cb_start)
		var cb_fin := Callable(self, "hide_reload_bar")
		if not h.finished_reload.is_connected(cb_fin):
			h.finished_reload.connect(cb_fin)
		var cb_upd := Callable(self, "update_ammo_left")
		if not h.finished_reload.is_connected(cb_upd):
			h.finished_reload.connect(cb_upd)
		if not h.shot.is_connected(cb_upd):
			h.shot.connect(cb_upd)

func _unbind_hero_ui_signals(h: Hero) -> void:
	if h == null:
		return
	var cb_a1_use := Callable(self, "ability_1_use_animation")
	if h.used_ability_1.is_connected(cb_a1_use):
		h.used_ability_1.disconnect(cb_a1_use)
	var cb_a1_ref := Callable(self, "ability_1_refresh_animation")
	if h.ability_1_refreshed.is_connected(cb_a1_ref):
		h.ability_1_refreshed.disconnect(cb_a1_ref)
	var cb_out := Callable(self, "prompt_reload")
	if h.ran_out_of_ammo.is_connected(cb_out):
		h.ran_out_of_ammo.disconnect(cb_out)
	var cb_start := Callable(self, "show_reload_bar")
	if h.started_reload.is_connected(cb_start):
		h.started_reload.disconnect(cb_start)
	var cb_fin := Callable(self, "hide_reload_bar")
	if h.finished_reload.is_connected(cb_fin):
		h.finished_reload.disconnect(cb_fin)
	var cb_upd := Callable(self, "update_ammo_left")
	if h.finished_reload.is_connected(cb_upd):
		h.finished_reload.disconnect(cb_upd)
	if h.shot.is_connected(cb_upd):
		h.shot.disconnect(cb_upd)

func _refresh_hero_ui() -> void:
	if hero == null:
		return
	var health_amount : int = int(hero.get_health())
	target_health_bar_value = hero.get_health_percent() * 100
	target_health_bar_color = Color.WHITE
	local_health_bar_label.text = str(health_amount)
	character_profile.texture = hero.get_hero_default_profile()
	character_profile.material = null
	character_profile.position = _profile_base_pos + hero.get_hero_portrait_offset()
	ability_1_icon.texture = hero.get_hero_ability1_icon()
	ability_2_icon.texture = hero.get_hero_ability2_icon()
	ability_1_bar.modulate = hero.get_hero_ui_color()
	ability_2_bar.modulate = hero.get_hero_ui_color()
	if hero.uses_gun_ammo():
		update_ammo_left()

	_refresh_movement_dash_ui_visibility()
	_refresh_ability2_charge_ui_visibility()
	_refresh_gun_ui_visibility()

func _setup_nametag() -> void:
	nametag = health_bar.get_node_or_null("Nametag") if health_bar else null
	if nametag == null:
		return
	var gm = GameManager.instance
	if gm and gm.player_data.has(player_id):
		nametag.text = gm.get_player_username(player_id)
	elif is_ai_player:
		nametag.text = "Bot %d" % player_id
	else:
		nametag.text = "Player %d" % player_id

func _show_enemy_health_bar() -> bool:
	return not _is_local_player() and not in_spectate_mode and not is_awaiting_respawn and not is_dying and not is_dead()

func _refresh_world_health_bar() -> void:
	if health_bar == null:
		return
	var show_enemy = _show_enemy_health_bar()
	health_bar.visible = _show_aux_ui or show_enemy
	if health_bar_fill:
		health_bar_fill.visible = show_enemy
	var bg = health_bar.get_node_or_null("Background")
	if bg:
		bg.visible = show_enemy
	if nametag:
		nametag.visible = show_enemy
	_refresh_mark_indicator_visibility()

func _refresh_mark_indicator_visibility() -> void:
	if mark_indicator == null or health_bar == null:
		return
	mark_indicator.visible = is_marked and health_bar.visible

func _physics_process(delta: float) -> void:
	if input == null:
		return
	
	var is_local = _is_local_player()
	
	input.update(delta)
	
	if in_spectate_mode:
		if is_local:
			_handle_spectate_movement(delta)
			move_and_slide()
		if input is LocalInput:
			input.end_frame()
		return
	
	if is_awaiting_respawn:
		_update_death_countdown(delta)
		if input is LocalInput:
			input.end_frame()
		return

	if is_dying:
		velocity = Vector2.ZERO
		_refresh_world_health_bar()
		if input is LocalInput:
			input.end_frame()
		return
	
	_update_timers(delta)
	
	if is_local:
		_handle_movement(delta)
		move_and_slide()
	
	_handle_rotation(delta)
	var consumed_shoot := _handle_crops(delta)
	_handle_actions(consumed_shoot)
	
	if health_bar:
		health_bar.global_position = global_position + Vector2(-25, -60)
	
	_update_cooldown_ui()
	_update_tooltip()
	
	if is_invulnerable:
		_check_farm_invulnerability()
	
	# Update local health bar
	local_health_bar.value = lerpf(local_health_bar.value, target_health_bar_value, delta * 10);
	local_health_bar.modulate = lerp(local_health_bar.modulate, target_health_bar_color, delta * 10);
	
	if input is LocalInput:
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
	if is_stunned:
		if hero and input.ult_just:
			hero.ult(aim_dir, get_aim_position())
		return

	if is_dying or is_dead():
		return

	# Dash (disabled for heroes that only use ability-based dashes, e.g. Loan Shark)
	if input.dash_just and dash_cd_timer <= 0 and not is_dashing and not is_dead():
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

func _update_health_bar() -> void:
	if health_bar_fill == null or hero == null:
		return
	_refresh_world_health_bar()
	
	var pct = hero.get_health_percent()
	health_bar_fill.scale.x = pct
	
	if pct > 0.5:
		health_bar_fill.color = Color(0.2, 0.8, 0.2)
		target_health_bar_color = Color.WHITE;
	elif pct > 0.25:
		health_bar_fill.color = Color(0.8, 0.8, 0.2)
		target_health_bar_color = Color.CORAL;
	else:
		health_bar_fill.color = Color(0.8, 0.2, 0.2)
		target_health_bar_color = Color.RED;
	
	var health_amount : int = int(hero.get_health());
	local_health_bar_label.text = str(health_amount);
	target_health_bar_value = hero.get_health_percent() * 100;
	

func _update_cooldown_ui() -> void:
	if hero == null or cooldown_ui == null or not cooldown_ui.visible:
		return
	
	if shoot_cd_bar:
		var shoot_pct = 1.0 - (hero.shoot_cd / hero.shoot_cooldown) if hero.shoot_cooldown > 0 else 1.0
		shoot_cd_bar.value = clamp(shoot_pct, 0.0, 1.0)
	
	if ability1_cd_bar:
		var a1_pct = 1.0 - (hero.ability1_cd / hero.ability1_cooldown) if hero.ability1_cooldown > 0 else 1.0
		ability1_cd_bar.value = clamp(a1_pct, 0.0, 1.0)
		ability_1_bar.value = clamp(a1_pct, 0.0, 1.0)
		if(a1_pct < 1.0): ability_1_bar.modulate.a = 0.35;
		else: ability_1_bar.modulate.a = 1;
	
	
	if ability2_cd_bar:
		if hero is HeroLoanShark:
			var ls := hero as HeroLoanShark
			ability2_cd_bar.get_parent().visible = hero.ability2_cooldown > 0
			ability2_cd_bar.visible = false
			if loan_shark_charge_row:
				loan_shark_charge_row.visible = true
			if ability2_charge_bar_1:
				ability2_charge_bar_1.value = clamp(ls.get_ability2_charge_slot_recharge_progress(0), 0.0, 1.0)
			if ability2_charge_bar_2:
				ability2_charge_bar_2.value = clamp(ls.get_ability2_charge_slot_recharge_progress(1), 0.0, 1.0)
		elif hero.ability2_cooldown > 0:
			ability2_cd_bar.visible = true
			var a2_pct = 1.0 - (hero.ability2_cd / hero.ability2_cooldown)
			ability2_cd_bar.value = clamp(a2_pct, 0.0, 1.0)
			ability2_cd_bar.get_parent().visible = true
			if loan_shark_charge_row:
				loan_shark_charge_row.visible = false
		else:
			ability2_cd_bar.get_parent().visible = false
			if loan_shark_charge_row:
				loan_shark_charge_row.visible = false
	
	if ability_2_bar:
		if hero is HeroLoanShark:
			var ls2 := hero as HeroLoanShark
			ability_2_bar.value = float(ls2.ability2_charges) / 2.0
			ability_2_bar.modulate.a = 0.35 if ls2.ability2_charges <= 0 else 1.0
		elif hero and hero.ability2_cooldown > 0:
			var a2_pct2 = 1.0 - (hero.ability2_cd / hero.ability2_cooldown)
			ability_2_bar.modulate.a = 0.35 if a2_pct2 < 1.0 else 1.0
	
	if reload_cd_bar and hero.uses_gun_ammo():
		var reload_pct = 1.0 - (hero.reload_cd / hero.reload_time) if hero.reload_time > 0 else 1.0
		reload_cd_bar.value = clamp(reload_pct, 0.0, 1.0)
		reload_bar.value = clamp(reload_pct, 0.15, 1.0);
		
	if dash_cd_bar and hero and hero.allows_movement_dash():
		var dash_pct = 1.0 - (dash_cd_timer / dash_cooldown) if dash_cooldown > 0 else 1.0
		dash_cd_bar.value = clamp(dash_pct, 0.0, 1.0)
	
	if ammo_label and hero.uses_gun_ammo():
		ammo_label.text = "%d/%d" % [hero.ammo, hero.mag_size]
	
	var ult_full := hero.get_ult_percent() >= 1.0
	ult_percent_label.text = "c" if ult_full else str(int(hero.get_ult_percent() * 100))
	if ult_full:
		character_profile.texture = hero.get_hero_ult_profile()
		var c := hero.get_hero_ui_color()
		_ult_ready_mat.set_shader_parameter("color_a", c.lerp(Color.WHITE, 0.2))
		_ult_ready_mat.set_shader_parameter("color_b", c.lerp(Color.BLACK, 0.35))
		character_profile.material = _ult_ready_mat
	else:
		character_profile.texture = hero.get_hero_default_profile()
		character_profile.material = null
	character_profile.position = _profile_base_pos + hero.get_hero_portrait_offset()
	
	if ult_bar:
		ult_bar.value = hero.get_ult_percent()
		
	if ult_label:
		ult_label.text = "%d/%d" % [hero.ult_points, hero.max_ult_points]

# --- TOOLTIP ---

func _create_tooltip() -> void:
	tooltip_layer = CanvasLayer.new()
	tooltip_layer.layer = 50
	add_child(tooltip_layer)
	
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_label.size = Vector2(200, 60)
	
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.add_child(tooltip_label)
	tooltip_layer.add_child(panel)

func _update_tooltip() -> void:
	if tooltip_label == null:
		return
	
	var panel = tooltip_label.get_parent()
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Query crops under mouse in world space
	var world_mouse = get_global_mouse_position()
	var crop = _find_crop_at(world_mouse)
	
	if crop:
		tooltip_label.text = crop.get_tooltip_bbcode()
		panel.visible = true
		panel.position = mouse_pos + Vector2(16, 16)
	else:
		panel.visible = false

func _find_crop_at(world_pos: Vector2) -> Crop:
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var results = space.intersect_point(params, 8)
	for result in results:
		if result.collider is Crop:
			return result.collider
	
	# Also check planted crops by proximity
	for f in get_tree().get_nodes_in_group("farms"):
		for c in f.crops:
			if is_instance_valid(c) and c.global_position.distance_to(world_pos) < 30.0:
				return c
	return null

# --- CROP SYSTEM ---

var _crop_area: Area2D = null

func _setup_crop_area() -> void:
	_crop_area = Area2D.new()
	_crop_area.collision_layer = 0
	_crop_area.collision_mask = 16
	_crop_area.monitoring = true
	_crop_area.monitorable = false
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	_crop_area.add_child(shape)
	add_child(_crop_area)
	_crop_area.area_entered.connect(_on_crop_area_entered)
	#print("[PLAYER] _setup_crop_area: player_", player_id, " crop pickup area ready (radius=40, mask=0, layer=0)")

func _on_crop_area_entered(area: Area2D) -> void:
	if in_spectate_mode: return
	if input is NetworkInput and not input.is_local: return
	if area is Crop and held_crop == null and drop_cd <= 0 and not area.is_planted:
		pickup_world_crop(area)

func _handle_crops(_delta: float) -> bool:
	if input == null:
		return false
	var consumed_shoot := false
	
	# Drop held crop
	if input.drop_just and held_crop != null:
		drop_held_crop()
		return false
	
	# Plant held crop (LMB click while holding)
	if input.shoot_just and held_crop != null:
		consumed_shoot = _try_plant()
		return consumed_shoot
	
	# Pick up planted crop (LMB click on planted crop, not holding anything)
	if input.shoot_just and held_crop == null:
		consumed_shoot = _try_uproot()
	
	if held_sprite and held_crop:
		var behind = -aim_dir.normalized() * 40.0
		held_sprite.global_position = global_position + behind
	if _remote_held_sprite and _remote_held_sprite.visible:
		_remote_held_sprite.position = Vector2(0, 40).rotated(-rotation_offset)
	return consumed_shoot

func pickup_world_crop(crop: Crop) -> void:
	var crop_pos = crop.global_position
	var type_id = crop.get_type_id()
	var stg = crop.stage
	held_crop = crop
	crop.picked_up.emit()
	if crop.get_parent():
		crop.get_parent().remove_child(crop)
	
	held_sprite = Sprite2D.new()
	held_sprite.texture = crop.icon if crop.icon else _make_placeholder_tex(crop)
	held_sprite.scale = Vector2(0.5, 0.5)
	held_sprite.z_index = 10
	get_parent().add_child(held_sprite)
	held_sprite.global_position = global_position + (-aim_dir.normalized() * 40.0)
	
	var gm = GameManager.instance
	if gm and not gm.is_local():
		gm.send_crop_pickup(player_id, crop_pos, type_id, stg)

func drop_held_crop() -> void:
	if held_crop == null:
		return
	var type_id = held_crop.get_type_id()
	var stg = held_crop.stage
	held_crop.global_position = global_position
	get_parent().add_child(held_crop)
	held_crop = null
	drop_cd = DROP_CD_TIME
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null
	var gm = GameManager.instance
	if gm and not gm.is_local():
		gm.send_crop_dropped(player_id, global_position, type_id, stg)

const INTERACT_RANGE := 400.0
const TILE_HALF := 80.0

func _tile_at_cursor(tiles: Array) -> Node:
	var aim_pos = get_aim_position()
	for tile in tiles:
		if tile.global_position.distance_to(aim_pos) <= TILE_HALF:
			return tile
	return null

func _try_plant() -> bool:
	if farm == null or held_crop == null:
		return false
	if not farm.has_space():
		return false
	
	var tiles = _get_plantable_tiles(farm)
	var tile = _tile_at_cursor(tiles)
	if tile == null or tile.planted_crop != null:
		return false
	if tile.global_position.distance_to(global_position) > INTERACT_RANGE:
		return false
	
	var crop = held_crop
	var crop_type = crop.get_type_id()
	var stg = crop.stage
	held_crop = null
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null
	
	farm.plant_crop(crop, tile)
	crop_count += 1
	
	var gm = GameManager.instance
	if gm and not gm.is_local():
		var tile_idx = tiles.find(tile)
		gm.send_crop_planted(player_id, tile_idx, crop_type, stg)
	return true

func _try_uproot() -> bool:
	var farms_list = get_tree().get_nodes_in_group("farms")
	for f in farms_list:
		var tiles = _get_plantable_tiles(f)
		var tile = _tile_at_cursor(tiles)
		if tile == null or tile.planted_crop == null:
			continue
		if tile.global_position.distance_to(global_position) > INTERACT_RANGE:
			continue
		var tile_idx = tiles.find(tile)
		var crop = f.remove_crop(tile.planted_crop)
		if crop:
			var victim = f._owner
			if victim:
				victim.crop_count -= 1
			pickup_world_crop(crop)
			var gm = GameManager.instance
			if gm and not gm.is_local() and victim:
				gm.send_crop_uproot(victim.player_id, tile_idx, crop.get_type_id(), crop.stage)
			return true
		return false
	return false

func _get_plantable_tiles(f) -> Array:
	var tiles: Array = []
	var tilemap = f.get_node_or_null("TileMapLayer")
	if tilemap == null:
		return tiles
	for child in tilemap.get_children():
		if child.has_method("plant"):
			tiles.append(child)
	return tiles

func _make_placeholder_tex(crop: Crop) -> Texture2D:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(crop.get_stage_color())
	return ImageTexture.create_from_image(img)

func set_remote_held_crop(type_id: String, stg: int) -> void:
	if type_id == _remote_held_type and _remote_held_sprite != null:
		return
	_remote_held_type = type_id
	if _remote_held_sprite == null:
		_remote_held_sprite = Sprite2D.new()
		_remote_held_sprite.scale = Vector2(0.5, 0.5)
		_remote_held_sprite.z_index = 10
		_remote_held_sprite.position = Vector2(0, 40)
		add_child(_remote_held_sprite)
	var gm = GameManager.instance
	if gm:
		_remote_held_sprite.texture = gm.make_crop_icon(type_id, stg)
	_remote_held_sprite.visible = true

func clear_remote_held_crop() -> void:
	_remote_held_type = ""
	if _remote_held_sprite:
		_remote_held_sprite.visible = false

func prompt_reload() -> void:
	reload_prompt_animation.play("appear");

func show_reload_bar() -> void:
	if(hero.ammo == 0): reload_prompt_animation.play("disappear");
	reload_bar_animation.play("appear");

func hide_reload_bar() -> void:
	reload_bar_animation.play("finish");
	reload_bar_finish_animation.play("finish");

func update_ammo_left() -> void:
	ammo_left.text = str(hero.ammo);
	ammo_left_animation.stop();
	ammo_left_animation.play("shoot");

func ability_1_use_animation() -> void:
	ability_1_animation.play("use");

func ability_1_refresh_animation() -> void:
	ability_1_animation.play("refreshed");

# --- DRUG EFFECT ---

const DrugShader = preload("res://assets/shaders/drug.gdshader")

func apply_drug_effect(duration: float) -> void:
	is_drugged = true
	drug_timer = duration
	
	if _should_show_local_ui():
		_create_drug_effect_layer()

func _create_drug_effect_layer() -> void:
	if drug_effect_layer:
		return
	
	# Create fullscreen shader layer
	drug_effect_layer = CanvasLayer.new()
	drug_effect_layer.layer = 100
	add_child(drug_effect_layer)
	
	drug_effect_rect = ColorRect.new()
	drug_effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	drug_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	mat.shader = DrugShader
	mat.set_shader_parameter("wobble_intensity", 0.025)
	mat.set_shader_parameter("color_intensity", 0.35)
	mat.set_shader_parameter("color_speed", 2.0)
	drug_effect_rect.material = mat
	
	drug_effect_layer.add_child(drug_effect_rect)

func _end_drug_effect() -> void:
	is_drugged = false
	drug_timer = 0.0
	
	if drug_effect_layer:
		drug_effect_layer.queue_free()
		drug_effect_layer = null
		drug_effect_rect = null

# --- MARKED EFFECT (LOAN SHARK) ---

func apply_mark_effect(duration: float) -> void:
	is_marked = true
	marked_timer = duration
	_refresh_mark_indicator_visibility()

func _end_marked_effect() -> void:
	clear_mark_effect()

## Clears Loan Shark mark (timer, UI). Safe to call when not marked.
func clear_mark_effect() -> void:
	if not is_marked:
		return
	is_marked = false
	marked_timer = 0.0
	_refresh_mark_indicator_visibility()

## World-space pop when Loan Shark's mark projectile connects (visible to all players).
func spawn_mark_projectile_hit_fx() -> void:
	var fx: Node2D = MarkProjectileHitFxScene.instantiate()
	add_child(fx)
	fx.global_position = global_position + Vector2(0, -72)


# --- BLIND EFFECT ---

const BlindShader = preload("res://assets/shaders/blind.gdshader")

func apply_blind_effect(duration: float) -> void:
	var is_local = (input is LocalInput and player_id == 0) or (input is NetworkInput and input.is_local)
	
	is_blinded = true
	blind_timer = duration
	
	if is_local:
		_create_blind_effect_layer()

func _create_blind_effect_layer() -> void:
	if blind_effect_layer:
		return
	
	blind_effect_layer = CanvasLayer.new()
	blind_effect_layer.layer = 100
	add_child(blind_effect_layer)
	
	blind_effect_rect = ColorRect.new()
	blind_effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blind_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	mat.shader = BlindShader
	mat.set_shader_parameter("flash_speed", 3.0)
	mat.set_shader_parameter("intensity", 1)
	mat.set_shader_parameter("fade", 1.0)
	blind_effect_rect.material = mat
	
	blind_effect_layer.add_child(blind_effect_rect)

func _end_blind_effect() -> void:
	is_blinded = false
	blind_timer = 0.0
	
	if blind_effect_layer:
		blind_effect_layer.queue_free()
		blind_effect_layer = null
		blind_effect_rect = null

# --- STUN ---

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = max(stun_timer, duration)


# ---------- Death / Respawn ----------

func _enter_death_state() -> void:
	is_awaiting_respawn = true
	respawn_countdown = 10.0
	
	if cooldown_ui:
		cooldown_ui.visible = false
	if health_bar:
		health_bar.visible = false
	if tooltip_layer:
		tooltip_layer.visible = false
	if held_crop:
		drop_held_crop()
	if _crop_area:
		_crop_area.monitoring = false
	_disable_collision()
	if hero:
		hero.enter_spectate_mode()
	
	if _is_local_player():
		_show_death_timer_ui()

func _update_death_countdown(delta: float) -> void:
	respawn_countdown -= delta
	if _death_timer_label:
		var secs = ceili(max(respawn_countdown, 0.0))
		_death_timer_label.text = "Respawning in %ds" % secs

func _show_death_timer_ui() -> void:
	_death_ui = CanvasLayer.new()
	_death_ui.layer = 90
	add_child(_death_ui)
	
	_death_timer_label = Label.new()
	_death_timer_label.text = "Respawning in 10s"
	_death_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_timer_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_timer_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_timer_label.add_theme_font_size_override("font_size", 36)
	_death_timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_death_ui.add_child(_death_timer_label)

func respawn_at(pos: Vector2) -> void:
	is_dying = false
	is_awaiting_respawn = false
	respawn_countdown = 0.0
	
	if _death_ui:
		_death_ui.queue_free()
		_death_ui = null
		_death_timer_label = null
	
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
	
	if _crop_area:
		_crop_area.monitoring = true
	
	if _is_local_player():
		if cooldown_ui:
			cooldown_ui.visible = true
	_refresh_world_health_bar()
	
	is_invulnerable = true
	_update_health_bar()

func _check_farm_invulnerability() -> void:
	if farm == null:
		is_invulnerable = false
		return
	if global_position.distance_to(farm.global_position) > FARM_RADIUS:
		is_invulnerable = false

# ---------- Spectate Mode ----------

const SPECTATE_SPEED := 500.0
var _elim_ui: CanvasLayer = null

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
	
	if cooldown_ui:
		cooldown_ui.visible = false
	if health_bar:
		health_bar.visible = false
	if tooltip_layer:
		tooltip_layer.visible = false
	
	# Drop any held crop back into the world
	if held_crop:
		drop_held_crop()
	
	# Disable crop pickup area
	if _crop_area:
		_crop_area.monitoring = false
	
	_disable_collision()
	
	if hero:
		hero.enter_spectate_mode()
	
	var gm = GameManager.instance
	if _is_local_player() and (gm == null or not gm.game_over):
		_show_elimination_ui()

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

# --- Elimination UI ---

func _show_elimination_ui() -> void:
	_elim_ui = CanvasLayer.new()
	_elim_ui.layer = 90
	add_child(_elim_ui)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_elim_ui.add_child(bg)
	
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(360, 0)
	center.add_theme_constant_override("separation", 24)
	bg.add_child(center)
	
	var title = Label.new()
	title.text = "ELIMINATED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	center.add_child(title)
	
	var spectate_btn = Button.new()
	spectate_btn.text = "Spectate"
	spectate_btn.custom_minimum_size = Vector2(160, 48)
	spectate_btn.pressed.connect(_on_spectate_pressed)
	center.add_child(spectate_btn)

func clear_elimination_ui() -> void:
	if _elim_ui:
		_elim_ui.queue_free()
		_elim_ui = null

func _on_spectate_pressed() -> void:
	clear_elimination_ui()
