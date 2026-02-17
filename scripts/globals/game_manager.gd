class_name GameManager
extends Node

# Handles player spawning and multiplayer mode
# Uses predefined spawn points from the map

enum Mode { LOCAL, ONLINE_HOST, ONLINE_CLIENT }

@export var player_scene: PackedScene
@export var mode: Mode = Mode.LOCAL

# Spawn points - set these from the map scene
@export var spawn_points: Array[Marker2D] = []

var players: Array[Player] = []

static var instance: GameManager = null

func _ready() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

# --- SPAWN POINT SELECTION ---

# Track which spawn points are taken (for initial spawns)
var used_spawns: Array[int] = []
# Seeded RNG for synchronized spawn selection across clients
var spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func init_spawn_rng(seed_string: String = "") -> void:
	# Use room code as seed so all clients get same "random" sequence
	if seed_string.is_empty() and Network.room_code:
		seed_string = Network.room_code
	spawn_rng.seed = hash(seed_string)
	used_spawns.clear()

func get_initial_spawn(_player_id: int) -> Vector2:
	# Pick a random unused spawn point (using seeded RNG for sync)
	if spawn_points.is_empty():
		return _get_fallback_position(_player_id)
	
	# Find available spawn indices
	var available: Array[int] = []
	for i in range(spawn_points.size()):
		if i not in used_spawns and spawn_points[i] != null:
			available.append(i)
	
	# If all used, reset and pick any
	if available.is_empty():
		used_spawns.clear()
		for i in range(spawn_points.size()):
			if spawn_points[i] != null:
				available.append(i)
	
	if available.is_empty():
		return _get_fallback_position(_player_id)
	
	# Pick random from available using seeded RNG
	var idx = available[spawn_rng.randi() % available.size()]
	used_spawns.append(idx)
	return spawn_points[idx].global_position

func get_fair_respawn(player: Player) -> Vector2:
	# Find the spawn point furthest from all living enemies
	if spawn_points.is_empty():
		return _get_fallback_position(player.player_id)
	
	var living_enemies: Array[Player] = []
	for p in players:
		if p != player and is_instance_valid(p) and not p.is_dead():
			living_enemies.append(p)
	
	# If no enemies, just use assigned spawn
	if living_enemies.is_empty():
		return get_initial_spawn(player.player_id)
	
	# Find spawn with maximum minimum distance to any enemy
	var best_spawn: Marker2D = null
	var best_min_dist: float = -1
	
	for spawn in spawn_points:
		if spawn == null:
			continue
		
		var min_dist = INF
		for enemy in living_enemies:
			var dist = spawn.global_position.distance_to(enemy.global_position)
			min_dist = min(min_dist, dist)
		
		if min_dist > best_min_dist:
			best_min_dist = min_dist
			best_spawn = spawn
	
	if best_spawn:
		return best_spawn.global_position
	return get_initial_spawn(player.player_id)

func _get_fallback_position(id: int) -> Vector2:
	var offset = 200
	match id % 4:
		0: return Vector2(-offset, -offset)
		1: return Vector2(offset, -offset)
		2: return Vector2(-offset, offset)
		_: return Vector2(offset, offset)

# --- LOCAL MODE ---

func start_local_game(player_count: int = 4) -> void:
	mode = Mode.LOCAL
	clear_players()
	
	for i in range(player_count):
		spawn_local_player(i)
	
	print("Started local game with ", player_count, " players")
	print("Controls: P1=WASD, P2=IJKL, P3=Arrows, P4=Numpad")

func spawn_local_player(id: int) -> Player:
	if player_scene == null:
		push_error("GameManager: player_scene not set!")
		return null
	
	var player = player_scene.instantiate() as Player
	player.player_id = id
	
	var local_input = LocalInput.new(id, id == 0)
	local_input.set_player_node(player)
	player.input = local_input
	
	player.global_position = get_initial_spawn(id)
	
	add_child(player)
	players.append(player)
	
	return player

func spawn_ai_player(id: int, target: Node2D = null) -> Player:
	if player_scene == null:
		push_error("GameManager: player_scene not set!")
		return null
	
	var player = player_scene.instantiate() as Player
	player.player_id = id
	player.is_ai_player = true
	
	var ai_input = DummyInput.new(player)
	if target:
		ai_input.set_target(target)
	player.input = ai_input
	
	player.global_position = get_initial_spawn(id)
	
	add_child(player)
	players.append(player)
	
	return player

