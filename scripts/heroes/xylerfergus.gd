class_name HeroXylerFergus
extends Hero

const FergusBulletScene = preload("res://scenes/heroes/xylerfergus/fergus_bullet.tscn")

enum Stance { XYLER, FERGUS }

@export_group("Xyler")
@export var xyler_move_mult: float = 0.72
@export var xyler_melee_damage: int = 34
@export var xyler_shoot_cooldown: float = 0.34

@export_group("Fergus")
@export var fergus_move_mult: float = 1.22
@export var fergus_bullet_damage: int = 8
@export var fergus_bullet_speed: float = 1080.0
@export var fergus_shoot_cooldown: float = 0.22

@export_group("Ult — Xyler")
@export var xyler_ult_duration: float = 8.0
@export var xyler_ult_move_bonus: float = 1.35
@export var xyler_ult_damage_bonus: float = 1.45

@export_group("Ult — Fergus")
@export var fergus_ult_duration: float = 10.0
@export var fergus_ult_bullet_speed_mult: float = 1.5
@export_range(1, 100, 1) var fergus_marks_for_slash: int = 10

@onready var _sprite_xyler: AnimatedSprite2D = $SpriteXyler
@onready var _sprite_fergus: AnimatedSprite2D = $SpriteFergus
@onready var hurtbox: HeroHurtbox = $hurtbox

var stance: Stance = Stance.XYLER
var _xyler_ult_t: float = 0.0
var _fergus_ult_t: float = 0.0

var _base_xyler_move: float = 0.72
var _base_fergus_move: float = 1.22

func get_hero_name() -> String:
	return "XylerFergus"

func _ready() -> void:
	_base_xyler_move = xyler_move_mult
	_base_fergus_move = fergus_move_mult
	_setup_placeholder_frames(_sprite_xyler, Color(0.65, 0.82, 1.0, 1.0))
	_setup_placeholder_frames(_sprite_fergus, Color(1.0, 0.78, 0.55, 1.0))
	super._ready()
	_apply_stance(true)

func _process(delta: float) -> void:
	super._process(delta)
	if _xyler_ult_t > 0.0:
		_xyler_ult_t = maxf(0.0, _xyler_ult_t - delta)
		if _xyler_ult_t <= 0.0 and stance == Stance.XYLER:
			_refresh_xyler_move()
	if _fergus_ult_t > 0.0:
		_fergus_ult_t = maxf(0.0, _fergus_ult_t - delta)

func _setup_placeholder_frames(node: AnimatedSprite2D, tint: Color) -> void:
	var tex: Texture2D = load("res://assets/sprites/icon.svg") as Texture2D
	if tex == null:
		return
	var sf := SpriteFrames.new()
	for anim_name in ["idle", "run", "shoot", "melee", "ability1", "ult", "reload", "death"]:
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
			sf.set_animation_loop(anim_name, anim_name == "idle" or anim_name == "run")
		sf.add_frame(anim_name, tex, 1.0)
	node.sprite_frames = sf
	node.modulate = tint

func uses_gun_ammo() -> bool:
	return stance == Stance.FERGUS

func allows_movement_dash() -> bool:
	return true

func can_shoot() -> bool:
	if stance == Stance.XYLER:
		return shoot_cd <= 0.0 and reload_cd <= 0.0 and not is_dead and not _is_action_blocked()
	return super.can_shoot()

func reload() -> void:
	if stance == Stance.XYLER:
		return
	super.reload()

func is_fergus_ult_active() -> bool:
	return _fergus_ult_t > 0.0

func is_xyler_ult_active() -> bool:
	return _xyler_ult_t > 0.0

func shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if stance == Stance.XYLER:
		if not can_shoot():
			return
		_begin_skill("shoot")
		current_anim = "melee"
		sprite.play("melee")
		_capture_skill_anim()
		_do_shoot(aim_dir, aim_pos)
		return
	super.shoot(aim_dir, aim_pos)

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if stance == Stance.XYLER:
		var dmg: int = int(round(float(xyler_melee_damage) * (_xyler_ult_damage_mult())))
		hurtbox.damage = dmg
		hurtbox.start_swing(HeroHurtbox.SwingMode.MELEE)
		await sprite.animation_finished
		hurtbox.end_swing()
		shoot_cd = xyler_shoot_cooldown
		shot.emit()
		return
	var bullet = FergusBulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	bullet.damage = fergus_bullet_damage
	bullet.speed = _fergus_bullet_speed_effective()
	bullet.global_position = player.global_position + aim_dir * 28.0
	bullet.rotation = aim_dir.angle()
	get_tree().current_scene.add_child(bullet)

func _xyler_ult_damage_mult() -> float:
	if _xyler_ult_t > 0.0:
		return xyler_ult_damage_bonus
	return 1.0

func _fergus_bullet_speed_effective() -> float:
	var s := fergus_bullet_speed
	if _fergus_ult_t > 0.0:
		s *= fergus_ult_bullet_speed_mult
	return s

func _refresh_xyler_move() -> void:
	if stance != Stance.XYLER:
		return
	var m := _base_xyler_move
	if _xyler_ult_t > 0.0:
		m *= xyler_ult_move_bonus
	move_speed_mult = m
	hurtbox.damage = int(round(float(xyler_melee_damage) * _xyler_ult_damage_mult()))

func _do_ability1(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
	stance = Stance.FERGUS if stance == Stance.XYLER else Stance.XYLER
	_apply_stance(false)
	var gm := GameManager.instance
	if gm:
		gm.sync_xf_stance(player.player_id, int(stance))

func apply_remote_stance(st: int) -> void:
	var new_stance: Stance = Stance.XYLER if st == 0 else Stance.FERGUS
	if new_stance == stance:
		return
	stance = new_stance
	_apply_stance(true)

func _apply_stance(from_remote: bool) -> void:
	if _sprite_xyler:
		_sprite_xyler.visible = stance == Stance.XYLER
	if _sprite_fergus:
		_sprite_fergus.visible = stance == Stance.FERGUS
	if sprite and sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	sprite = _sprite_xyler if stance == Stance.XYLER else _sprite_fergus
	if sprite and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	if stance == Stance.XYLER:
		move_speed_mult = _base_xyler_move * (xyler_ult_move_bonus if _xyler_ult_t > 0.0 else 1.0)
		shoot_cooldown = xyler_shoot_cooldown
		reload_cd = 0.0
		hurtbox.damage = int(round(float(xyler_melee_damage) * _xyler_ult_damage_mult()))
		shoot_actionable = false
	else:
		move_speed_mult = _base_fergus_move
		shoot_cooldown = fergus_shoot_cooldown
		ammo = mag_size
		shoot_actionable = true
	_refresh_xyler_move()
	if not from_remote and stance == Stance.FERGUS:
		reload_cd = 0.0

func _do_ult(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
	if stance == Stance.XYLER:
		_xyler_ult_t = xyler_ult_duration
		_refresh_xyler_move()
		hurtbox.damage = int(round(float(xyler_melee_damage) * _xyler_ult_damage_mult()))
	else:
		_fergus_ult_t = fergus_ult_duration
