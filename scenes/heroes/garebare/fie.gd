extends StaticBody2D

@export var hp: float = 30.0
@export var suppress_radius: float = 150.0

var owner_player: Player = null

@onready var suppress_zone: Area2D = $SuppressionZone

signal destroyed

const COLOR_FRIENDLY := Color(0.3, 0.8, 1.0)
const COLOR_ENEMY := Color(1.0, 0.25, 0.2)

func _ready() -> void:
	var zone_shape = suppress_zone.get_node("Shape") as CollisionShape2D
	if zone_shape and zone_shape.shape is CircleShape2D:
		zone_shape.shape.radius = suppress_radius

	suppress_zone.body_entered.connect(_on_zone_entered)
	suppress_zone.body_exited.connect(_on_zone_exited)

	var c = COLOR_FRIENDLY if _is_local_owner() else COLOR_ENEMY
	$Sprite.modulate = Color(c.r, c.g, c.b, 0.8)
	add_child(_create_ring(c))

func _is_local_owner() -> bool:
	if owner_player == null:
		return false
	if GameManager.instance:
		return GameManager.instance.get_local_player() == owner_player
	return owner_player.player_id == 0

func take_damage(amount: float, _attacker: Player = null) -> void:
	hp -= amount
	if hp <= 0:
		_destroy()

func _destroy() -> void:
	for body in suppress_zone.get_overlapping_bodies():
		if body is Player and body != owner_player:
			body.fie_suppress_count = max(0, body.fie_suppress_count - 1)
	destroyed.emit()
	queue_free()

func detonate(damage: float) -> void:
	for body in suppress_zone.get_overlapping_bodies():
		if body is Player and body != owner_player:
			body.take_damage(damage, owner_player)
	_destroy()

func _on_zone_entered(body: Node) -> void:
	if body is Player and body != owner_player:
		body.fie_suppress_count += 1

func _on_zone_exited(body: Node) -> void:
	if body is Player and body != owner_player:
		body.fie_suppress_count = max(0, body.fie_suppress_count - 1)

func _create_ring(c: Color) -> Node2D:
	var ring = Node2D.new()
	var pts = 48
	for i in range(pts):
		var seg = Line2D.new()
		var a1 = TAU * i / pts
		var a2 = TAU * (i + 1) / pts
		seg.add_point(Vector2(cos(a1), sin(a1)) * suppress_radius)
		seg.add_point(Vector2(cos(a2), sin(a2)) * suppress_radius)
		seg.width = 1.5
		seg.default_color = Color(c.r, c.g, c.b, 0.35)
		ring.add_child(seg)
	return ring
