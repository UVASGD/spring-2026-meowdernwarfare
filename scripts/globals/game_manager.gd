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
var eliminated: Array[Player] = []
var entity_parent: Node = null
var sudden_death: bool = false
var game_over: bool = false
var stats: Dictionary = {}

signal player_eliminated(player: Player)
signal game_over_received(winner_id: int)
signal sudden_death_received

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
	var sp = spawn_points[idx]
	print("Player ", _player_id, " → spawn[", idx, "] pos=", sp.position, " global=", sp.global_position)
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
	
	var spawn_pos = get_initial_spawn(id)
	_add_entity(player)
	player.global_position = spawn_pos
	print("  Player ", id, " after add: global=", player.global_position, " (wanted ", spawn_pos, ")")
	players.append(player)
	player.died.connect(func(): _on_player_died(player))
	stats[id] = {"kills": 0, "deaths": 0}
	
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
	
	var spawn_pos = get_initial_spawn(id)
	_add_entity(player)
	player.global_position = spawn_pos
	print("  Player ", id, " after add: global=", player.global_position, " (wanted ", spawn_pos, ")")
	players.append(player)
	player.died.connect(func(): _on_player_died(player))
	stats[id] = {"kills": 0, "deaths": 0}
	
	return player

const RESPAWN_DELAY := 10.0

func respawn_player(player: Player) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	var pos: Vector2
	if player.farm:
		var sp = player.farm.get_node_or_null("Spawnpoint")
		pos = sp.global_position if sp else player.farm.global_position
	else:
		pos = get_fair_respawn(player)
	
	player.respawn_at(pos)

func _on_player_died(player: Player) -> void:
	_track_death(player)
	
	var should_elim = sudden_death or player.crop_count <= 0
	print("[GAME] _on_player_died: pid=", player.player_id, " crop_count=", player.crop_count, " sudden_death=", sudden_death, " should_elim=", should_elim, " mode=", mode)
	if should_elim:
		eliminated.append(player)
		print("[GAME] Player ", player.player_id, " eliminated (", "sudden death" if sudden_death else "0 crops", ")")
		player_eliminated.emit(player)
	else:
		print("[GAME] Player ", player.player_id, " will respawn in ", RESPAWN_DELAY, "s")
		get_tree().create_timer(RESPAWN_DELAY).timeout.connect(
			func(): respawn_player(player)
		)

func _track_death(player: Player) -> void:
	var pid = player.player_id
	if not stats.has(pid):
		stats[pid] = {"kills": 0, "deaths": 0}
	stats[pid]["deaths"] += 1
	
	if player.last_attacker and is_instance_valid(player.last_attacker):
		var aid = player.last_attacker.player_id
		if not stats.has(aid):
			stats[aid] = {"kills": 0, "deaths": 0}
		stats[aid]["kills"] += 1
	
	player.last_attacker = null

func get_stats(pid: int) -> Dictionary:
	return stats.get(pid, {"kills": 0, "deaths": 0})

func clear_players() -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	eliminated.clear()
	used_spawns.clear()
	stats.clear()
	sudden_death = false
	game_over = false

func get_player(id: int) -> Player:
	for p in players:
		if p.player_id == id:
			return p
	return null

func get_alive_players() -> Array[Player]:
	var alive: Array[Player] = []
	for p in players:
		if is_instance_valid(p) and not p.in_spectate_mode:
			alive.append(p)
	return alive

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

const POS_REPORT_INTERVAL: float = 2.0
var pos_report_timer: float = 0.0

func _process(delta: float) -> void:
	if mode == Mode.LOCAL:
		return
	
	sync_timer += delta
	if sync_timer >= SYNC_INTERVAL:
		sync_timer = 0.0
		
		if mode == Mode.ONLINE_HOST:
			_broadcast_state()
		else:
			_send_local_state()
	
	if mode == Mode.ONLINE_CLIENT:
		_apply_corrections(delta)
	
	pos_report_timer += delta
	if pos_report_timer >= POS_REPORT_INTERVAL:
		pos_report_timer = 0.0
		_send_pos_report()

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
	
	state["cc"] = player.crop_count
	if player.held_crop:
		state["hc"] = player.held_crop.get_type_id()
		state["hs"] = player.held_crop.stage
	
	Network.send_to_host(state)

