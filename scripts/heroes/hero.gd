class_name Hero
extends Node2D

signal health_changed(current: float, max_hp: float)
signal ult_changed(current: int, max_points: int)
signal died

# Stats 
@export var max_health: float = 100.0
@export var move_speed_mult: float = 1.0

@export var shoot_cooldown: float = 0.3
@export var ability1_cooldown: float = 5.0

# Ult (ability2) charge
@export var max_ult_points: int = 50
@export var ult_points_on_hit: int = 2
@export var ult_points_on_dodge: int = 1

@export var reload_time: float = 1.5
@export var mag_size: int = 15

# Animation durations
@export var ability1_anim_duration: float = 0.5
@export var ability2_anim_duration: float = 0.5
@export var dash_anim_duration: float = 0.2

# State
var health: float = 100.0
var shoot_cd: float = 0.0
var ability1_cd: float = 0.0
var reload_cd: float = 0.0
var is_dead: bool = false
var ammo: int = 15
var ult_points: int = 0

# Animation state
var ability1_anim_timer: float = 0.0
var ability2_anim_timer: float = 0.0
var current_anim: String = "idle"

# Set by Player
var player: Node2D = null
var sprite: AnimatedSprite2D = null
var hitbox: CollisionShape2D = null

# Default UI
const DEFAULT_HERO_UI_COLOR = Color.WHITE;
const ABILITY_ICON_TEMP_2 = preload("res://assets/ui/player/ability_icon_temp2.png")
const ABILITY_ICON_TEMP_1 = preload("res://assets/ui/player/ability_icon_temp1.png")
const PROFILE_ANGRY_PLACEHOLDER = preload("res://assets/ui/player/profile_angry_placeholder.png")
const PROFILE_PLACEHOLDER = preload("res://assets/ui/player/profile_placeholder.png")

func _ready() -> void:
	health = max_health
	ammo = mag_size
	
	# Auto-find sprite if it exists as child
	sprite = get_node_or_null("Sprite")
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D")
	
	_setup_visuals()

func _process(delta: float) -> void:
	_update_cooldowns(delta)
	_update_animation(delta)

func _update_cooldowns(delta: float) -> void:
	shoot_cd = max(0, shoot_cd - delta)
	ability1_cd = max(0, ability1_cd - delta)
	
	var was_reloading = reload_cd > 0
	reload_cd = max(0, reload_cd - delta)
	if was_reloading and reload_cd <= 0:
		ammo = mag_size
	
	ability1_anim_timer = max(0, ability1_anim_timer - delta)
	ability2_anim_timer = max(0, ability2_anim_timer - delta)

func _update_animation(delta: float) -> void:
	if sprite == null or player == null:
		return
	
	var new_anim = _get_animation_state()
	if new_anim != current_anim:
		current_anim = new_anim
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(new_anim):
			sprite.play(new_anim)

func _get_animation_state() -> String:
	var is_moving = player.velocity.length() > 10 if "velocity" in player else false
	var is_dashing = player.is_dashing if "is_dashing" in player else false
	var is_reloading = reload_cd > 0
	
	# Priority: dash > ability2 > ability1 > reload > run/idle
	if is_dashing:
		return "dash"
	
	if ability2_anim_timer > 0:
		return "ability2"
	
	if ability1_anim_timer > 0:
		return "ability1"
	
	if is_reloading:
		return "reload_run" if is_moving else "reload_idle"
	
	return "run" if is_moving else "idle"

# VISUALS

func _setup_visuals() -> void:
	pass

func get_sprite_frames() -> SpriteFrames:
	return null

func get_hitbox_shape() -> Shape2D:
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	return shape

# HEALTH

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	
	if health <= 0:
		_die()

func heal(amount: float) -> void:
	if is_dead:
		return
	
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)

func _die() -> void:
	is_dead = true
	died.emit()

func get_health_percent() -> float:
	return health / max_health

func get_health() -> float:
	return health;

# ABILITIES

func can_shoot() -> bool:
	return shoot_cd <= 0 and reload_cd <= 0 and ammo > 0

func can_ability1() -> bool:
	return ability1_cd <= 0

func can_ability2() -> bool:
	return ult_points >= max_ult_points

func shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_shoot():
		return
	shoot_cd = shoot_cooldown
	ammo -= 1
	_do_shoot(aim_dir, aim_pos)

func reload() -> void:
	if reload_cd > 0:
		return
	reload_cd = reload_time
	_do_reload()

func ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ability1():
		return
	ability1_cd = ability1_cooldown
	ability1_anim_timer = ability1_anim_duration
	_do_ability1(aim_dir, aim_pos)

func ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ability2():
		return
	ult_points = 0
	ult_changed.emit(ult_points, max_ult_points)
	ability2_anim_timer = ability2_anim_duration
	_do_ability2(aim_dir, aim_pos)

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	pass

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	pass

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	pass

func _do_reload() -> void:
	pass

# ULT

func add_ult_points(amount: int) -> void:
	var old = ult_points
	ult_points = min(max_ult_points, ult_points + amount)
	if ult_points != old:
		ult_changed.emit(ult_points, max_ult_points)

func get_ult_percent() -> float:
	return float(ult_points) / float(max_ult_points) if max_ult_points > 0 else 0.0

# Util

func get_hero_name() -> String:
	return "Hero"


# UI

func get_hero_default_profile() -> Texture2D:
	return PROFILE_PLACEHOLDER;

func get_hero_ult_profile() -> Texture2D:
	return PROFILE_ANGRY_PLACEHOLDER;

func get_hero_ability1_icon() -> Texture2D:
	return ABILITY_ICON_TEMP_1;

func get_hero_ability2_icon() -> Texture2D:
	return ABILITY_ICON_TEMP_2;

func get_hero_ui_color() -> Color:
	return DEFAULT_HERO_UI_COLOR;
