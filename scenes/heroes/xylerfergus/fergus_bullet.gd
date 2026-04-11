extends Area2D

@export var damage: int = 8
@export var speed: float = 1080.0
@export var lifetime: float = 2.2

var direction: Vector2 = Vector2.RIGHT
var owner_player: Player = null
var _hit: bool = false

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _hit:
		return
	var move_amount := direction * speed * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + move_amount * 2.0,
		2
	)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result:
		queue_free()
		return
	position += move_amount
	if owner_player and owner_player.is_invulnerable and owner_player.farm:
		if global_position.distance_to(owner_player.farm.global_position) > Player.FARM_RADIUS:
			queue_free()

func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	if body == owner_player:
		return
	_hit = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_mask = 0
	collision_layer = 0
	if body is Player:
		var pl := body as Player
		var did_hit := pl.take_damage(damage, owner_player)
		if did_hit:
			var gm := GameManager.instance
			if gm and owner_player and owner_player.hero is HeroXylerFergus:
				var h := owner_player.hero as HeroXylerFergus
				if h.is_fergus_ult_active():
					gm.xf_fergus_mark_hit(owner_player.player_id, pl.player_id)
		queue_free()
	elif body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	else:
		queue_free()
