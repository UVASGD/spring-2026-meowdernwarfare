class_name Hero
extends Node2D

signal health_changed(current: float, max_hp: float)
signal ult_changed(current: int, max_points: int)
signal died

signal shot

signal ran_out_of_ammo
signal started_reload
signal finished_reload

signal used_ability_1
signal ability_1_refreshed
signal used_ult

const SfxEvent = preload("res://scripts/audio/sfx_event.gd")
const SfxBus = preload("res://scripts/audio/sfx_bus.gd")

enum UltMode { CHARGE, COOLDOWN }

# Stats 
@export_category("Hero Stats")
@export var max_health: float = 100.0
@export var move_speed_mult: float = 1.0

@export var shoot_cooldown: float = 0.3
@export var ability1_cooldown: float = 5.0
@export var ability2_cooldown: float = 0.0

# Ult. CHARGE heroes fill ult_points on hit/dodge; COOLDOWN heroes (e.g. Dingus) use ult_cd.
@export var ult_mode: UltMode = UltMode.CHARGE
@export var ult_cooldown: float = 0.0
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


#UI stuff
@export_category("Hero UI stuff")
@export var portrait_outline_color:Color = Color(1,1,1,1)
@export var normal_portrait: Texture2D
@export var ult_portrait: Texture2D
@export var portrait_offset: Vector2 = Vector2.ZERO
@export var ult_banner_portrait_offset: Vector2 = Vector2.ZERO
# State
var health: float = 100.0
var shoot_cd: float = 0.0
var ability1_cd: float = 0.0
var ability2_cd: float = 0.0
var reload_cd: float = 0.0
var is_dead: bool = false
var ammo: int = 15
var ult_points: int = 0
var ult_cd: float = 0.0
var _prev_shoot_cd_active: bool = false
var _prev_ability1_cd_active: bool = false
var _prev_ability2_cd_active: bool = false
var _prev_reload_cd_active: bool = false
var _prev_ult_ready: bool = false

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

# Default UI
const DEFAULT_HERO_UI_COLOR = Color.WHITE;
const ABILITY_ICON_TEMP_2 = preload("res://assets/ui/player/ability_icon_temp2.png")
const ABILITY_ICON_TEMP_1 = preload("res://assets/ui/player/ability_icon_temp1.png")
const PROFILE_ANGRY_PLACEHOLDER = preload("res://assets/ui/player/profile_angry_placeholder.png")
const PROFILE_PLACEHOLDER = preload("res://assets/ui/player/profile_placeholder.png")

func _ready() -> void:
	health = max_health
	ammo = mag_size
	_prev_shoot_cd_active = shoot_cd > 0.0
	_prev_ability1_cd_active = ability1_cd > 0.0
	_prev_ability2_cd_active = ability2_cd > 0.0
	_prev_reload_cd_active = reload_cd > 0.0
	_prev_ult_ready = can_ult()
	
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
	var shoot_was_on_cd := shoot_cd > 0.0
	shoot_cd = max(0, shoot_cd - delta)
	
	var ability1_was_on_cooldown = ability1_cd > 0;
	ability1_cd = max(0, ability1_cd - delta)
	ability2_cd = max(0, ability2_cd - delta)
	if ability1_was_on_cooldown and ability1_cd <= 0:
		ability_1_refreshed.emit();
	
	var was_reloading = reload_cd > 0
	reload_cd = max(0, reload_cd - delta)
	if was_reloading and reload_cd <= 0:
		ammo = mag_size
		finished_reload.emit();
		SfxBus.play_world(SfxEvent.WEAPON_RELOAD_DONE, player.global_position if player else global_position)
	
	if ult_mode == UltMode.COOLDOWN:
		ult_cd = max(0, ult_cd - delta)
	
	ability1_anim_timer = max(0, ability1_anim_timer - delta)
	ability2_anim_timer = max(0, ability2_anim_timer - delta)
	ult_anim_timer = max(0, ult_anim_timer - delta)

	_emit_cd_feedback(shoot_was_on_cd)

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
	SfxBus.play_world(SfxEvent.PLAYER_DEATH, player.global_position if player else global_position)
	died.emit()

func get_health_percent() -> float:
	return health / max_health

func get_health() -> float:
	return health;

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
	if _is_fie_suppressed() or _is_action_blocked() or is_dead:
		return false
	if ult_mode == UltMode.COOLDOWN:
		return ult_cd <= 0.0
	return ult_points >= max_ult_points

