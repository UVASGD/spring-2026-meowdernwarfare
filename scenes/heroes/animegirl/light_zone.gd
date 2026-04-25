class_name AnimeGirlLightZone
extends Node2D

const FlashLightScene = preload("res://scenes/heroes/animegirl/light_flash.tscn")

@export var zone_radius: float = 180.0
@export var pulse_damage: float = 7.0
@export var pulse_interval: float = 0.25
@export var duration: float = 3.5
@export var kind: int = 1
@export var min_pool_lights: int = 10
@export var max_pool_lights: int = 20
@export var pulse_min_lights: int = 5
@export var pulse_max_lights: int = 10
@export var light_fade_rate: float = 48.0

var owner_player: Player = null
var zone_id := ""
var authoritative := true

var _time_left := 0.0
var _pulse_left := 0.0
var _done := false
var _viz_rng := RandomNumberGenerator.new()
var _lights: Array[PointLight2D] = []

func _ready() -> void:
	_time_left = duration
	_pulse_left = pulse_interval
	z_index = -1
	_viz_rng.randomize()
	_build_light_pool()

func _process(delta: float) -> void:
	if _done:
		return
	_decay_lights(delta)
	if authoritative:
		_time_left -= delta
		_pulse_left -= delta
		if _pulse_left <= 0.0:
			_pulse_left += pulse_interval
			_pulse()
		if _time_left <= 0.0:
			_finish(true)
	queue_redraw()

func _draw() -> void:
	var col := _base_color()
	var t := Time.get_ticks_msec() / 1000.0
	var osc := 0.6 + 0.4 * sin(t * 8.0)
	draw_circle(Vector2.ZERO, zone_radius, Color(col.r, col.g, col.b, 0.18 + 0.08 * osc))
	draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.9), 4.0)

func play_pulse() -> void:
	if _done:
		return
	_spawn_flash_lights()

func force_end() -> void:
	_finish(false)

func _pulse() -> void:
	if _done:
		return
	_apply_damage()
	_spawn_flash_lights()
	var gm := GameManager.instance
	if gm and gm.mode == GameManager.Mode.ONLINE_HOST:
		gm.report_animegirl_zone_pulse(zone_id)

func _apply_damage() -> void:
	var r2 := zone_radius * zone_radius
	for node in get_tree().get_nodes_in_group("players"):
		if not (node is Player):
			continue
		var pl := node as Player
		if pl == owner_player:
			continue
		if pl.global_position.distance_squared_to(global_position) > r2:
			continue
		pl.take_damage(pulse_damage, owner_player)

func _spawn_flash_lights() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _lights.is_empty():
		return
	var c := _base_color()
	var count_min := mini(pulse_min_lights, _lights.size())
	var count_max := mini(pulse_max_lights, _lights.size())
	var n := _viz_rng.randi_range(count_min, maxi(count_min, count_max))
	var picks := _lights.duplicate()
	picks.shuffle()
	for i in range(n):
		var l = picks[i]
		l.color = Color(c.r, c.g, c.b, 1.0)
		var angle := _viz_rng.randf_range(0.0, TAU)
		var dist := _viz_rng.randf_range(0.0, zone_radius)
		l.position = Vector2(cos(angle), sin(angle)) * dist
		l.energy = _viz_rng.randf_range(3.2, 6.6)
		l.texture_scale = _viz_rng.randf_range(0.9, 2.4)
		l.z_index = 1

func _build_light_pool() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var pool_min := maxi(1, min_pool_lights)
	var pool_max := maxi(pool_min, max_pool_lights)
	var pool_size := _viz_rng.randi_range(pool_min, pool_max)
	for i in range(pool_size):
		var l := FlashLightScene.instantiate() as PointLight2D
		if l == null:
			continue
		l.energy = 0.0
		l.color = _base_color()
		l.z_index = 1
		add_child(l)
		_lights.append(l)

func _decay_lights(delta: float) -> void:
	for l in _lights:
		if l == null:
			continue
		l.energy = maxf(0.0, l.energy - light_fade_rate * delta)

func _finish(notify: bool) -> void:
	if _done:
		return
	_done = true
	if notify:
		var gm := GameManager.instance
		if gm and gm.mode == GameManager.Mode.ONLINE_HOST:
			gm.report_animegirl_zone_end(zone_id)
	queue_free()

func _base_color() -> Color:
	if kind == 2:
		return Color(1.0, 0.95, 0.65, 1.0)
	return Color(1.0, 0.55, 0.86, 1.0)
