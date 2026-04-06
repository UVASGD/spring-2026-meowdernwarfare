class_name HeroBurple
extends Hero

const BulletScene = preload("res://scenes/heroes/dealer/bullet.tscn")

@export var grenade_range: float = Player.INTERACT_RANGE
@export var strike_range: float = Player.INTERACT_RANGE

var _grenade_id := 0
var _strike_id := 0

func get_hero_name() -> String:
	return "Burple"

func uses_ability1_targeting() -> bool:
	return true

func get_ability1_range() -> float:
	return grenade_range

func uses_ult_targeting() -> bool:
	return true

func get_ult_range() -> float:
	return strike_range

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	bullet.global_position = player.global_position + aim_dir * 30
	bullet.rotation = aim_dir.angle()
	get_tree().current_scene.add_child(bullet)

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var gm := GameManager.instance
	if gm == null or player == null:
		return
	if not gm.is_local() and player.player_id != gm.local_player_id:
		return
	_grenade_id += 1
	gm.cast_burple_grenade(player.player_id, aim_pos, "%s:%s" % [player.player_id, _grenade_id])

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var gm := GameManager.instance
	if gm == null or player == null:
		return
	if not gm.is_local() and player.player_id != gm.local_player_id:
		return
	_strike_id += 1
	gm.cast_burple_strike(player.player_id, aim_pos, "%s:%s" % [player.player_id, _strike_id])
