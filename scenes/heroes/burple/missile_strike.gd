class_name BurpleMissileStrike
extends Node2D

const ExplosionScene = preload("res://scenes/explosion_visual.tscn")

@export var zone_radius: float = 300.0
@export var pulse_damage: float = 10.0
@export var pulse_interval: float = 0.45
@export var duration: float = 4.5

var owner_player: Player = null
var strike_id := ""
var authoritative := true

var _time_left := 0.0
var _pulse_left := 0.0
var _done := false

@onready var _ring: Sprite2D = $Ring

func _ready() -> void:
	_time_left = duration
	_pulse_left = pulse_interval
	_sync_ring()

func _process(delta: float) -> void:
	if _done:
		return
	if _ring:
		_ring.modulate.a = 0.14 + 0.06 * sin(Time.get_ticks_msec() / 130.0)
	if not authoritative:
		return
	_time_left -= delta
	_pulse_left -= delta
	if _pulse_left <= 0.0:
		_pulse_left += pulse_interval
		_pulse()
	if _time_left <= 0.0:
		_finish(true)

func play_pulse() -> void:
	if _done:
		return
	_spawn_fx()

func force_end() -> void:
	_finish(false)

func _pulse() -> void:
	if _done:
		return
	_apply_damage()
	_spawn_fx()
	var gm := GameManager.instance
	if gm and gm.mode == GameManager.Mode.ONLINE_HOST:
		gm.report_burple_strike_pulse(strike_id)

func _apply_damage() -> void:
	var r2 := zone_radius * zone_radius
	for node in get_tree().get_nodes_in_group("players"):
		if not node is Player:
			continue
		var pl := node as Player
		if pl == owner_player:
			continue
		if pl.global_position.distance_squared_to(global_position) > r2:
			continue
		pl.take_damage(pulse_damage, owner_player)

func _spawn_fx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fx: Node2D = ExplosionScene.instantiate() as Node2D
	fx.global_position = global_position
	var s: float = max(zone_radius / 220.0, 0.75)
	fx.scale = Vector2.ONE * s
	get_tree().current_scene.add_child(fx)

func _sync_ring() -> void:
	if _ring == null:
		return
	var s: float = max(zone_radius / 64.0, 1.0)
	_ring.scale = Vector2.ONE * s

func _finish(notify: bool) -> void:
	if _done:
		return
	_done = true
	if notify:
		var gm := GameManager.instance
		if gm and gm.mode == GameManager.Mode.ONLINE_HOST:
			gm.report_burple_strike_end(strike_id)
	queue_free()