func respawn_player(player: Player) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	player.global_position = get_fair_respawn(player)
	if player.hero:
		player.hero.health = player.hero.max_health
		player.hero.is_dead = false
		player.hero.health_changed.emit(player.hero.health, player.hero.max_health)

func clear_players() -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	used_spawns.clear()

func get_player(id: int) -> Player:
	for p in players:
		if p.player_id == id:
			return p
	return null

# --- ONLINE MODE ---
var local_player_id: int = -1
var net_inputs: Dictionary = {}
var player_data: Dictionary = {}
var game_settings: Dictionary = {}
var _signals_connected: bool = false

# State sync
const SYNC_INTERVAL: float = 0.1  # Sync 10 times per second
const POSITION_SNAP_THRESHOLD: float = 200.0  # Teleport if too far off
const POSITION_LERP_SPEED: float = 15.0  # Smooth correction speed
var sync_timer: float = 0.0
var pending_corrections: Dictionary = {}  # player_id -> {pos, rot, health, etc}

func _process(delta: float) -> void:
	if mode == Mode.LOCAL:
		return
	
	sync_timer += delta
	if sync_timer >= SYNC_INTERVAL:
		sync_timer = 0.0
		
		if mode == Mode.ONLINE_HOST:
			# Host broadcasts authoritative state to all clients
			_broadcast_state()
		else:
			# Client sends own state to host for accurate sync
			_send_local_state()
	
	# Clients apply smooth corrections for remote players
	if mode == Mode.ONLINE_CLIENT:
		_apply_corrections(delta)

func _send_local_state() -> void:
	var player = get_local_player()
	if player == null or not is_instance_valid(player):
		return
	
	var state = {
		"type": "client_state",
		"id": player.player_id,
		"x": player.global_position.x,
		"y": player.global_position.y,
		"r": player.rotation,
		"vx": player.velocity.x,
		"vy": player.velocity.y,
		"dash": player.is_dashing
	}
	
	if player.hero:
		state["hp"] = player.hero.health
		state["ult"] = player.hero.ult_points
		state["ammo"] = player.hero.ammo
	
	Network.send_to_host(state)

func _setup_network_signals() -> void:
	if _signals_connected:
		return
	Network.player_left.connect(_on_player_left)
	Network.message_received.connect(_on_message)
	_signals_connected = true

func start_online_game(players_info: Array, settings: Dictionary) -> void:
	_setup_network_signals()
	game_settings = settings
	local_player_id = Network.my_player_id
	mode = Mode.ONLINE_HOST if Network.is_host else Mode.ONLINE_CLIENT
	
	# Initialize spawn RNG with room code so all clients get same spawn sequence
	init_spawn_rng(Network.room_code)
	
	# Sort players by ID to ensure consistent spawn order across clients
	var sorted_players = players_info.duplicate()
	sorted_players.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	
	for p in sorted_players:
		var pid = int(p.get("id", -1))
		player_data[pid] = {
			"username": p.get("username", "Player"),
			"hero": p.get("hero", "")
		}
		var is_local_player = (pid == local_player_id)
		_spawn_net_player(pid, is_local_player)
	
	print("Game started with ", players_info.size(), " players")

func _on_player_left(player_id: int) -> void:
	var player = get_player(player_id)
	if player:
		players.erase(player)
		player.queue_free()
	net_inputs.erase(player_id)

