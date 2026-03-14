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
@export var ability2_cooldown: float = 0.0

# Ult charge
@export var max_ult_points: int = 50
@export var ult_points_on_hit: int = 2
@export var ult_points_on_dodge: int = 1

@export var reload_time: float = 1.5
@export var mag_size: int = 15

# Animation durations
@export var ability1_anim_duration: float = 0.5
@export var ability2_anim_duration: float = 0.5
@export var ult_anim_duration: float = 0.5
@export var dash_anim_duration: float = 0.2
@export var shoot_actionable: bool = true
@export var ability1_actionable: bool = true
@export var ability2_actionable: bool = true
@export var ult_actionable: bool = true

# State
var health: float = 100.0
var shoot_cd: float = 0.0
var ability1_cd: float = 0.0
var ability2_cd: float = 0.0
var reload_cd: float = 0.0
var is_dead: bool = false
var ammo: int = 15
var ult_points: int = 0

# Animation state
var ability1_anim_timer: float = 0.0
var ability2_anim_timer: float = 0.0
var ult_anim_timer: float = 0.0
var current_anim: String = "idle"
var anim_locked: bool = false
var lock_anim: String = ""
var lock_skill: String = ""
var missing_anim_warn := {}

# Set by Player
var player: Node2D = null
var sprite: AnimatedSprite2D = null
var hitbox: CollisionShape2D = null

func _ready() -> void:
	health = max_health
	ammo = mag_size
	
	# Auto-find sprite if it exists as child
	sprite = get_node_or_null("Sprite")
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	_setup_visuals()

func _process(delta: float) -> void:
	_update_cooldowns(delta)
	_update_animation(delta)

func _update_cooldowns(delta: float) -> void:
	shoot_cd = max(0, shoot_cd - delta)
	ability1_cd = max(0, ability1_cd - delta)
	ability2_cd = max(0, ability2_cd - delta)
	
	var was_reloading = reload_cd > 0
	reload_cd = max(0, reload_cd - delta)
	if was_reloading and reload_cd <= 0:
		ammo = mag_size
	
	ability1_anim_timer = max(0, ability1_anim_timer - delta)
	ability2_anim_timer = max(0, ability2_anim_timer - delta)
	ult_anim_timer = max(0, ult_anim_timer - delta)

func _update_animation(delta: float) -> void:
	if sprite == null or player == null:
		return
	
	_update_anim_lock()
	if anim_locked:
		return
	
	var new_anim = _get_animation_state()
	if new_anim != current_anim:
		current_anim = new_anim
		if new_anim == "run":
			_play_anim_candidates(PackedStringArray(["run", "idle"]), "run")
		elif new_anim == "idle":
			_play_anim_candidates(PackedStringArray(["idle"]), "idle")
		elif new_anim == "dash":
			_play_anim_candidates(PackedStringArray(["dash", "run", "idle"]), "dash")

func _get_animation_state() -> String:
	var is_moving = player.velocity.length() > 10 if "velocity" in player else false
	var is_dashing = player.is_dashing if "is_dashing" in player else false
	
	# Priority: death > dash > run/idle
	if is_dead:
		return "death"

	if is_dashing:
		return "dash"
	
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
	_begin_skill("death")
	_play_action_anim("death")
	_capture_skill_anim()
	died.emit()

func get_health_percent() -> float:
	return health / max_health

# ABILITIES

func can_shoot() -> bool:
	return shoot_cd <= 0 and reload_cd <= 0 and ammo > 0 and not is_dead and not _is_action_blocked()

func _is_fie_suppressed() -> bool:
	return player and player.fie_suppress_count > 0

func can_ability1() -> bool:
	return ability1_cd <= 0 and not _is_fie_suppressed() and not _is_action_blocked()

func can_ability2() -> bool:
	return ability2_cd <= 0 and ability2_cooldown > 0 and not _is_fie_suppressed() and not _is_action_blocked()

func can_ult() -> bool:
	return ult_points >= max_ult_points and not _is_fie_suppressed() and not _is_action_blocked()

func shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_shoot():
		return
	shoot_cd = shoot_cooldown
	ammo -= 1
	_begin_skill("shoot")
	_play_action_anim("shoot")
	_capture_skill_anim()
	_do_shoot(aim_dir, aim_pos)

func reload() -> void:
	if reload_cd > 0:
		return
	reload_cd = reload_time
	_begin_skill("reload")
	_play_action_anim("reload")
	_capture_skill_anim()
	_do_reload()

func ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ability1() or is_dead:
		return
	ability1_cd = ability1_cooldown
	ability1_anim_timer = ability1_anim_duration
	_begin_skill("ability1")
	_play_action_anim("ability1")
	_capture_skill_anim()
	_do_ability1(aim_dir, aim_pos)

func ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ability2() or is_dead:
		return
	ability2_cd = ability2_cooldown
	ability2_anim_timer = ability2_anim_duration
	_begin_skill("ability2")
	_play_action_anim("ability2")
	_capture_skill_anim()
	_do_ability2(aim_dir, aim_pos)

func ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ult() or is_dead:
		return
	ult_points = 0
	ult_changed.emit(ult_points, max_ult_points)
	ult_anim_timer = ult_anim_duration
	_begin_skill("ult")
	_play_action_anim("ult")
	_capture_skill_anim()
	_do_ult(aim_dir, aim_pos)

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	pass

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	pass

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	pass

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
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

# Called from player class. Removes ability to interact with world. 
# The following is disabled when a character enters the spectate state
# From Hero:		Sprite visibility
# added not is_dead to can_shoot() requirement. Player is_dead should be set externally
func enter_spectate_mode() -> void:
	disable_sprite()


func disable_sprite() -> void:
	var hero_sprite = get_node_or_null("Sprite")
	if hero_sprite and hero_sprite is AnimatedSprite2D:
		hero_sprite.visible = false 

func _begin_skill(skill: String) -> void:
	lock_skill = skill

func _play_action_anim(kind: String) -> void:
	var moving: bool = false
	if player and "velocity" in player:
		moving = player.velocity.length() > 10
	if kind == "shoot":
		if moving:
			_play_anim_candidates(PackedStringArray(["shoot_run", "shoot_idle", "shoot", "idle"]), "shoot")
		else:
			_play_anim_candidates(PackedStringArray(["shoot_idle", "shoot", "idle"]), "shoot")
		return
	if kind == "reload":
		if moving:
			_play_anim_candidates(PackedStringArray(["reload_run", "reload_idle", "reload", "idle"]), "reload")
		else:
			_play_anim_candidates(PackedStringArray(["reload_idle", "reload", "idle"]), "reload")
		return
	if kind == "ability1":
		if moving:
			_play_anim_candidates(PackedStringArray(["ability1_run", "ability1_idle", "ability1", "idle"]), "ability1")
		else:
			_play_anim_candidates(PackedStringArray(["ability1_idle", "ability1", "idle"]), "ability1")
		return
	if kind == "ability2":
		if moving:
			_play_anim_candidates(PackedStringArray(["ability2_run", "ability2_idle", "ability2", "idle"]), "ability2")
		else:
			_play_anim_candidates(PackedStringArray(["ability2_idle", "ability2", "idle"]), "ability2")
		return
	if kind == "ult":
		_play_anim_candidates(PackedStringArray(["ult_idle", "ult", "idle"]), "ult")
		return
	if kind == "death":
		_play_anim_candidates(PackedStringArray(["death", "idle"]), "death")
		return

func _play_anim_candidates(cands: PackedStringArray, req: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		_warn_missing_anim(req, cands)
		return
	for name in cands:
		if sprite.sprite_frames.has_animation(name):
			current_anim = name
			sprite.play(name)
			return
	_warn_missing_anim(req, cands)

func _warn_missing_anim(req: String, cands: PackedStringArray) -> void:
	var key := req + "|" + ",".join(cands)
	if missing_anim_warn.has(key):
		return
	missing_anim_warn[key] = true
	print("Hero anim missing for ", get_hero_name(), " request=", req, " candidates=", ",".join(cands))

func _capture_skill_anim() -> void:
	if sprite == null:
		return
	var anim := sprite.animation
	if anim == &"":
		lock_skill = ""
		return
	var anim_name := String(anim)
	if anim_name == "idle" or anim_name == "run":
		lock_skill = ""
		return
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		lock_skill = ""
		return
	if sprite.sprite_frames.get_animation_loop(anim_name):
		lock_skill = ""
		return
	lock_anim = anim_name
	current_anim = anim_name
	anim_locked = true

func _update_anim_lock() -> void:
	if not anim_locked:
		return
	if sprite == null or lock_anim == "":
		_clear_anim_lock()
		return
	if String(sprite.animation) != lock_anim:
		_clear_anim_lock()
		return
	if sprite.is_playing():
		return
	_clear_anim_lock()

func _clear_anim_lock() -> void:
	anim_locked = false
	lock_anim = ""
	lock_skill = ""

func _on_sprite_animation_finished() -> void:
	_update_anim_lock()

func _is_action_blocked() -> bool:
	if not anim_locked:
		return false
	if lock_skill == "shoot":
		return not shoot_actionable
	if lock_skill == "ability1":
		return not ability1_actionable
	if lock_skill == "ability2":
		return not ability2_actionable
	if lock_skill == "ult":
		return not ult_actionable
	return false
