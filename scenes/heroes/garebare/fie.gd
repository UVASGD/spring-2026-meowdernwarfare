class_name FIE extends StaticBody2D

@export var hp: float = 30.0
@export var suppress_radius: float = 150.0

var owner_player: Player = null

@onready var suppress_zone: Area2D = $SuppressionZone
@onready var aoe: Sprite2D = $aoe
@onready var sprite: AnimatedSprite2D = $Sprite

signal destroyed

const COLOR_FRIENDLY := Color(0.3, 0.8, 1.0)
const COLOR_ENEMY := Color(1.0, 0.25, 0.2)
const GAREBARE_EXPLOSION = preload("res://scenes/heroes/garebare/garebare_explosion.tscn")

func _ready() -> void:

	var zone_shape = suppress_zone.get_node("Shape") as CollisionShape2D
	if zone_shape and zone_shape.shape is CircleShape2D:
		zone_shape.shape.radius = suppress_radius

	suppress_zone.body_entered.connect(_on_zone_entered)
	suppress_zone.body_exited.connect(_on_zone_exited)

	var c = COLOR_FRIENDLY if _is_local_owner() else COLOR_ENEMY
	$Sprite.modulate = Color(c.r, c.g, c.b, 1)
	aoe.material.set_shader_parameter("color", Color(c.r, c.g, c.b, 1))
	$PointLight2D.color = Color(c.r, c.g, c.b, 1)


func _is_local_owner() -> bool:
	if owner_player == null:
		return false
	if GameManager.instance:
		return GameManager.instance.get_local_player() == owner_player
	return owner_player.player_id == 0

## Players currently suppressed by this FIE (instance_id -> Player). Tracked so the
## suppress count is released exactly once per player no matter how the FIE dies.
var _suppressed: Dictionary = {}

func take_damage(amount: float, _attacker: Player = null) -> void:
	hp -= amount
	if hp <= 0:
		_destroy()

func _destroy() -> void:
	_release_all_suppression()
	destroyed.emit()
	queue_free()

func _on_zone_entered(body: Node) -> void:
	if body is Player and body != owner_player and not _suppressed.has(body.get_instance_id()):
		_suppressed[body.get_instance_id()] = body
		body.fie_suppress_count += 1

func _on_zone_exited(body: Node) -> void:
	if body is Player and _suppressed.erase(body.get_instance_id()):
		body.fie_suppress_count = max(0, body.fie_suppress_count - 1)

func _release_all_suppression() -> void:
	for p in _suppressed.values():
		if is_instance_valid(p):
			p.fie_suppress_count = max(0, p.fie_suppress_count - 1)
	_suppressed.clear()

func ult_explode():
	_release_all_suppression()
	suppress_zone.monitoring = false
	var explosion = GAREBARE_EXPLOSION.instantiate()
	explosion._set_owner(owner_player)
	add_child(explosion)
	await get_tree().create_timer(0.5).timeout
	aoe.hide()
	sprite.hide()
	$PointLight2D.hide()
	await explosion.finished
	queue_free()
