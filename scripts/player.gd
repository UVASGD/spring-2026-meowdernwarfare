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
var reload_cd_bar: ProgressBar = null
var dash_cd_bar: ProgressBar = null
var ammo_label: Label = null
var ult_bar: ProgressBar = null
var ult_label: Label = null

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

# Meta States
var in_spectate_mode : bool = false 
var is_ai_player : bool = false # Set by game_manager on spawn to denote an ai_player


signal took_damage(amount: float)
signal died

# Hero name -> Hero scene mapping
const HERO_SCENES = {
	"Dealer": preload("res://scenes/heroes/dealer/dealer.tscn"),
	"Burple": preload("res://scenes/heroes/burple.tscn"),
	"Alien": preload("res://scenes/heroes/alien.tscn"),
	"Xyler": preload("res://scenes/heroes/xyler.tscn"),
	"Fergus": preload("res://scenes/heroes/fergus.tscn"),
	"LoanShark": preload("res://scenes/heroes/loanshark.tscn"),
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
		health_bar_fill = health_bar.get_node_or_null("Fill")
	
	# Camera follows only local players
	camera = get_node_or_null("Camera2D")
	
	# Cooldown UI
	cooldown_ui = get_node_or_null("CooldownUI")
	if cooldown_ui:
		var container = cooldown_ui.get_node_or_null("Container")
		if container:
			shoot_cd_bar = container.get_node_or_null("ShootCD/Bar")
			ability1_cd_bar = container.get_node_or_null("Ability1CD/Bar")
			reload_cd_bar = container.get_node_or_null("ReloadCD/Bar")
			dash_cd_bar = container.get_node_or_null("DashCD/Bar")
			ammo_label = container.get_node_or_null("Ammo/Count")
			ult_bar = container.get_node_or_null("UltCD/Bar")
			ult_label = container.get_node_or_null("UltCD/Count")
	
	# Default hero for testing
	if hero == null:
		set_hero("Dealer")
	
	# Enable camera/UI only for local human players
	_setup_local_ui()
	

func set_hero(hero_name: String) -> void:
	if hero:
		hero.queue_free()
		hero = null
	
	var hero_scene = HERO_SCENES.get(hero_name)
	if hero_scene == null:
		push_warning("Unknown hero: ", hero_name, ", defaulting to Dealer")
		hero_scene = HERO_SCENES["Dealer"]
	
	hero = hero_scene.instantiate()
	hero.player = self
	add_child(hero)
	

	hero.died.connect(_on_hero_died)
	hero.health_changed.connect(_on_hero_health_changed)
	
	# Update hitbox if we have one
	var hitbox = get_node_or_null("CollisionShape2D")
	if hitbox:
		hitbox.shape = hero.get_hitbox_shape()
	
	print("Player ", player_id, " set hero to ", hero.get_hero_name())

func _setup_local_ui() -> void:
	# Check if this player should have camera/UI
	var show_ui = false
	if input is LocalInput:
		# In local mode, only player 0 gets the camera
		show_ui = (player_id == 0)
	elif input is NetworkInput:
		# In online mode, the local player gets camera
		show_ui = input.is_local
	
	if camera:
		camera.enabled = show_ui
	
	if cooldown_ui:
		cooldown_ui.visible = show_ui

func _physics_process(delta: float) -> void:
	if input == null:
		return
	
	input.update(delta)
	
	_update_timers(delta)
	_handle_movement(delta)
	_handle_rotation(delta)
	_handle_actions()
	
	move_and_slide()
	
	# Keep health bar above player
	if health_bar:
		health_bar.global_position = global_position + Vector2(-25, -60)
	
	# Update cooldown UI
	_update_cooldown_ui()
	
	if input is LocalInput:
		input.end_frame()

func _update_timers(delta: float) -> void:
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	
	# Drug effect timer
	if drug_timer > 0:
		drug_timer -= delta
		if drug_timer <= 0:
			_end_drug_effect()

func _handle_movement(delta: float) -> void:
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
	

func _handle_actions() -> void:
	# Dash
	if input.dash_just and dash_cd_timer <= 0 and not is_dashing and not is_dead():
		_start_dash()
	
	if hero == null:
		return
	
	# Delegate to hero
	if input.shoot:
		hero.shoot(aim_dir, get_aim_position())
	if input.ability1_just:
		hero.ability1(aim_dir, get_aim_position())
	if input.ability2_just:
		hero.ability2(aim_dir, get_aim_position())
	if input.reload_just:
		hero.reload()

func _start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cd_timer = dash_cooldown
	dash_dir = aim_dir if input.move_input.length() < 0.1 else input.move_input.normalized()

func _on_hero_died() -> void:
	died.emit()

func _on_hero_health_changed(current: float, max_hp: float) -> void:
	_update_health_bar()

# --- PUBLIC API ---

func get_aim_direction() -> Vector2:
	return aim_dir

func get_aim_position() -> Vector2:
	if input:
		return input.aim_position
	return global_position + aim_dir * 100

func is_moving() -> bool:
	return input != null and input.move_input.length() > 0.1

func take_damage(amount: float, attacker: Player = null) -> void:
	if is_dead(): return
	# Invulnerable during dash
	if is_dashing:
		on_bullet_dodged()
		return
	
	if hero:
		hero.take_damage(amount)
		took_damage.emit(amount)
		# Award ult points to attacker for hitting
		if attacker and attacker.hero:
			attacker.hero.add_ult_points(attacker.hero.ult_points_on_hit)

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
	
	var pct = hero.get_health_percent()
	health_bar_fill.scale.x = pct
	
	if pct > 0.5:
		health_bar_fill.color = Color(0.2, 0.8, 0.2)
	elif pct > 0.25:
		health_bar_fill.color = Color(0.8, 0.8, 0.2)
	else:
		health_bar_fill.color = Color(0.8, 0.2, 0.2)

func _update_cooldown_ui() -> void:
	if hero == null or cooldown_ui == null or not cooldown_ui.visible:
		return
	
	if shoot_cd_bar:
		var shoot_pct = 1.0 - (hero.shoot_cd / hero.shoot_cooldown) if hero.shoot_cooldown > 0 else 1.0
		shoot_cd_bar.value = clamp(shoot_pct, 0.0, 1.0)
	
	if ability1_cd_bar:
		var a1_pct = 1.0 - (hero.ability1_cd / hero.ability1_cooldown) if hero.ability1_cooldown > 0 else 1.0
		ability1_cd_bar.value = clamp(a1_pct, 0.0, 1.0)
	
	
	if reload_cd_bar:
		var reload_pct = 1.0 - (hero.reload_cd / hero.reload_time) if hero.reload_time > 0 else 1.0
		reload_cd_bar.value = clamp(reload_pct, 0.0, 1.0)
		
	if dash_cd_bar:
		var dash_pct = 1.0 - (dash_cd_timer / dash_cooldown) if dash_cooldown > 0 else 1.0
		dash_cd_bar.value = clamp(dash_pct, 0.0, 1.0)
	
	if ammo_label:
		ammo_label.text = "%d/%d" % [hero.ammo, hero.mag_size]
	
	if ult_bar:
		ult_bar.value = hero.get_ult_percent()
	if ult_label:
		ult_label.text = "%d/%d" % [hero.ult_points, hero.max_ult_points]

# --- DRUG EFFECT ---

const DrugShader = preload("res://assets/shaders/drug.gdshader")

func apply_drug_effect(duration: float) -> void:
	# Only show effect for local player
	var is_local = (input is LocalInput and player_id == 0) or (input is NetworkInput and input.is_local)
	
	is_drugged = true
	drug_timer = duration
	
	if is_local:
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
		
		
# ---------- Spectate Mode ----------
# The following is done while in spectate mode
# disbled visability for cooldown_ui, health_bar, health_bar_fill
# player collision is disabled as to not get hit by bullets
# tells the hero subclass to enter spectate mode
func enter_spectate_mode() -> void:
	# ensure player is not already in spectate mode
	# for now check for ai_player in spectate
	if is_ai_player: return
	if in_spectate_mode: return
	#if not is_dead
	in_spectate_mode = true
	
	# disable all the ui for player
	cooldown_ui.visible = false
	health_bar.visible = false
	health_bar_fill.visible = false
	disable_player_collision_area()
	if hero:
		# hero.is_dead = true
		hero.enter_spectate_mode()

# diable the collision shape for player
# double chekc to make sure can walk through walls?
func disable_player_collision_area() -> void:
	var playerCollision : CollisionShape2D = get_node_or_null("CollisionShape2D")
	if playerCollision:
		playerCollision.disabled = true
