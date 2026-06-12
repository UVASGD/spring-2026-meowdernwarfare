class_name BurpleGrenade
extends Area2D

const ExplosionScene = preload("res://scenes/explosion_visual.tscn")

@export var damage: float = 28.0
@export var speed: float = 900.0
@export var blast_radius: float = 140.0
@export var max_life: float = 5.0

var owner_player: Player = null
var landing_point: Vector2 = Vector2.ZERO
var grenade_id := ""
var authoritative := true

var _done := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(max_life).timeout.connect(_on_life_end)
	var dir := landing_point - global_position
	if dir.length_squared() > 0.01:
		rotation = dir.angle()

func _physics_process(delta: float) -> void:
	if _done:
		return
	var prev := global_position
	global_position = global_position.move_toward(landing_point, speed * delta)
	var dir := global_position - prev
	if dir.length_squared() > 0.01:
		rotation = dir.angle()
	if not authoritative:
		if global_position.distance_to(landing_point) <= 1.0:
			set_physics_process(false)
		return
	if global_position.distance_to(landing_point) <= 1.0:
		_boom(landing_point, true)

func _on_body_entered(body: Node) -> void:
	if _done or not authoritative or body == owner_player:
		return
	if body is Player:
		_boom(global_position, true)

func _on_life_end() -> void:
	if _done:
		return
	if authoritative:
		_boom(global_position, true)
	else:
		queue_free()

func force_boom(pos: Vector2) -> void:
	_boom(pos, false)

func _boom(pos: Vector2, deal_damage: bool) -> void:
	if _done:
		return
	_done = true
	global_position = pos
	if deal_damage:
		_apply_damage(pos)
		var gm := GameManager.instance
		if gm and gm.mode == GameManager.Mode.ONLINE_HOST:
			gm.report_burple_grenade_boom(grenade_id, pos)
	_spawn_fx(pos)
	queue_free()

func _apply_damage(center: Vector2) -> void:
	var r2 := blast_radius * blast_radius
	for node in get_tree().get_nodes_in_group("players"):
		if not node is Player:
			continue
		var pl := node as Player
		if pl == owner_player:
			continue
		if pl.global_position.distance_squared_to(center) > r2:
			continue
		pl.take_damage(damage, owner_player)

func _spawn_fx(pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fx: Node2D = ExplosionScene.instantiate() as Node2D
	fx.global_position = pos
	var s: float = max(blast_radius / 220.0, 0.45)
	fx.scale = Vector2.ONE * s
	get_tree().current_scene.add_child(fx)