func _setup_network_signals() -> void:
	if _signals_connected:
		return
	Network.player_left.connect(_on_player_left)
	Network.message_received.connect(_on_message)
	Network.became_host.connect(_on_became_host)
	_signals_connected = true

func _on_became_host() -> void:
	mode = Mode.ONLINE_HOST
	print("GameManager: became host via migration")

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
	
	elif msg_type == "crop_planted":
		_handle_crop_planted(from_id, data)

	elif msg_type == "crop_uproot":
		_handle_crop_uproot(from_id, data)
	
	elif msg_type == "crop_removed":
		_handle_crop_removed(data)
	
	elif msg_type == "crop_dropped":
		_handle_crop_dropped(from_id, data)
	
	elif msg_type == "crop_pickup":
		_handle_crop_pickup(from_id, data)
	
	elif msg_type == "game_over":
		_handle_game_over(data)
	
	elif msg_type == "sudden_death":
		_handle_sudden_death()
	
	elif msg_type == "tp_used":
		_handle_teleporter_used(from_id, data)
	
	elif msg_type == "crop_spawned":
		_handle_crop_spawned(data)
	
	elif msg_type == "spawner_stage":
		_handle_spawner_stage(data)

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
			if p.hero.has_method("is_invisible"):
				state["invis"] = p.hero.is_invisible()
		
		state["cc"] = p.crop_count
		state["spec"] = p.in_spectate_mode
		state["dead"] = p.is_dead()
		state["await_resp"] = p.is_awaiting_respawn
		if p.held_crop:
			state["hc"] = p.held_crop.get_type_id()
			state["hs"] = p.held_crop.stage
		elif _host_held_crops.has(p.player_id):
			state["hc"] = _host_held_crops[p.player_id].get("t", "")
			state["hs"] = _host_held_crops[p.player_id].get("s", 0)
		
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
	
	var client_pos = Vector2(data.get("x", 0), data.get("y", 0))
	player.global_position = client_pos
	player.rotation = data.get("r", player.rotation)
	player.velocity = Vector2(data.get("vx", 0), data.get("vy", 0))
	player.is_dashing = data.get("dash", false)
	
	if player.hero and data.has("hp"):
		player.hero.health = data["hp"]
	
	var hc = data.get("hc", "")
	if hc != "":
		_host_held_crops[pid] = {"t": hc, "s": int(data.get("hs", 1))}
	else:
		_host_held_crops.erase(pid)

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
		
		if player.hero:
			if not is_local_player:
				var hp = state.get("hp", player.hero.health)
				if abs(player.hero.health - hp) > 1:
					player.hero.health = hp
					player.hero.health_changed.emit(hp, player.hero.max_health)
			
			player.hero.ult_points = int(state.get("ult", player.hero.ult_points))
			player.hero.ammo = int(state.get("ammo", player.hero.ammo))
			
			if player.hero.has_method("is_invisible"):
				var should_be_invis = state.get("invis", false)
				var is_invis = player.hero.is_invisible()
				if should_be_invis and not is_invis:
					player.hero._start_invis()
				elif not should_be_invis and is_invis:
					player.hero._end_invis()
		
		player.crop_count = int(state.get("cc", player.crop_count))
		
		if not is_local_player:
			var hc = state.get("hc", "")
			if hc != "" and hc is String:
				player.set_remote_held_crop(hc, int(state.get("hs", 1)))
			else:
				player.clear_remote_held_crop()
			
			if state.get("spec", false) and not player.in_spectate_mode:
				player.enter_spectate_mode()
			elif state.get("dead", false) and player.hero and not player.hero.is_dead:
				player.hero.is_dead = true
				player.hero.died.emit()
			elif not state.get("dead", false) and not state.get("spec", false):
				if player.hero and player.hero.is_dead:
					player.respawn_at(target_pos)
				elif player.is_awaiting_respawn:
					player.respawn_at(target_pos)
		else:
			if state.get("dead", false) and player.hero and not player.hero.is_dead:
				print("[SYNC] Local player death catch-up: host says dead, forcing local death. hp=", player.hero.health)
				player.hero.take_damage(player.hero.health + 1)
	
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
	
	var spawn_pos = get_initial_spawn(id)
	_add_entity(player)
	player.global_position = spawn_pos
	print("  Player ", id, " after add: global=", player.global_position, " (wanted ", spawn_pos, ")")
	players.append(player)
	player.died.connect(func(): _on_player_died(player))
	stats[id] = {"kills": 0, "deaths": 0}
	
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

