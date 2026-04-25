class_name DummyInput
extends InputProvider

# AI-controlled input for solo testing
# Provides basic "enemy" behavior so you can test combat alone

enum Behavior { WANDER, CHASE, SHOOT, RELOAD }

var behavior: Behavior = Behavior.WANDER
var target: Node2D = null
var owner_node: Node2D = null

var wander_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var shoot_timer: float = 0.0
var reload_timer: float = 0.0

# Tuning
var chase_range: float = 600.0
var shoot_range: float = 240.0

func _init(node: Node2D = null) -> void:
	owner_node = node

func set_target(t: Node2D) -> void:
	target = t

func update(delta: float) -> void:
	clear_just_pressed()
	
	if owner_node == null:
		return
	
	shoot = false
	reload = false
	sprint = false

	wander_timer -= delta
	shoot_timer -= delta
	reload_timer -= delta

	_pick_target()
	_update_behavior()
	
	match behavior:
		Behavior.WANDER:
			_do_wander()
		Behavior.CHASE:
			_do_chase()
		Behavior.SHOOT:
			_do_shoot()
		Behavior.RELOAD:
			_do_reload()

	if target != null and is_instance_valid(target):
		var aim = target.global_position - owner_node.global_position
		if aim.length() > 0.01:
			aim_input = aim.normalized()
			aim_position = target.global_position
	elif move_input.length() > 0.01:
		aim_input = move_input.normalized()
		aim_position = owner_node.global_position + aim_input * 100.0

func _pick_target() -> void:
	if _is_valid_target(target):
		return
	target = null
	var best_dist := INF
	for p in owner_node.get_tree().get_nodes_in_group("players"):
		if not (p is Player):
			continue
		var pl := p as Player
		if not _is_valid_target(pl):
			continue
		var d := owner_node.global_position.distance_to(pl.global_position)
		if d < best_dist:
			best_dist = d
			target = pl

func _is_valid_target(n: Node2D) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n == owner_node:
		return false
	if n is Player:
		var p := n as Player
		if p.is_dead() or p.in_spectate_mode or p.is_awaiting_respawn or p.is_dying:
			return false
	return true

func _update_behavior() -> void:
	if _should_reload():
		behavior = Behavior.RELOAD
		return
	if not _is_valid_target(target):
		behavior = Behavior.WANDER
		return
	var dist := owner_node.global_position.distance_to(target.global_position)
	if dist <= shoot_range:
		behavior = Behavior.SHOOT
	elif dist <= chase_range:
		behavior = Behavior.CHASE
	else:
		behavior = Behavior.WANDER

func _should_reload() -> bool:
	if owner_node == null or not (owner_node is Player):
		return false
	var p := owner_node as Player
	if p.hero == null or not p.hero.uses_gun_ammo():
		return false
	if p.hero.reload_cd > 0.0:
		return false
	return p.hero.ammo <= 0

func _do_chase() -> void:
	if not _is_valid_target(target):
		move_input = Vector2.ZERO
		return
	var to_target := target.global_position - owner_node.global_position
	move_input = to_target.normalized()

func _do_reload() -> void:
	move_input = Vector2.ZERO
	if reload_timer <= 0.0:
		reload = true
		reload_just = true
		reload_timer = 0.4

func _do_wander() -> void:
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.8, 2.0)
		wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if randf() < 0.35:
			wander_dir = Vector2.ZERO
	move_input = wander_dir * 0.5

func _do_shoot() -> void:
	if not _is_valid_target(target):
		move_input = Vector2.ZERO
		return
	var to_target := target.global_position - owner_node.global_position
	var dist := to_target.length()
	if dist > shoot_range * 0.9:
		move_input = to_target.normalized()
	elif dist < shoot_range * 0.5:
		move_input = -to_target.normalized() * 0.6
	else:
		move_input = Vector2.ZERO
	if shoot_timer <= 0.0:
		shoot = true
		shoot_just = true
		shoot_timer = randf_range(0.12, 0.26)
