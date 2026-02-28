class_name NetworkInput
extends InputProvider

# Networked input - either sends local input to server, or receives remote input

var player_id: int = 0
var is_local: bool = false  # True if this is our local player
var player_node: Node2D = null

# For local player: the underlying local input we read from
var local_source: LocalInput = null

# For remote players: buffer of received inputs
var input_buffer: Array[Dictionary] = []

func _init(id: int = 0, local: bool = false) -> void:
	player_id = id
	is_local = local
	
	if is_local:
		# Always use player 0 controls (WASD + mouse) for local player
		local_source = LocalInput.new(0, true)

func set_player_node(node: Node2D) -> void:
	player_node = node
	if local_source:
		local_source.set_player_node(node)

func update(delta: float) -> void:
	clear_just_pressed()
	
	if is_local:
		# Read local input and send to network
		local_source.update(delta)
		_copy_from(local_source)
		_send_to_network()
		local_source.end_frame()
	else:
		# Apply buffered input from network
		_apply_buffered_input()

func _copy_from(src: InputProvider) -> void:
	move_input = src.move_input
	aim_input = src.aim_input
	aim_position = src.aim_position
	sprint = src.sprint
	dash = src.dash
	shoot = src.shoot
	reload = src.reload
	ability1 = src.ability1
	ability2 = src.ability2
	interact = src.interact
	dash_just = src.dash_just
	shoot_just = src.shoot_just
	reload_just = src.reload_just
	ability1_just = src.ability1_just
	ability2_just = src.ability2_just
	interact_just = src.interact_just
	drop = src.drop
	drop_just = src.drop_just

func _send_to_network() -> void:
	if not Network.is_online():
		return
	
	Network.broadcast({
		"type": "input",
		"pid": player_id,
		"m": [move_input.x, move_input.y],
		"a": [aim_input.x, aim_input.y],
		"sp": sprint,
		"d": dash_just,
		"sh": shoot,
		"shj": shoot_just,
		"r": reload_just,
		"a1": ability1_just,
		"a2": ability2_just,
		"dr": drop_just
	})

func receive_input(data: Dictionary) -> void:
	input_buffer.append(data)

func _apply_buffered_input() -> void:
	if input_buffer.is_empty():
		return
	
	# Use most recent input
	var data = input_buffer.pop_back()
	input_buffer.clear()
	
	var m = data.get("m", [0, 0])
	var a = data.get("a", [1, 0])
	
	move_input = Vector2(m[0], m[1])
	aim_input = Vector2(a[0], a[1])
	sprint = data.get("sp", false)
	dash_just = data.get("d", false)
	shoot = data.get("sh", false)
	shoot_just = data.get("shj", false)
	reload_just = data.get("r", false)
	ability1_just = data.get("a1", false)
	ability2_just = data.get("a2", false)
	drop_just = data.get("dr", false)
