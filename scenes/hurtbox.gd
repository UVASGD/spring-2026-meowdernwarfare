extends Node2D

@export var damage : int
var owner_player
var hit_map := {}
@onready var area: Area2D = $Area2D

func _ready() -> void:
	owner_player = get_parent().get_parent()

func start_swing() -> void:
	hit_map.clear()
	area.monitoring = true
	_hit_overlaps()

func end_swing() -> void:
	area.monitoring = false
	hit_map.clear()
	

func _on_area_2d_body_entered(body: Node2D) -> void:
	if area.monitoring: 
		_try_hit(body)

func _hit_overlaps() -> void:
	if not area.monitoring:
		return 
	for body in area.get_overlapping_bodies():
		_try_hit(body)

func _try_hit(body: Node2D) -> void:
	if body == owner_player:
		return

	var body_id := body.get_instance_id()
	if hit_map.has(body_id):
		return
	hit_map[body_id] = true

	if body is Player:
		body.take_damage(damage, owner_player)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
