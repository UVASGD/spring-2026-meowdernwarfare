class_name MuskratCybertruckLine
extends Node2D

@export var damage: float = 22.0
@export var life: float = 1.0
@export var width: float = 22.0

var owner_player: Player = null
var authoritative := true

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _hit: Dictionary = {}
var _left: float = 0.0

@onready var _line: Line2D = $Line2D
@onready var _area: Area2D = $Area2D
@onready var _shape: CollisionShape2D = $Area2D/CollisionShape2D

func setup(a: Vector2, b: Vector2) -> void:
	_from = a
	_to = b

func _ready() -> void:
	_left = life
	_sync_shape()
	_area.body_entered.connect(_on_body_entered)
	_hit_overlaps()

func _process(delta: float) -> void:
	_left -= delta
	if _line:
		_line.modulate.a = clamp(_left / maxf(life, 0.001), 0.0, 1.0)
	if _left <= 0.0:
		queue_free()

func _sync_shape() -> void:
	var diff := _to - _from
	var seg_len := maxf(diff.length(), 1.0)
	global_position = (_from + _to) * 0.5
	rotation = diff.angle()
	if _line:
		_line.clear_points()
		_line.width = width
		_line.add_point(Vector2(-seg_len * 0.5, 0.0))
		_line.add_point(Vector2(seg_len * 0.5, 0.0))
	if _shape and _shape.shape is RectangleShape2D:
		var rect := _shape.shape as RectangleShape2D
		rect.size = Vector2(seg_len, maxf(width, 4.0))

func _hit_overlaps() -> void:
	if not authoritative or _area == null:
		return
	for b in _area.get_overlapping_bodies():
		_try_hit(b)

func _on_body_entered(body: Node) -> void:
	if not authoritative:
		return
	_try_hit(body)

func _try_hit(body: Node) -> void:
	if not (body is Player):
		return
	var p := body as Player
	if p == owner_player:
		return
	var key := p.get_instance_id()
	if _hit.has(key):
		return
	_hit[key] = true
	p.take_damage(damage, owner_player)
