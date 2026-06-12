extends Area2D

@export var damage: float = 5.0
@export var speed: float = 360.0
@export var life: float = 1.3

var dir: Vector2 = Vector2.RIGHT
var owner_player: Player = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(life).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	var step := dir * speed * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step * 1.6, 2)
	q.exclude = [self]
	if space.intersect_ray(q):
		queue_free()
		return
	global_position += step

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	if body is Player:
		(body as Player).take_damage(damage, owner_player)
		queue_free()
	elif body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