func uses_ability1_targeting() -> bool:
	return false

func get_ability1_range() -> float:
	return 0.0

func uses_ult_targeting() -> bool:
	return false

func get_ult_range() -> float:
	return 0.0

## If false, the player cannot use the default movement dash (space). Ability-based dashes still work.
func allows_movement_dash() -> bool:
	return true

## If false, hero has no magazine/reload (e.g. pure melee); UI and input skip ammo/reload.
func uses_gun_ammo() -> bool:
	return true

func shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_shoot():
		return
	shoot_cd = shoot_cooldown
	ammo -= 1
	_begin_skill("shoot")
	_play_action_anim("shoot")
	_capture_skill_anim()
	if ammo == 0:
		ran_out_of_ammo.emit()
	shot.emit();
	SfxBus.play_world(SfxEvent.WEAPON_SHOOT, player.global_position if player else global_position)
	_play_hero_sfx(&"shoot")
	_do_shoot(aim_dir, aim_pos)

func reload() -> void:
	if reload_cd > 0 or ammo == mag_size:
		return
	reload_cd = reload_time
	_begin_skill("reload")
	_play_action_anim("reload")
	_capture_skill_anim()
	started_reload.emit();
	SfxBus.play_world(SfxEvent.WEAPON_RELOAD_START, player.global_position if player else global_position)
	_do_reload()

func ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ability1() or is_dead:
		return
	ability1_cd = ability1_cooldown
	ability1_anim_timer = ability1_anim_duration
	_begin_skill("ability1")
	_play_action_anim("ability1")
	_capture_skill_anim()
	used_ability_1.emit();
	SfxBus.play_world(SfxEvent.ABILITY_1, player.global_position if player else global_position)
	_play_hero_sfx(&"ability1")
	_do_ability1(aim_dir, aim_pos)

func ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ability2() or is_dead:
		return
	ability2_cd = ability2_cooldown
	ability2_anim_timer = ability2_anim_duration
	_begin_skill("ability2")
	_play_action_anim("ability2")
	_capture_skill_anim()
	SfxBus.play_world(SfxEvent.ABILITY_2, player.global_position if player else global_position)
	_play_hero_sfx(&"ability2")
	_do_ability2(aim_dir, aim_pos)

func ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ult() or is_dead:
		return
	if ult_mode == UltMode.COOLDOWN:
		ult_cd = ult_cooldown
	else:
		ult_points = 0
	ult_changed.emit(ult_points, max_ult_points)
	ult_anim_timer = ult_anim_duration
	_begin_skill("ult")
	_play_action_anim("ult")
	_capture_skill_anim()
	used_ult.emit()
	SfxBus.play_world(SfxEvent.ABILITY_ULT, player.global_position if player else global_position)
	_play_hero_sfx(&"ult")
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

func _play_hero_sfx(kind: StringName) -> void:
	var ev: StringName = &""
	var hero_name := get_hero_name()
	match hero_name:
		"Dealer":
			if kind == &"ability1":
				ev = SfxEvent.DEALER_ABILITY_1
			elif kind == &"ability2":
				ev = SfxEvent.DEALER_ABILITY_2
			elif kind == &"ult":
				ev = SfxEvent.DEALER_ULT
		"Burple":
			if kind == &"ability1":
				ev = SfxEvent.BURPLE_ABILITY_1
			elif kind == &"ult":
				ev = SfxEvent.BURPLE_ULT
		"LoanShark":
			if kind == &"ability1":
				ev = SfxEvent.LOANSHARK_ABILITY_1
			elif kind == &"ability2":
				ev = SfxEvent.LOANSHARK_ABILITY_2
			elif kind == &"ult":
				ev = SfxEvent.LOANSHARK_ULT
		"Gooblin":
			if kind == &"ability1":
				ev = SfxEvent.GOOBLIN_ABILITY_1
			elif kind == &"ability2":
				ev = SfxEvent.GOOBLIN_ABILITY_2
			elif kind == &"ult":
				ev = SfxEvent.GOOBLIN_ULT
		"Garebare":
			if kind == &"ability1":
				ev = SfxEvent.GAREBARE_ABILITY_1
			elif kind == &"ability2":
				ev = SfxEvent.GAREBARE_ABILITY_2
			elif kind == &"ult":
				ev = SfxEvent.GAREBARE_ULT
		"ElonMusk":
			if kind == &"ability1":
				ev = SfxEvent.ELONMUSK_ABILITY_1
			elif kind == &"ult":
				ev = SfxEvent.ELONMUSK_ULT
		"AnderDingus":
			if kind == &"ult":
				ev = SfxEvent.ANDERDINGUS_ULT
		"XylerFergus":
			if kind == &"ability1":
				ev = SfxEvent.XYLER_FERGUS_SWAP
			elif kind == &"ult":
				ev = SfxEvent.XYLER_FERGUS_ULT
		_:
			pass
	if ev != &"":
		SfxBus.play_world(ev, player.global_position if player else global_position)

