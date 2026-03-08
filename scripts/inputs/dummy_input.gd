class_name DummyInput
extends InputProvider

# AI-controlled input for solo testing
# Provides basic "enemy" behavior so you can test combat alone

enum Behavior { IDLE, CHASE, FLEE, WANDER, AGGRESSIVE }

var behavior: Behavior = Behavior.AGGRESSIVE
var target: Node2D = null
var owner_node: Node2D = null

var wander_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var action_timer: float = 0.0
var dash_cd: float = 0.0

# Tuning
var chase_range: float = 400.0
var attack_range: float = 150.0
var flee_health_pct: float = 0.2
var reaction_time: float = 0.15

func _init(node: Node2D = null) -> void:
	owner_node = node

func set_target(t: Node2D) -> void:
	target = t

func update(delta: float) -> void:
	clear_just_pressed()
	
	if owner_node == null:
		return
	
	# Update timers
	wander_timer -= delta
	action_timer -= delta
	dash_cd -= delta
	
	# Decide behavior based on situation
	_update_behavior()
	
	# Execute behavior
	match behavior:
		Behavior.IDLE:
			_do_idle(delta)
		Behavior.CHASE:
			_do_chase(delta)
		Behavior.FLEE:
			_do_flee(delta)
		Behavior.WANDER:
			_do_wander(delta)
		Behavior.AGGRESSIVE:
			_do_aggressive(delta)

func _update_behavior() -> void:
	if target == null or not is_instance_valid(target):
		behavior = Behavior.WANDER
		return
	
	var dist = owner_node.global_position.distance_to(target.global_position)
	
	# Check if we should flee (if owner has health system)
	if owner_node.has_method("get_health_percent"):
		if owner_node.get_health_percent() < flee_health_pct:
			behavior = Behavior.FLEE
			return
	
	# Combat range decisions
	if dist < attack_range:
		behavior = Behavior.AGGRESSIVE
	elif dist < chase_range:
		behavior = Behavior.CHASE
	else:
		behavior = Behavior.WANDER

func _do_idle(delta: float) -> void:
	move_input = Vector2.ZERO
	aim_input = wander_dir if wander_dir.length() > 0 else Vector2.RIGHT

func _do_chase(delta: float) -> void:
	if target == null:
		return
	
	var to_target = target.global_position - owner_node.global_position
	move_input = to_target.normalized()
	aim_input = move_input
	
	# Sprint to catch up
	sprint = to_target.length() > 200

func _do_flee(delta: float) -> void:
	if target == null:
		return
	
	var away = owner_node.global_position - target.global_position
	move_input = away.normalized()
	aim_input = -move_input  # Aim at pursuer while fleeing
	sprint = true
	
	# Dash away if available
	if dash_cd <= 0 and randf() < 0.3:
		dash_just = true
		dash_cd = 2.0

func _do_wander(delta: float) -> void:
	if wander_timer <= 0:
		wander_timer = randf_range(1.0, 3.0)
		wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		if randf() < 0.3:
			wander_dir = Vector2.ZERO  # Sometimes stand still
	
	move_input = wander_dir * 0.5  # Walk slowly
	aim_input = wander_dir if wander_dir.length() > 0 else aim_input

func _do_aggressive(delta: float) -> void:
	if target == null:
		return
	
	var to_target = target.global_position - owner_node.global_position
	var dist = to_target.length()
	
	# Aim at target
	aim_input = to_target.normalized()
	
	# Strafe around target
	var strafe = to_target.normalized().rotated(PI/2)
	if wander_timer <= 0:
		wander_timer = randf_range(0.5, 1.5)
		wander_dir = strafe * (1 if randf() > 0.5 else -1)
	
	# Move: strafe + maintain distance
	var desired_dist = attack_range * 0.7
	var approach = to_target.normalized() * (1 if dist > desired_dist else -0.5)
	move_input = (wander_dir * 0.6 + approach * 0.4).normalized()
	
	# Shoot with some reaction time
	if action_timer <= 0 and dist < attack_range:
		shoot = true
		shoot_just = true
		action_timer = randf_range(0.1, 0.4)  # Fire rate variance
	
	# Occasionally dash
	if dash_cd <= 0 and randf() < 0.02:
		dash_just = true
		dash_cd = 1.5
	
	# Use abilities sometimes
	if randf() < 0.005:
		ability1_just = true
	if randf() < 0.003:
		ability2_just = true
	if randf() < 0.002:
		ult_just = true
