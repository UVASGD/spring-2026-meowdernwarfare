extends Area2D

@export var damage: int = 15
@export var speed: float = 600.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var owner_player: Player = null

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var move_amount = direction * speed * delta
	
	# Raycast ahead to check for walls
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + move_amount * 2,  # Check a bit ahead
		2  # Collision mask for walls (layer 2)
	)
	query.exclude = [self]
	
	var result = space.intersect_ray(query)
	if result:
		# Hit a wall
		queue_free()
		return
	
	position += move_amount

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	
	if body is Player:
		body.take_damage(damage, owner_player)
		queue_free()
	elif body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