func _on_message(from_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")
	
	if msg_type == "input":
		var pid = int(data.get("pid", from_id))
		if net_inputs.has(pid):
			net_inputs[pid].receive_input(data)
	
	elif msg_type == "state_sync":
		_receive_state_sync(data)
	
	elif msg_type == "client_state":
		_receive_client_state(from_id, data)

func _broadcast_state() -> void:
	if not Network.is_online():
		return
	
	var states = []
	for p in players:
		if not is_instance_valid(p):
			continue
		
		var state = {
			"id": p.player_id,
			"x": p.global_position.x,
			"y": p.global_position.y,
			"r": p.rotation,
			"vx": p.velocity.x,
			"vy": p.velocity.y,
			"dash": p.is_dashing,
			"drug": p.is_drugged
		}
		
		if p.hero:
			state["hp"] = p.hero.health
			state["ult"] = p.hero.ult_points
			state["ammo"] = p.hero.ammo
			# Sync invisibility for Dealer
			if p.hero.has_method("is_invisible"):
				state["invis"] = p.hero.is_invisible()
		
		states.append(state)
	
	Network.broadcast({
		"type": "state_sync",
		"states": states
	})

func _receive_state_sync(data: Dictionary) -> void:
	# Only clients receive state sync
	if mode != Mode.ONLINE_CLIENT:
		return
	
	var states = data.get("states", [])
	for state in states:
		var pid = int(state.get("id", -1))
		pending_corrections[pid] = state

func _receive_client_state(from_id: int, data: Dictionary) -> void:
	# Only host receives client state updates
	if mode != Mode.ONLINE_HOST:
		return
	
	var pid = int(data.get("id", from_id))
	var player = get_player(pid)
	
	if player == null or not is_instance_valid(player):
		return
	
	# Update the player's position based on client's authoritative state
	var client_pos = Vector2(data.get("x", 0), data.get("y", 0))
	var dist = player.global_position.distance_to(client_pos)
	
	# Only accept if reasonably close (prevents cheating)
	if dist < 500:  # Allow up to 500 units difference
		player.global_position = client_pos
		player.rotation = data.get("r", player.rotation)
		player.velocity = Vector2(data.get("vx", 0), data.get("vy", 0))
		player.is_dashing = data.get("dash", false)

func _apply_corrections(delta: float) -> void:
	for pid in pending_corrections:
		var state = pending_corrections[pid]
		var player = get_player(pid)
		
		if player == null or not is_instance_valid(player):
			continue
		
		# Don't correct local player's position (they are authoritative for their own movement)
		# But DO apply other state like health
		var is_local_player = (pid == local_player_id)
		
		var target_pos = Vector2(state.get("x", 0), state.get("y", 0))
		var target_rot = state.get("r", 0)
		
		if not is_local_player:
			# Correct remote player positions
			var dist = player.global_position.distance_to(target_pos)
			
			if dist > POSITION_SNAP_THRESHOLD:
				# Teleport if too far off
				player.global_position = target_pos
				player.rotation = target_rot
			else:
				# Smooth interpolation
				player.global_position = player.global_position.lerp(target_pos, POSITION_LERP_SPEED * delta)
				player.rotation = lerp_angle(player.rotation, target_rot, POSITION_LERP_SPEED * delta)
			
			# Apply velocity for prediction
			player.velocity = Vector2(state.get("vx", 0), state.get("vy", 0))
			
			# Sync dash/drug state
			player.is_dashing = state.get("dash", false)
			if state.get("drug", false) and not player.is_drugged:
				player.is_drugged = true
			elif not state.get("drug", false) and player.is_drugged:
				player._end_drug_effect()
		
		# Always sync health and resources for all players
		if player.hero:
			var hp = state.get("hp", player.hero.health)
			if abs(player.hero.health - hp) > 1:
				player.hero.health = hp
				player.hero.health_changed.emit(hp, player.hero.max_health)
			
			player.hero.ult_points = int(state.get("ult", player.hero.ult_points))
			player.hero.ammo = int(state.get("ammo", player.hero.ammo))
			
			# Sync invisibility for Dealer
			if player.hero.has_method("is_invisible"):
				var should_be_invis = state.get("invis", false)
				var is_invis = player.hero.is_invisible()
				if should_be_invis and not is_invis:
					player.hero._start_invis()
				elif not should_be_invis and is_invis:
					player.hero._end_invis()
	
	pending_corrections.clear()

func _spawn_net_player(id: int, local: bool) -> Player:
	if player_scene == null:
		return null
	
	var player = player_scene.instantiate() as Player
	player.player_id = id
	
	var net_input = NetworkInput.new(id, local)
	net_input.set_player_node(player)
	player.input = net_input
	net_inputs[id] = net_input
	
	player.global_position = get_initial_spawn(id)
	
	add_child(player)
	players.append(player)
	
	var hero_name = get_player_hero(id)
	if hero_name:
		player.set_hero(hero_name)
	
	return player

func disconnect_online() -> void:
	Network.disconnect_from_server()
	clear_players()
	net_inputs.clear()
	player_data.clear()
	game_settings.clear()
	local_player_id = -1
	mode = Mode.LOCAL

func get_player_username(player_id: int) -> String:
	if player_data.has(player_id):
		return player_data[player_id].get("username", "Player")
	return "Player"

func get_player_hero(player_id: int) -> String:
	if player_data.has(player_id):
		return player_data[player_id].get("hero", "")
	return ""

# --- UTIL ---

func is_local() -> bool:
	return mode == Mode.LOCAL

func is_host() -> bool:
	return mode == Mode.LOCAL or mode == Mode.ONLINE_HOST

func get_local_player() -> Player:
	if mode == Mode.LOCAL:
		return get_player(0)
	return get_player(local_player_id)
