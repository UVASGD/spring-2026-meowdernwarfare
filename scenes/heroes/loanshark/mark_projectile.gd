extends Area2D

const MarkExplosionFxScene = preload("res://scenes/heroes/loanshark/mark_explosion_fx.tscn")

@export var damage: float = 8.0
@export var speed: float = 2200.0
@export var lifetime: float = 5.0
@export var mark_duration: float = 10.0
@export var explosion_radius: float = 140.0

var direction: Vector2 = Vector2.RIGHT
var owner_player: Player = null

var _exploded: bool = false

@onready var _proj_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)
	body_entered.connect(_on_body_entered)
	if DisplayServer.get_name() != "headless":
		_run_projectile_ghost_loop()

func _on_lifetime_expired() -> void:
	if _exploded or not is_instance_valid(self):
		return
	queue_free()

func _run_projectile_ghost_loop() -> void:
	var t := lifetime
	while t > 0 and is_instance_valid(self) and not _exploded:
		_spawn_projectile_trail_ghost()
		await get_tree().create_timer(0.05).timeout
		t -= 0.05

func _spawn_projectile_trail_ghost() -> void:
	if _proj_sprite == null or _proj_sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _proj_sprite.texture
	ghost.global_position = _proj_sprite.global_position
	ghost.global_rotation = _proj_sprite.global_rotation
	ghost.scale = _proj_sprite.scale
	ghost.flip_h = _proj_sprite.flip_h
	ghost.flip_v = _proj_sprite.flip_v
	var m := _proj_sprite.modulate
	ghost.modulate = Color(m.r, m.g, m.b, m.a * 0.5)
	ghost.z_index = -1
	get_tree().current_scene.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.finished.connect(ghost.queue_free)

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var move_amount := direction * speed * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + move_amount * 1.1,
		2
	)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result:
		_explode()
		return
	position += move_amount

func _on_body_entered(body: Node) -> void:
	if _exploded or body == owner_player:
		return
	if body is Player:
		_explode()
	elif body is StaticBody2D or body is AnimatableBody2D:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	set_physics_process(false)
	var pos := global_position
	if _proj_sprite:
		_proj_sprite.visible = false
	_spawn_explosion_visual(pos)
	_apply_explosion_aoe(pos)
	queue_free()

func _spawn_explosion_visual(pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fx: Node2D = MarkExplosionFxScene.instantiate()
	fx.ring_radius = explosion_radius
	fx.global_position = pos
	get_tree().current_scene.add_child(fx)

func _apply_explosion_aoe(center: Vector2) -> void:
	var r2 := explosion_radius * explosion_radius
	for node in get_tree().get_nodes_in_group("players"):
		if not node is Player:
			continue
		var pl := node as Player
		if pl == owner_player:
			continue
		if pl.global_position.distance_squared_to(center) > r2:
			continue
		if damage > 0.0:
			pl.take_damage(damage, owner_player)
		pl.apply_mark_effect(mark_duration)
		pl.spawn_mark_projectile_hit_fx()
