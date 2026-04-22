class_name MuskratCybertruckUlt
extends Node2D

const LineScene = preload("res://scenes/heroes/elonmusk/cybertruck_line.tscn")

@export var zone_radius: float = 420.0
@export var teleport_cd: float = 0.5
@export var duration: float = 10.0
@export var line_damage: float = 22.0
@export var line_life: float = 1.0
@export var explosion_damage: float = 40.0
@export var intro_time: float = 0.7

var owner_player: Player = null
var ult_id := ""
var authoritative := true

var center := Vector2.ZERO
var _truck := Vector2.ZERO
var _tp_left := 0.0
var _ult_left := 0.0
var _intro_left := 0.0
var _ended := false
var _can_control := false

@onready var _zone: Line2D = $Zone
@onready var _truck_node: Node2D = $Truck
@onready var _truck_body: AnimatedSprite2D = $Truck/Body
@onready var _truck_glow: PointLight2D = $Truck/Glow
@onready var _boom: ColorRect = $Boom

func _ready() -> void:
	center = global_position
	var vp_w := get_viewport_rect().size.x
	_truck = Vector2(center.x + vp_w * 0.7, center.y)
	_ult_left = duration
	_tp_left = 0.0
	_intro_left = intro_time
	_sync_visuals()

func _process(delta: float) -> void:
	if _ended:
		return
	_tick_intro(delta)
	_sync_visuals()
	if not _can_control:
		return
	if authoritative:
		_tp_left = maxf(0.0, _tp_left - delta)
		_ult_left -= delta
		_try_local_control()
		if _ult_left <= 0.0:
			_end_ult()
	elif _is_owner_local():
		_try_remote_tp_request()
	if _zone:
		_zone.modulate.a = 0.22 + 0.05 * sin(Time.get_ticks_msec() / 170.0)

func request_tp(target: Vector2) -> void:
	if not authoritative or _ended or not _can_control or _tp_left > 0.0:
		return
	var next := _clamp_to_zone(target)
	if _ult_left <= teleport_cd + 0.05:
		next = center
	_do_tp(next, true)

func play_remote_tp(a: Vector2, b: Vector2) -> void:
	if _ended:
		return
	_spawn_line(a, b, false)
	_truck = b
	_tp_left = teleport_cd

func force_end_remote() -> void:
	if _ended:
		return
	_end_ult(false)

func _tick_intro(delta: float) -> void:
	if _intro_left <= 0.0:
		_can_control = true
		return
	_intro_left -= delta
	var t: float = 1.0 - clamp(_intro_left / maxf(intro_time, 0.001), 0.0, 1.0)
	_truck = _truck.lerp(center, t)
	if _intro_left <= 0.0:
		_truck = center
		_can_control = true

func _try_local_control() -> void:
	if owner_player == null or owner_player.input == null:
		return
	if owner_player.input.shoot_just:
		request_tp(owner_player.get_aim_position())

func _try_remote_tp_request() -> void:
	if owner_player == null or owner_player.input == null:
		return
	if not owner_player.input.shoot_just:
		return
	var gm := GameManager.instance
	if gm == null or gm.mode != GameManager.Mode.ONLINE_CLIENT:
		return
	Network.send_to_host({
		"type": "muskrat_ult_tp_req",
		"uid": ult_id,
		"x": owner_player.get_aim_position().x,
		"y": owner_player.get_aim_position().y,
	})

func _do_tp(next: Vector2, notify: bool) -> void:
	var start := _truck
	_truck = next
	_tp_left = teleport_cd
	_spawn_line(start, next, authoritative)
	if notify:
		var gm := GameManager.instance
		if gm and gm.mode == GameManager.Mode.ONLINE_HOST:
			gm.report_muskrat_ult_tp(ult_id, start, next)

func _spawn_line(a: Vector2, b: Vector2, deal_damage: bool) -> void:
	if a.distance_squared_to(b) < 1.0:
		return
	var line = LineScene.instantiate()
	line.owner_player = owner_player
	line.authoritative = deal_damage
	line.damage = line_damage
	line.life = line_life
	line.setup(a, b)
	get_tree().current_scene.add_child(line)

func _end_ult(notify := true) -> void:
	if _ended:
		return
	_ended = true
	if _truck.distance_to(center) > 1.0:
		_spawn_line(_truck, center, authoritative)
		_truck = center
	_apply_explosion()
	if notify:
		var gm := GameManager.instance
		if gm and gm.mode == GameManager.Mode.ONLINE_HOST:
			gm.report_muskrat_ult_end(ult_id)
	await get_tree().create_timer(0.22).timeout
	queue_free()

func _apply_explosion() -> void:
	if _boom:
		_boom.visible = true
		_boom.modulate.a = 0.9
		var tw := create_tween()
		tw.tween_property(_boom, "modulate:a", 0.0, 0.2)
	if not authoritative:
		return
	var r2 := zone_radius * zone_radius
	for n in get_tree().get_nodes_in_group("players"):
		if not (n is Player):
			continue
		var p := n as Player
		if p == owner_player:
			continue
		if p.global_position.distance_squared_to(center) <= r2:
			p.take_damage(explosion_damage, owner_player)

func _clamp_to_zone(target: Vector2) -> Vector2:
	var off := target - center
	if off.length() <= zone_radius:
		return target
	return center + off.normalized() * zone_radius

func _is_owner_local() -> bool:
	if owner_player == null or owner_player.input == null:
		return false
	if owner_player.input is LocalInput:
		return owner_player.player_id == 0
	if owner_player.input is NetworkInput:
		return owner_player.input.is_local
	return false

func _sync_visuals() -> void:
	global_position = center
	if _truck_node:
		_truck_node.global_position = _truck
	if _zone:
		_zone.clear_points()
		var steps := 40
		for i in range(steps + 1):
			var a := TAU * float(i) / float(steps)
			_zone.add_point(Vector2(cos(a), sin(a)) * zone_radius)
	if _truck_body:
		_truck_body.modulate = Color(0.58, 0.62, 0.78, 0.95) if _can_control else Color(0.42, 0.42, 0.45, 0.95)
	if _truck_glow:
		_truck_glow.energy = 1.0 if _can_control else 0.35
