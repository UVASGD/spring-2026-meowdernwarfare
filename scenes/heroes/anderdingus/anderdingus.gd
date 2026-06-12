class_name HeroAnderDingus
extends Hero

const BulletScene = preload("res://scenes/heroes/dealer/bullet.tscn")
const UltSfx = preload("res://assets/sound/music/anderdingus.mp3")

@export var ult_strike_count: int = 26
@export var ult_spread_pad: float = 380.0

var _orbital_seq := 0

func _ready() -> void:
	ult_mode = UltMode.COOLDOWN
	if ult_cooldown <= 0.0:
		ult_cooldown = 10.0
	super._ready()
	ammo = mag_size

func get_hero_name() -> String:
	return "AnderDingus"

func can_ability1() -> bool:
	return false

func can_ability2() -> bool:
	return false

func can_shoot() -> bool:
	return shoot_cd <= 0.0 and not is_dead and not _is_action_blocked()

func uses_gun_ammo() -> bool:
	return false

func shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_shoot():
		return
	shoot_cd = shoot_cooldown
	_begin_skill("shoot")
	_play_action_anim("shoot")
	_capture_skill_anim()
	shot.emit()
	_do_shoot(aim_dir, aim_pos)

func _do_shoot(aim_dir: Vector2, _aim_pos: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	bullet.global_position = player.global_position + aim_dir * 30.0
	bullet.rotation = aim_dir.angle()
	get_tree().current_scene.add_child(bullet)

func _do_ult(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
	var gm := GameManager.instance
	if gm == null or player == null:
		return
	if not gm.is_local() and player.player_id != gm.local_player_id:
		return
	_orbital_seq += 1
	if gm.mode == GameManager.Mode.ONLINE_CLIENT:
		Network.send_to_host({
			"type": "dingus_ult_req",
			"pid": player.player_id,
			"seq": _orbital_seq
		})
		return
	gm._roll_and_cast_dingus_ult(player, _orbital_seq)

func _play_ult_sfx() -> void:
	if UltSfx == null:
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = UltSfx
	s.volume_db = -6.0
	s.global_position = player.global_position
	get_tree().current_scene.add_child(s)
	s.finished.connect(s.queue_free)
	s.play()

func _get_map_area() -> Rect2:
	var min_v := Vector2.INF
	var max_v := -Vector2.INF
	for f in get_tree().get_nodes_in_group("farms"):
		if not (f is Node2D):
			continue
		var p := (f as Node2D).global_position
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	for p in get_tree().get_nodes_in_group("players"):
		if not (p is Node2D):
			continue
		var v := (p as Node2D).global_position
		min_v = min_v.min(v)
		max_v = max_v.max(v)
	if min_v.x == INF:
		var center := player.global_position if player else Vector2.ZERO
		return Rect2(center - Vector2(1200.0, 1200.0), Vector2(2400.0, 2400.0))
	min_v -= Vector2.ONE * ult_spread_pad
	max_v += Vector2.ONE * ult_spread_pad
	return Rect2(min_v, max_v - min_v)
