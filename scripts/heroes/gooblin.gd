class_name HeroGooblin
extends Hero

const BulletScene = preload("res://scenes/heroes/gooblin/gooblin_tear.tscn")
const BoogieBombScene = preload("res://scenes/heroes/gooblin/boogie_bomb.tscn")
const DrooglinFireScene = preload("res://scenes/heroes/gooblin/drooglin_fire.tscn")

@export var blind_duration: float = 3.0
@export var retreat_speed_mult: float = 2.0
@export var retreat_duration: float = 2.5
@export var fire_duration: float = 30.0

var _shoot_left: bool = true
var retreat_timer: float = 0.0
var _base_speed_mult: float = 1.0
var _pending_bomb: bool = false
var _pending_bomb_aim_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	_base_speed_mult = move_speed_mult
	if sprite and not sprite.animation_finished.is_connected(_on_ability1_anim_finished):
		sprite.animation_finished.connect(_on_ability1_anim_finished)

func _process(delta: float) -> void:
	super._process(delta)
	if retreat_timer > 0:
		retreat_timer -= delta
		if retreat_timer <= 0:
			_end_retreat()

func get_hero_name() -> String:
	return "Gooblin"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var left_eye = get_node_or_null("LeftEye")
	var right_eye = get_node_or_null("RightEye")
	var origin_node = left_eye if _shoot_left else right_eye
	_shoot_left = not _shoot_left

	var bullet = BulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	if origin_node:
		bullet.global_position = origin_node.global_position
	else:
		bullet.global_position = player.global_position + aim_dir * 30
	bullet.rotation = aim_dir.angle()
	get_tree().current_scene.add_child(bullet)

# Boogie Bomb: spawn after ability1_idle or ability1_run finishes
func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	_pending_bomb = true
	_pending_bomb_aim_dir = aim_dir

func _on_ability1_anim_finished() -> void:
	if not _pending_bomb or sprite == null or is_dead:
		return
	var anim := String(sprite.animation)
	if anim != "ability1_idle" and anim != "ability1_run" and anim != "ability1":
		return
	_pending_bomb = false
	var aim_dir := _pending_bomb_aim_dir
	var bomb = BoogieBombScene.instantiate()
	bomb.direction = aim_dir
	bomb.owner_player = player
	bomb.blind_duration = blind_duration
	bomb.global_position = player.global_position + aim_dir * 40
	bomb.rotation = aim_dir.angle()
	get_tree().current_scene.add_child(bomb)

# Retreat: temporary speed boost
func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	retreat_timer = retreat_duration
	move_speed_mult = _base_speed_mult * retreat_speed_mult

func _end_retreat() -> void:
	move_speed_mult = _base_speed_mult

# Summon Drooglin: place fire at every farm entrance (caster is immune to damage)
func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var farms = get_tree().get_nodes_in_group("farms")
	for farm in farms:
		var entrance = farm.get_node_or_null("entrance")
		if entrance == null:
			continue
		var fire = DrooglinFireScene.instantiate()
		fire.owner_player = player
		fire.duration = fire_duration
		fire.global_position = entrance.global_position
		get_tree().current_scene.add_child(fire)