func broadcast_game_over(winner_id: int) -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	print("[NET] Host broadcasting game_over, winner_id=", winner_id)
	Network.broadcast({
		"type": "game_over",
		"winner": winner_id
	})

func _handle_game_over(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var winner_id = int(data.get("winner", -1))
	print("[NET] Received game_over from host, winner_id=", winner_id, " game_over_already=", game_over)
	game_over_received.emit(winner_id)

func broadcast_sudden_death() -> void:
	sudden_death = true
	if mode == Mode.ONLINE_HOST and Network.is_online():
		Network.broadcast({"type": "sudden_death"})

func _handle_sudden_death() -> void:
	if sudden_death:
		return
	sudden_death = true
	sudden_death_received.emit()

# --- TELEPORTER SYNC ---

func send_teleporter_used(tp_id: int, target_tp_id: int) -> void:
	var msg = {"type": "tp_used", "a": tp_id, "b": target_tp_id}
	if mode == Mode.ONLINE_HOST:
		Network.broadcast(msg)
	else:
		Network.send_to_host(msg)

func _handle_teleporter_used(from_id: int, data: Dictionary) -> void:
	if mode == Mode.ONLINE_HOST:
		Network.broadcast(data)
	var tp_a = int(data.get("a", -1))
	var tp_b = int(data.get("b", -1))
	for tp in get_tree().get_nodes_in_group("teleporters"):
		if tp.id == tp_a or tp.id == tp_b:
			if tp.active:
				tp._set_disabled(tp.cooldown)

# --- CROP SYNC ---

const CROP_SCENES := {
	"SpeedSprout": preload("res://scenes/crops/speed_sprout.tscn"),
	"IronRoot": preload("res://scenes/crops/iron_root.tscn"),
	"BlastBerry": preload("res://scenes/crops/blast_berry.tscn"),
}

var _host_held_crops: Dictionary = {}

func make_crop_icon(type_id: String, stg: int) -> Texture2D:
	var scene = CROP_SCENES.get(type_id)
	if scene == null:
		return null
	var tmp = scene.instantiate() as Crop
	tmp.stage = stg
	tmp._setup()
	var tex = tmp.icon
	if tex == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(tmp.get_stage_color())
		tex = ImageTexture.create_from_image(img)
	tmp.free()
	return tex

func _get_plantable_tiles(farm_node: Node2D) -> Array:
	var tiles: Array = []
	var tilemap = farm_node.get_node_or_null("TileMapLayer")
	if tilemap == null:
		return tiles
	for child in tilemap.get_children():
		if child.has_method("plant"):
			tiles.append(child)
	return tiles

func send_crop_planted(planter_id: int, tile_idx: int, crop_type: String, stg: int) -> void:
	var msg = {
		"type": "crop_planted",
		"pid": planter_id,
		"ti": tile_idx,
		"ct": crop_type,
		"cs": stg
	}
	if mode == Mode.ONLINE_HOST:
		_host_held_crops.erase(planter_id)
		Network.broadcast(msg)
	else:
		Network.send_to_host(msg)

func _handle_crop_planted(from_id: int, data: Dictionary) -> void:
	var planter_id = int(data.get("pid", from_id))
	if mode == Mode.ONLINE_HOST:
		_host_held_crops.erase(planter_id)
		Network.broadcast(data)
	if planter_id == local_player_id:
		return
	var planter = get_player(planter_id)
	if planter == null or not is_instance_valid(planter) or planter.farm == null:
		return
	var tile_idx = int(data.get("ti", -1))
	var tiles = _get_plantable_tiles(planter.farm)
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	var tile = tiles[tile_idx]
	if tile.planted_crop != null:
		return
	var crop_type = str(data.get("ct", ""))
	var scene = CROP_SCENES.get(crop_type)
	if scene == null:
		return
	var crop = scene.instantiate() as Crop
	crop.stage = int(data.get("cs", 1))
	crop._setup()
	planter.farm.plant_crop(crop, tile)
	planter.crop_count += 1
	planter.clear_remote_held_crop()

func send_crop_uproot(victim_id: int, tile_idx: int, crop_type: String, stg: int) -> void:
	var victim = get_player(victim_id)
	var cc = victim.crop_count if victim else 0
	if mode == Mode.ONLINE_HOST:
		_host_held_crops[local_player_id] = {"t": crop_type, "s": stg}
		Network.broadcast({
			"type": "crop_removed",
			"vid": victim_id,
			"ti": tile_idx,
			"cc": cc,
			"thief": local_player_id,
			"ct": crop_type,
			"cs": stg
		})
	else:
		Network.send_to_host({
			"type": "crop_uproot",
			"vid": victim_id,
			"ti": tile_idx,
			"ct": crop_type,
			"cs": stg
		})

func send_crop_pickup(picker_id: int, pos: Vector2, crop_type: String, stg: int) -> void:
	var msg = {
		"type": "crop_pickup",
		"pid": picker_id,
		"x": pos.x,
		"y": pos.y,
		"ct": crop_type,
		"cs": stg
	}
	if mode == Mode.ONLINE_HOST:
		_host_held_crops[picker_id] = {"t": crop_type, "s": stg}
		Network.broadcast(msg)
	else:
		Network.send_to_host(msg)

func send_crop_dropped(dropper_id: int, pos: Vector2, crop_type: String, stg: int) -> void:
	var msg = {
		"type": "crop_dropped",
		"pid": dropper_id,
		"x": pos.x,
		"y": pos.y,
		"ct": crop_type,
		"cs": stg
	}
	if mode == Mode.ONLINE_HOST:
		_host_held_crops.erase(dropper_id)
		Network.broadcast(msg)
	else:
		Network.send_to_host(msg)

func _handle_crop_uproot(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var victim_id = int(data.get("vid", -1))
	var tile_idx = int(data.get("ti", -1))
	var victim = get_player(victim_id)
	if victim == null or not is_instance_valid(victim) or victim.farm == null:
		return
	var tiles = _get_plantable_tiles(victim.farm)
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	var tile = tiles[tile_idx]
	if tile.planted_crop == null:
		return
	var crop = victim.farm.remove_crop(tile.planted_crop)
	if crop:
		victim.crop_count -= 1
		var ct = data.get("ct", "")
		var cs = data.get("cs", 1)
		crop.queue_free()
		_host_held_crops[from_id] = {"t": ct, "s": int(cs)}
		Network.broadcast({
			"type": "crop_removed",
			"vid": victim_id,
			"ti": tile_idx,
			"cc": victim.crop_count,
			"thief": from_id,
			"ct": ct,
			"cs": cs
		})

func _handle_crop_removed(data: Dictionary) -> void:
	var victim_id = int(data.get("vid", -1))
	var tile_idx = int(data.get("ti", -1))
	var new_count = int(data.get("cc", 0))
	var victim = get_player(victim_id)
	if victim == null or not is_instance_valid(victim) or victim.farm == null:
		return
	var tiles = _get_plantable_tiles(victim.farm)
	if tile_idx < 0 or tile_idx >= tiles.size():
		victim.crop_count = new_count
		return
	var tile = tiles[tile_idx]
	if tile.planted_crop != null:
		var crop = victim.farm.remove_crop(tile.planted_crop)
		if crop:
			crop.queue_free()
	victim.crop_count = new_count
	
	var thief_id = int(data.get("thief", -1))
	if thief_id >= 0 and thief_id != local_player_id:
		var thief = get_player(thief_id)
		if thief and is_instance_valid(thief):
			var ct = str(data.get("ct", ""))
			var cs = int(data.get("cs", 1))
			if ct != "":
				thief.set_remote_held_crop(ct, cs)

func _handle_crop_pickup(from_id: int, data: Dictionary) -> void:
	var picker_id = int(data.get("pid", from_id))
	if mode == Mode.ONLINE_HOST:
		_host_held_crops[picker_id] = {"t": data.get("ct", ""), "s": int(data.get("cs", 1))}
		Network.broadcast(data)
	if picker_id == local_player_id:
		return
	var pos = Vector2(data.get("x", 0), data.get("y", 0))
	var found := false
	for sid in _spawners:
		var spawner = _spawners[sid]
		if spawner and is_instance_valid(spawner) and spawner.current_crop and is_instance_valid(spawner.current_crop):
			if spawner.current_crop.global_position.distance_to(pos) < 80.0:
				spawner.current_crop.queue_free()
				spawner.current_crop = null
				found = true
				break
	if not found:
		var parent = entity_parent if entity_parent else self
		for child in parent.get_children():
			if child is Crop and not child.is_planted and child.global_position.distance_to(pos) < 80.0:
				child.queue_free()
				break
	var picker = get_player(picker_id)
	if picker and is_instance_valid(picker):
		var ct = str(data.get("ct", ""))
		var cs = int(data.get("cs", 1))
		if ct != "":
			picker.set_remote_held_crop(ct, cs)

func _handle_crop_dropped(from_id: int, data: Dictionary) -> void:
	var dropper_id = int(data.get("pid", from_id))
	if mode == Mode.ONLINE_HOST:
		_host_held_crops.erase(dropper_id)
		Network.broadcast(data)
	if dropper_id != local_player_id:
		var dropper = get_player(dropper_id)
		if dropper and is_instance_valid(dropper):
			dropper.clear_remote_held_crop()
	if dropper_id == local_player_id:
		return
	var pos = Vector2(data.get("x", 0), data.get("y", 0))
	var type_id = str(data.get("ct", ""))
	var stg = int(data.get("cs", 1))
	var scene = CROP_SCENES.get(type_id)
	if scene == null:
		return
	var crop = scene.instantiate() as Crop
	crop.stage = stg
	crop._setup()
	crop.global_position = pos
	var parent = entity_parent if entity_parent else self
	parent.add_child(crop)

# --- CROP SPAWNER SYNC ---

var _spawners: Dictionary = {}  # spawner_id -> CropSpawner node

func register_spawner(spawner: Node) -> void:
	var id = _spawners.size()
	spawner.spawner_id = id
	_spawners[id] = spawner

func send_crop_spawned(sid: int, crop_idx: int, stg: int) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	Network.broadcast({"type": "crop_spawned", "sid": sid, "ci": crop_idx, "cs": stg})

func send_spawner_stage(sid: int, stg: int) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	Network.broadcast({"type": "spawner_stage", "sid": sid, "cs": stg})

func _handle_crop_spawned(data: Dictionary) -> void:
	var sid = int(data.get("sid", -1))
	var spawner = _spawners.get(sid)
	if spawner and is_instance_valid(spawner):
		spawner.spawn_crop_remote(int(data.get("ci", 0)), int(data.get("cs", 1)))

func _handle_spawner_stage(data: Dictionary) -> void:
	var sid = int(data.get("sid", -1))
	var spawner = _spawners.get(sid)
	if spawner and is_instance_valid(spawner):
		spawner.stage = int(data.get("cs", 1))

# --- DESYNC TELEMETRY ---

func _send_pos_report() -> void:
	if not Network.is_online() or game_over:
		return
	var report = {}
	for p in players:
		if not is_instance_valid(p):
			continue
		report[str(p.player_id)] = {
			"x": snapped(p.global_position.x, 0.1),
			"y": snapped(p.global_position.y, 0.1),
			"hp": snapped(p.hero.health, 0.1) if p.hero else 0,
			"mhp": snapped(p.hero.max_health, 0.1) if p.hero else 0,
			"dead": p.is_dead(),
			"spec": p.in_spectate_mode,
		}
	Network._send({
		"type": "pos_report",
		"from": local_player_id,
		"t": snapped(Time.get_ticks_msec() / 1000.0, 0.01),
		"p": report
	})

# --- UTIL ---

func _add_entity(node: Node) -> void:
	var parent = entity_parent if entity_parent else self
	parent.add_child(node)

func is_local() -> bool:
	return mode == Mode.LOCAL

func is_host() -> bool:
	return mode == Mode.LOCAL or mode == Mode.ONLINE_HOST

func get_local_player() -> Player:
	if mode == Mode.LOCAL:
		return get_player(0)
	return get_player(local_player_id)
