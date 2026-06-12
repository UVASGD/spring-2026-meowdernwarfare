extends Area2D

const SfxEvent = preload("res://scripts/audio/sfx_event.gd")
const SfxBus = preload("res://scripts/audio/sfx_bus.gd")

@export var damage: int = 10
@export var speed: float = 350.0
@export var lifetime: float = 3.0
@export var blind_duration: float = 3.0
@export var blast_radius: float = 120.0

var direction: Vector2 = Vector2.RIGHT
var owner_player: Player = null
var _exploded: bool = false

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(_explode)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
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
		_explode()
		return

	position += move_amount

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	if not is_inside_tree():
		return
	SfxBus.play_world(SfxEvent.FX_EXPLOSION, global_position)

	var all_players = get_tree().get_nodes_in_group("players")
	for p in all_players:
		if p is Player and p != owner_player:
			if p.global_position.distance_to(global_position) <= blast_radius:
				p.take_damage(damage, owner_player)
				p.apply_blind_effect(blind_duration)

	queue_free()
