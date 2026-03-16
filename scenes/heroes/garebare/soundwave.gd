extends Area2D

@export var base_damage: float = 12.0
@export var speed: float = 500.0
@export var lifetime: float = 1.5
@export var grow_rate: float = 1.8
@export var max_bounces: int = 1

var direction: Vector2 = Vector2.RIGHT
var owner_player: Player = null
var age: float = 0.0
var bounces_left: int = 0
var hit_ids := {}

func _ready() -> void:
	bounces_left = max_bounces
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	age += delta
	var s = 1.0 + age * grow_rate
	scale = Vector2(s, s)

	var move_amount = direction * speed * delta
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + move_amount * 2,
		2
	)
	query.exclude = [self]
	var result = space.intersect_ray(query)
	if result:
		if bounces_left > 0:
			bounces_left -= 1
			var normal: Vector2 = result.normal
			direction = direction.bounce(normal).normalized()
			rotation = direction.angle()
			global_position = result.position + normal * 2.0
			return
		queue_free()
		return
	position += move_amount
	modulate = Color(1,1,1, 1-(age/4))
	$light.energy = 1-(age/4)

func _get_current_damage() -> float:
	var t = clamp(age / lifetime, 0.0, 1.0)
	return base_damage * (1.0 - t * 0.7)

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	if body is Player:
		var id = body.get_instance_id()
		if hit_ids.has(id):
			return
		hit_ids[id] = true
		body.take_damage(_get_current_damage(), owner_player)
	elif body.has_method("take_damage"):
		body.take_damage(_get_current_damage())
		queue_free()