# ULT

func add_ult_points(amount: int) -> void:
	if ult_mode != UltMode.CHARGE:
		return
	var old = ult_points
	ult_points = min(max_ult_points, ult_points + amount)
	if ult_points != old:
		ult_changed.emit(ult_points, max_ult_points)
		if _is_local_feedback() and old < max_ult_points and ult_points >= max_ult_points:
			SfxBus.play_ui(SfxEvent.PLAYER_ULT_READY)

func get_ult_percent() -> float:
	if ult_mode == UltMode.COOLDOWN:
		if ult_cooldown <= 0.0:
			return 1.0
		return 1.0 - (ult_cd / ult_cooldown)
	return float(ult_points) / float(max_ult_points) if max_ult_points > 0 else 0.0

## Sets ability 1 cooldown to ready and emits ability_1_refreshed if it was on cooldown.
func refresh_ability1_cooldown() -> void:
	var was_on_cooldown := ability1_cd > 0.0
	ability1_cd = 0.0
	if was_on_cooldown:
		ability_1_refreshed.emit()

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
	push_warning("Hero anim missing for ", get_hero_name(), " request=", req, " candidates=", ",".join(cands))

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

# UI

func get_hero_default_profile() -> Texture2D:
	return normal_portrait if normal_portrait else PROFILE_PLACEHOLDER;

func get_hero_ult_profile() -> Texture2D:
	if ult_portrait:
		return ult_portrait
	if normal_portrait:
		return normal_portrait
	return PROFILE_ANGRY_PLACEHOLDER;

func get_hero_portrait_offset() -> Vector2:
	return portrait_offset

func get_hero_ult_banner_portrait_offset() -> Vector2:
	return ult_banner_portrait_offset

func get_hero_ability1_icon() -> Texture2D:
	return ABILITY_ICON_TEMP_1;

func get_hero_ability2_icon() -> Texture2D:
	return ABILITY_ICON_TEMP_2;

func get_hero_ui_color() -> Color:
	return DEFAULT_HERO_UI_COLOR;

func _emit_cd_feedback(shoot_was_on_cd: bool) -> void:
	if not _is_local_feedback():
		_prev_shoot_cd_active = shoot_cd > 0.0
		_prev_ability1_cd_active = ability1_cd > 0.0
		_prev_ability2_cd_active = ability2_cd > 0.0
		_prev_reload_cd_active = reload_cd > 0.0
		_prev_ult_ready = can_ult()
		return
	var shoot_on_cd := shoot_cd > 0.0
	var a1_on_cd := ability1_cd > 0.0
	var a2_on_cd := ability2_cd > 0.0
	var reload_on_cd := reload_cd > 0.0
	var ult_ready := can_ult()
	if shoot_was_on_cd and not shoot_on_cd:
		SfxBus.play_ui(SfxEvent.PLAYER_CD_READY)
	elif _prev_ability1_cd_active and not a1_on_cd:
		SfxBus.play_ui(SfxEvent.PLAYER_CD_READY)
	elif _prev_ability2_cd_active and not a2_on_cd:
		SfxBus.play_ui(SfxEvent.PLAYER_CD_READY)
	elif _prev_reload_cd_active and not reload_on_cd:
		SfxBus.play_ui(SfxEvent.PLAYER_CD_READY)
	if not _prev_ult_ready and ult_ready:
		SfxBus.play_ui(SfxEvent.PLAYER_ULT_READY)
	_prev_shoot_cd_active = shoot_on_cd
	_prev_ability1_cd_active = a1_on_cd
	_prev_ability2_cd_active = a2_on_cd
	_prev_reload_cd_active = reload_on_cd
	_prev_ult_ready = ult_ready

func _is_local_feedback() -> bool:
	if player == null or player.input == null:
		return false
	if player.input is LocalInput:
		return player.player_id == 0
	if player.input is NetworkInput:
		return player.input.is_local
	return false
