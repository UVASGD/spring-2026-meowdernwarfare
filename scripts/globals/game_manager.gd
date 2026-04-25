class_name GameManager
extends Node

# Handles player spawning and multiplayer mode

enum Mode { LOCAL, ONLINE_HOST, ONLINE_CLIENT }

@export var player_scene: PackedScene
@export var mode: Mode = Mode.LOCAL

var players: Array[Player] = []
var _players_by_id: Dictionary = {}
var eliminated: Array[Player] = []
var entity_parent: Node = null
var sudden_death: bool = false
var game_over: bool = false
var stats: Dictionary = {}

signal player_eliminated(player: Player)
signal game_over_received(winner_id: int)
signal sudden_death_received
signal farm_spawns_received(assignments: Array)
signal ult_used_received(player_id: int)

const AI_HERO := "BurpleBot"

const BurpleGrenadeScene = preload("res://scenes/heroes/burple/grenade.tscn")
const BurpleStrikeScene = preload("res://scenes/heroes/burple/missile_strike.tscn")
const MuskratUltScene = preload("res://scenes/heroes/elonmusk/cybertruck_ult.tscn")
const AnderOrbitalScene = preload("res://scenes/heroes/anderdingus/orbitalstrike.tscn")
const ChompEffectScene = preload("res://scenes/heroes/loanshark/chomp_effect.tscn")

static var instance: GameManager = null

func _ready() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

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
	

func spawn_local_player(id: int) -> Player:
	if player_scene == null:
		push_error("GameManager: player_scene not set!")
		return null
	
	var player = player_scene.instantiate() as Player
	player.player_id = id
	
	var local_input = LocalInput.new(id, id == 0)
	local_input.set_player_node(player)
	player.input = local_input
	
	var spawn_pos = _get_fallback_position(id)
	_add_entity(player)
	player.global_position = spawn_pos
	_register_player(player)
	player.died.connect(func(): _on_player_died(player))
	stats[id] = {"kills": 0, "deaths": 0}
	
	return player

func _register_player(p: Player) -> void:
	players.append(p)
	_players_by_id[p.player_id] = p

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
	player.set_hero(AI_HERO)
	
	var spawn_pos = _get_fallback_position(id)
	_add_entity(player)
	player.global_position = spawn_pos
	_register_player(player)
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
		if sp == null:
			sp = player.farm.get_node_or_null("spawnpoint")
		pos = sp.global_position if sp else player.farm.global_position
	else:
		pos = _get_fallback_position(player.player_id)
	
	player.respawn_at(pos)

func _on_player_died(player: Player) -> void:
	if not is_host():
		return
	_track_death(player)
	
	var should_elim = sudden_death or player.crop_count <= 0
	if should_elim:
		eliminated.append(player)
		player_eliminated.emit(player)
	else:
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
	_broadcast_stats()

func _broadcast_stats() -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	var compact := {}
	for pid in stats:
		var s = stats[pid]
		compact[str(pid)] = {"k": int(s.get("kills", 0)), "d": int(s.get("deaths", 0))}
	Network.broadcast({"type": "stats_sync", "s": compact})

func _handle_stats_sync(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var compact: Dictionary = data.get("s", {})
	for key in compact:
		var pid := int(str(key))
		var s = compact[key]
		stats[pid] = {"kills": int(s.get("k", 0)), "deaths": int(s.get("d", 0))}

func get_stats(pid: int) -> Dictionary:
	return stats.get(pid, {"kills": 0, "deaths": 0})

func clear_players() -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	for grenade in _burple_grenades.values():
		if is_instance_valid(grenade):
			grenade.queue_free()
	for strike in _burple_strikes.values():
		if is_instance_valid(strike):
			strike.queue_free()
	for ult in _muskrat_ults.values():
		if is_instance_valid(ult):
			ult.queue_free()
	for strike in _ander_orbitals.values():
		if is_instance_valid(strike):
			strike.queue_free()
	players.clear()
	_players_by_id.clear()
	eliminated.clear()
	stats.clear()
	_remote_targets.clear()
	pending_corrections.clear()
	net_inputs.clear()
	_host_held_crops.clear()
	_burple_grenades.clear()
	_burple_strikes.clear()
	_muskrat_ults.clear()
	_ander_orbitals.clear()
	_xf_mark_counts.clear()
	_spawners.clear()
	_world_crops.clear()
	sync_timer = 0.0
	pos_report_timer = 0.0
	sudden_death = false
	game_over = false

## Farms rarely change so we cache them per-frame to avoid repeated O(N) group scans
## in hot paths like Player._update_tooltip. Callers must treat the returned array as read-only.
var _cached_farms: Array = []
var _cached_farms_frame: int = -1

func get_farms() -> Array:
	var f := Engine.get_process_frames()
	if _cached_farms_frame != f:
		_cached_farms_frame = f
		_cached_farms = get_tree().get_nodes_in_group("farms")
	return _cached_farms

func get_player(id: int) -> Player:
	var p: Player = _players_by_id.get(id)
	if p != null and is_instance_valid(p):
		return p
	if _players_by_id.has(id):
		_players_by_id.erase(id)
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
const SYNC_INTERVAL: float = 0.05  # Sync 20 times per second (bumped from 10 Hz for tighter positional convergence).
const POSITION_SNAP_THRESHOLD: float = 200.0  # Teleport remote players if too far off.
const POSITION_LERP_SPEED: float = 22.0  # Smooth remote correction speed.
# Local-player rubber-band against host state (clients only).
const LOCAL_POS_IGNORE: float = 4.0      # ignore tiny drift to avoid jitter fighting local input
const LOCAL_POS_LERP_FRAC: float = 0.5   # fraction of drift erased per state_sync tick
const LOCAL_POS_SNAP: float = 160.0      # hard snap above this error (cheat/lag catch-up)
var sync_timer: float = 0.0
var pending_corrections: Dictionary = {}  # player_id -> {pos, rot, health, etc}
var _remote_targets: Dictionary = {}  # pid -> { pos, rot, vel } for smooth interpolation
var _burple_grenades: Dictionary = {}
var _burple_strikes: Dictionary = {}
var _muskrat_ults: Dictionary = {}
var _ander_orbitals: Dictionary = {}

const XF_MARKS_FOR_SLASH_DEFAULT: int = 10
const XF_SLASH_DAMAGE: float = 26.0
var _xf_mark_counts: Dictionary = {}

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
		_interpolate_remotes(delta)
	
	pos_report_timer += delta
	if pos_report_timer >= POS_REPORT_INTERVAL:
		pos_report_timer = 0.0
		_send_pos_report()

func _send_local_state() -> void:
	var player = get_local_player()
	if player == null or not is_instance_valid(player):
		return
	# Don't stream state while dead/respawning/spectating; otherwise we tell the host we're still
	# holding a crop we dropped on death. Mirrors NetworkInput._player_uncontrollable().
	if player.is_dead() or player.is_awaiting_respawn or player.in_spectate_mode:
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

func start_online_game(players_info: Array, settings: Dictionary) -> void:
	_setup_network_signals()
	game_settings = settings
	local_player_id = Network.my_player_id
	mode = Mode.ONLINE_HOST if Network.is_host else Mode.ONLINE_CLIENT
	
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
	

func _on_player_left(player_id: int) -> void:
	var player = get_player(player_id)
	if player:
		players.erase(player)
		_players_by_id.erase(player_id)
		player.queue_free()
	for uid in _muskrat_ults.keys():
		var ult = _muskrat_ults.get(uid)
		if ult and is_instance_valid(ult) and ult.owner_player and ult.owner_player.player_id == player_id:
			ult.queue_free()
	for oid in _ander_orbitals.keys():
		var strike = _ander_orbitals.get(oid)
		if strike and is_instance_valid(strike) and strike.owner_player and strike.owner_player.player_id == player_id:
			strike.queue_free()
	net_inputs.erase(player_id)
	_remote_targets.erase(player_id)

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

	elif msg_type == "crop_pickup_reject":
		_handle_crop_pickup_reject(data)
	
	elif msg_type == "game_over":
		_handle_game_over(data)
	
	elif msg_type == "stats_sync":
		_handle_stats_sync(data)
	
	elif msg_type == "sudden_death":
		_handle_sudden_death()
	
	elif msg_type == "tp_used":
		_handle_teleporter_used(from_id, data)
	
	elif msg_type == "crop_spawned":
		_handle_crop_spawned(data)
	
	elif msg_type == "crop_bring":
		_handle_crop_bring(data)
	
	elif msg_type == "spawner_stage":
		_handle_spawner_stage(data)

	elif msg_type == "fie_placed":
		_handle_fie_placed(from_id, data)

	elif msg_type == "fie_destroyed":
		_handle_fie_destroyed(from_id, data)

	elif msg_type == "farm_spawns":
		_handle_farm_spawns(data)

	elif msg_type == "ult_used":
		_handle_ult_used(data)

	elif msg_type == "burple_grenade_req":
		_handle_burple_grenade_req(from_id, data)

	elif msg_type == "burple_grenade_spawn":
		_handle_burple_grenade_spawn(data)

	elif msg_type == "burple_grenade_boom":
		_handle_burple_grenade_boom(data)

	elif msg_type == "burple_strike_req":
		_handle_burple_strike_req(from_id, data)

	elif msg_type == "burple_strike_spawn":
		_handle_burple_strike_spawn(data)

	elif msg_type == "burple_strike_pulse":
		_handle_burple_strike_pulse(data)

	elif msg_type == "burple_strike_end":
		_handle_burple_strike_end(data)

	elif msg_type == "xf_stance_req":
		_handle_xf_stance_req(from_id, data)

	elif msg_type == "xf_stance":
		_handle_xf_stance(data)

	elif msg_type == "xf_mark_hit":
		_handle_xf_mark_hit(from_id, data)

	elif msg_type == "xf_slash":
		_handle_xf_slash(data)

	elif msg_type == "muskrat_ult_req":
		_handle_muskrat_ult_req(from_id, data)

	elif msg_type == "muskrat_ult_spawn":
		_handle_muskrat_ult_spawn(data)

	elif msg_type == "muskrat_ult_tp_req":
		_handle_muskrat_ult_tp_req(from_id, data)

	elif msg_type == "muskrat_ult_tp":
		_handle_muskrat_ult_tp(data)

	elif msg_type == "muskrat_ult_end":
		_handle_muskrat_ult_end(data)

	elif msg_type == "muskrat_hold_steal_req":
		_handle_muskrat_hold_steal_req(from_id, data)

	elif msg_type == "muskrat_hold_steal":
		_handle_muskrat_hold_steal(data)

	elif msg_type == "dingus_orbital_req":
		_handle_dingus_orbital_req(from_id, data)

	elif msg_type == "dingus_orbital_spawn":
		_handle_dingus_orbital_spawn(data)

	elif msg_type == "dingus_ult_req":
		_handle_dingus_ult_req(from_id, data)

	elif msg_type == "loan_dash_hit":
		_handle_loan_dash_hit(data)

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
			if p.hero.ult_mode == Hero.UltMode.COOLDOWN:
				state["ucd"] = p.hero.ult_cd
			else:
				state["ult"] = p.hero.ult_points
			state["ammo"] = p.hero.ammo
			if p.hero.has_method("is_invisible"):
				state["invis"] = p.hero.is_invisible()
		
		state["cc"] = p.crop_count
		state["stun"] = p.is_stunned
		state["spec"] = p.in_spectate_mode
		state["dead"] = p.is_dead()
		state["await_resp"] = p.is_awaiting_respawn
		# Per-peer status-effect bits (Loan Shark mark, Gooblin boogie-bomb blind) converge on
		# the next state_sync even if the originating *_just edge was dropped. See sync_bugs #3.
		state["mk"] = p.is_marked
		state["bl"] = p.is_blinded
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
	if mode != Mode.ONLINE_CLIENT:
		return
	
	var states = data.get("states", [])
	for state in states:
		var pid = int(state.get("id", -1))
		pending_corrections[pid] = state
		if pid != local_player_id:
			_remote_targets[pid] = {
				"pos": Vector2(state.get("x", 0), state.get("y", 0)),
				"rot": float(state.get("r", 0)),
				"vel": Vector2(state.get("vx", 0), state.get("vy", 0)),
			}

func _receive_client_state(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	
	var pid = int(data.get("id", from_id))
	var player = get_player(pid)
	
	if player == null or not is_instance_valid(player):
		return
	
	# Host simulates remote players from streamed inputs; we don't trust reported position/velocity.
	# Only held-crop info piggy-backs on client_state (crop_count is already host-authoritative).
	var hc = data.get("hc", "")
	if hc != "":
		_host_held_crops[pid] = {"t": hc, "s": int(data.get("hs", 1))}
	else:
		_host_held_crops.erase(pid)

func _apply_state_sync_hp(player: Player, state: Dictionary) -> void:
	if player.hero == null:
		return
	var hp: float = float(state.get("hp", player.hero.health))
	# If we're dead locally but host sent a respawned HP, let the death/respawn branch in
	# _apply_corrections handle the transition instead of stomping hp -> alive with is_dead still set.
	if player.hero.is_dead and hp > 0.0:
		return
	var hp_diff := hp - player.hero.health
	if abs(hp_diff) <= 1.0:
		return
	if hp_diff > 0.0 and hp_diff < player.hero.max_health * 0.25:
		player.hero.health = lerpf(player.hero.health, hp, 0.4)
	else:
		player.hero.health = hp
	player.hero.health_changed.emit(player.hero.health, player.hero.max_health)

func _apply_corrections(delta: float) -> void:
	for pid in pending_corrections:
		var state = pending_corrections[pid]
		var player = get_player(pid)
		
		if player == null or not is_instance_valid(player):
			continue
		
		# Don't correct local player's position (they are authoritative for their own movement)
		# Apply host HP/ult/ammo to everyone (including local) so host-only damage matches all clients.
		var is_local_player = (pid == local_player_id)
		var target_pos = Vector2(state.get("x", 0), state.get("y", 0))
		
		if not is_local_player:
			player.is_dashing = state.get("dash", false)
			if state.get("drug", false) and not player.is_drugged:
				player.is_drugged = true
			elif not state.get("drug", false) and player.is_drugged:
				player._end_drug_effect()
			if state.get("stun", false) and not player.is_stunned:
				player.apply_stun(1.0)
			elif not state.get("stun", false) and player.is_stunned:
				player.is_stunned = false
				player.stun_timer = 0.0

		# Mark / blind apply symmetrically to local + remote so a dropped *_just edge converges on
		# the next sync tick (hosts override clients either way).
		var hs_mk := bool(state.get("mk", false))
		if hs_mk and not player.is_marked:
			player.apply_mark_effect(1.0)
		elif not hs_mk and player.is_marked:
			player.clear_mark_effect()
		var hs_bl := bool(state.get("bl", false))
		if hs_bl and not player.is_blinded:
			player.apply_blind_effect(1.0)
		elif not hs_bl and player.is_blinded:
			player._end_blind_effect()
		
		if player.hero:
			_apply_state_sync_hp(player, state)
			
			if player.hero.ult_mode == Hero.UltMode.COOLDOWN:
				if state.has("ucd"):
					player.hero.ult_cd = float(state["ucd"])
			else:
				if state.has("ult"):
					var new_ult := int(state["ult"])
					if new_ult != player.hero.ult_points:
						player.hero.ult_points = new_ult
						player.hero.ult_changed.emit(player.hero.ult_points, player.hero.max_ult_points)
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
			# Local player on a client: host owns death + respawn now that _on_player_died is
			# host-only, so we have to react to the state_sync here.
			var host_dead: bool = state.get("dead", false)
			var host_spec: bool = state.get("spec", false)
			var host_await: bool = state.get("await_resp", false)
			if host_dead and player.hero and not player.hero.is_dead:
				player.hero.take_damage(player.hero.health + 1)
			elif not host_dead and not host_spec and not host_await:
				if player.is_awaiting_respawn or (player.hero and player.hero.is_dead):
					player.respawn_at(target_pos)
				else:
					# Strict positional accuracy: rubber-band the local player to host state so
					# FP drift, collision differences, or dropped input edges don't cascade into
					# crop pickup / hurtbox / killzone desyncs. Pickup arbitration downstream
					# depends on positions matching within the host's tolerance.
					_reconcile_local_position(player, target_pos, state)
	
	pending_corrections.clear()

func _reconcile_local_position(player: Player, host_pos: Vector2, state: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Skip transient states where host and client intentionally disagree; they reset on next tick.
	if player.is_dashing or player.is_dying or player.in_spectate_mode or player.is_awaiting_respawn:
		return
	if player.hero and player.hero.is_dead:
		return
	var diff := host_pos - player.global_position
	var d := diff.length()
	if d <= LOCAL_POS_IGNORE:
		return
	if d >= LOCAL_POS_SNAP:
		player.global_position = host_pos
		player.velocity = Vector2(state.get("vx", player.velocity.x), state.get("vy", player.velocity.y))
		return
	player.global_position = player.global_position.lerp(host_pos, LOCAL_POS_LERP_FRAC)

func _interpolate_remotes(delta: float) -> void:
	for pid in _remote_targets:
		var player = get_player(pid)
		if player == null or not is_instance_valid(player):
			continue
		if player.in_spectate_mode or player.is_awaiting_respawn or player.is_dying:
			continue
		
		var t = _remote_targets[pid]
		player.velocity = t["vel"]
		t["pos"] += t["vel"] * delta
		
		var dist = player.global_position.distance_to(t["pos"])
		if dist > POSITION_SNAP_THRESHOLD:
			player.global_position = t["pos"]
		else:
			player.global_position = player.global_position.lerp(t["pos"], POSITION_LERP_SPEED * delta)

func _spawn_net_player(id: int, local: bool) -> Player:
	if player_scene == null:
		return null
	
	var player = player_scene.instantiate() as Player
	player.player_id = id
	
	var net_input = NetworkInput.new(id, local)
	net_input.set_player_node(player)
	player.input = net_input
	net_inputs[id] = net_input
	
	var spawn_pos = _get_fallback_position(id)
	_add_entity(player)
	player.global_position = spawn_pos
	_register_player(player)
	player.died.connect(func(): _on_player_died(player))
	stats[id] = {"kills": 0, "deaths": 0}
	
	var hero_name = get_player_hero(id)
	hero_name = GameData.resolve_hero_for_username(get_player_username(id), hero_name)
	if hero_name:
		player.set_hero(hero_name)
	
	return player

func disconnect_online() -> void:
	Network.disconnect_from_server()
	clear_players()
	net_inputs.clear()
	_remote_targets.clear()
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
	_broadcast_stats()
	Network.broadcast({
		"type": "game_over",
		"winner": winner_id
	})

func _handle_game_over(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var winner_id = int(data.get("winner", -1))
	game_over_received.emit(winner_id)

func broadcast_sudden_death() -> void:
	sudden_death = true
	sudden_death_received.emit()
	if mode == Mode.ONLINE_HOST and Network.is_online():
		Network.broadcast({"type": "sudden_death"})

func _handle_sudden_death() -> void:
	if sudden_death:
		return
	sudden_death = true
	sudden_death_received.emit()

func broadcast_farm_spawns(assignments: Array) -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	Network.broadcast({
		"type": "farm_spawns",
		"a": assignments
	})

func _handle_farm_spawns(data: Dictionary) -> void:
	var assignments = data.get("a", [])
	if assignments is Array:
		farm_spawns_received.emit(assignments)

func notify_ult_used(player_id: int) -> void:
	if mode == Mode.LOCAL:
		ult_used_received.emit(player_id)
		return
	if mode == Mode.ONLINE_HOST and Network.is_online():
		ult_used_received.emit(player_id)
		Network.broadcast({"type": "ult_used", "pid": player_id})

func _handle_ult_used(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var pid = int(data.get("pid", -1))
	if pid >= 0:
		ult_used_received.emit(pid)

func cast_burple_grenade(owner_id: int, aim_pos: Vector2, gid: String) -> void:
	if gid.is_empty():
		return
	if mode == Mode.ONLINE_CLIENT:
		Network.send_to_host({
			"type": "burple_grenade_req",
			"pid": owner_id,
			"gid": gid,
			"tx": aim_pos.x,
			"ty": aim_pos.y
		})
		return
	var msg := _make_burple_grenade_spawn(owner_id, aim_pos, gid)
	if msg.is_empty():
		return
	_spawn_burple_grenade(msg, true)
	if mode == Mode.ONLINE_HOST and Network.is_online():
		var out := msg.duplicate()
		out["type"] = "burple_grenade_spawn"
		Network.broadcast(out)

func report_burple_grenade_boom(gid: String, pos: Vector2) -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	Network.broadcast({
		"type": "burple_grenade_boom",
		"gid": gid,
		"x": pos.x,
		"y": pos.y
	})

func _handle_burple_grenade_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var gid := str(data.get("gid", ""))
	if gid.is_empty():
		return
	cast_burple_grenade(from_id, Vector2(data.get("tx", 0.0), data.get("ty", 0.0)), gid)

func _handle_burple_grenade_spawn(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	_spawn_burple_grenade(data, false)

func _handle_burple_grenade_boom(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var gid := str(data.get("gid", ""))
	var grenade: BurpleGrenade = _burple_grenades.get(gid) as BurpleGrenade
	if grenade == null or not is_instance_valid(grenade):
		return
	grenade.force_boom(Vector2(data.get("x", 0.0), data.get("y", 0.0)))

func _make_burple_grenade_spawn(owner_id: int, aim_pos: Vector2, gid: String) -> Dictionary:
	var player := get_player(owner_id)
	if player == null or not is_instance_valid(player) or player.hero == null:
		return {}
	var land := aim_pos
	var range := player.hero.get_ability1_range()
	if range > 0.0:
		var off := land - player.global_position
		if off.length() > range:
			land = player.global_position + off.normalized() * range
	var dir := land - player.global_position
	if dir.length_squared() < 0.01:
		dir = player.get_aim_direction()
	else:
		dir = dir.normalized()
	var start := player.global_position + dir * 36.0
	return {
		"pid": owner_id,
		"gid": gid,
		"sx": start.x,
		"sy": start.y,
		"tx": land.x,
		"ty": land.y
	}

func _spawn_burple_grenade(data: Dictionary, authoritative: bool) -> void:
	var gid := str(data.get("gid", ""))
	if gid.is_empty():
		return
	var prev: BurpleGrenade = _burple_grenades.get(gid) as BurpleGrenade
	if prev != null and is_instance_valid(prev):
		return
	var owner_id := int(data.get("pid", -1))
	var owner := get_player(owner_id)
	if owner == null or not is_instance_valid(owner):
		return
	var grenade: BurpleGrenade = BurpleGrenadeScene.instantiate() as BurpleGrenade
	grenade.owner_player = owner
	grenade.grenade_id = gid
	grenade.authoritative = authoritative
	grenade.global_position = Vector2(data.get("sx", owner.global_position.x), data.get("sy", owner.global_position.y))
	grenade.landing_point = Vector2(data.get("tx", owner.global_position.x), data.get("ty", owner.global_position.y))
	var parent: Node = entity_parent if entity_parent else self
	parent.add_child(grenade)
	_burple_grenades[gid] = grenade
	grenade.tree_exited.connect(func():
		if _burple_grenades.get(gid) == grenade:
			_burple_grenades.erase(gid)
	)

func cast_burple_strike(owner_id: int, aim_pos: Vector2, sid: String) -> void:
	if sid.is_empty():
		return
	if mode == Mode.ONLINE_CLIENT:
		Network.send_to_host({
			"type": "burple_strike_req",
			"pid": owner_id,
			"sid": sid,
			"tx": aim_pos.x,
			"ty": aim_pos.y
		})
		return
	var msg := _make_burple_strike_spawn(owner_id, aim_pos, sid)
	if msg.is_empty():
		return
	_spawn_burple_strike(msg, true)
	if mode == Mode.ONLINE_HOST and Network.is_online():
		var out := msg.duplicate()
		out["type"] = "burple_strike_spawn"
		Network.broadcast(out)

func report_burple_strike_pulse(sid: String) -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	Network.broadcast({
		"type": "burple_strike_pulse",
		"sid": sid
	})

func report_burple_strike_end(sid: String) -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	Network.broadcast({
		"type": "burple_strike_end",
		"sid": sid
	})

func _handle_burple_strike_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var sid := str(data.get("sid", ""))
	if sid.is_empty():
		return
	cast_burple_strike(from_id, Vector2(data.get("tx", 0.0), data.get("ty", 0.0)), sid)

func _handle_burple_strike_spawn(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	_spawn_burple_strike(data, false)

func _handle_burple_strike_pulse(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var sid := str(data.get("sid", ""))
	var strike: BurpleMissileStrike = _burple_strikes.get(sid) as BurpleMissileStrike
	if strike == null or not is_instance_valid(strike):
		return
	strike.play_pulse()

func _handle_burple_strike_end(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var sid := str(data.get("sid", ""))
	var strike: BurpleMissileStrike = _burple_strikes.get(sid) as BurpleMissileStrike
	if strike == null or not is_instance_valid(strike):
		return
	strike.force_end()

func _make_burple_strike_spawn(owner_id: int, aim_pos: Vector2, sid: String) -> Dictionary:
	var player := get_player(owner_id)
	if player == null or not is_instance_valid(player) or player.hero == null:
		return {}
	var target := aim_pos
	var range := player.hero.get_ult_range()
	if range > 0.0:
		var off := target - player.global_position
		if off.length() > range:
			target = player.global_position + off.normalized() * range
	return {
		"pid": owner_id,
		"sid": sid,
		"x": target.x,
		"y": target.y
	}

func _spawn_burple_strike(data: Dictionary, authoritative: bool) -> void:
	var sid := str(data.get("sid", ""))
	if sid.is_empty():
		return
	var prev: BurpleMissileStrike = _burple_strikes.get(sid) as BurpleMissileStrike
	if prev != null and is_instance_valid(prev):
		return
	var owner_id := int(data.get("pid", -1))
	var owner := get_player(owner_id)
	if owner == null or not is_instance_valid(owner):
		return
	var strike: BurpleMissileStrike = BurpleStrikeScene.instantiate() as BurpleMissileStrike
	strike.owner_player = owner
	strike.strike_id = sid
	strike.authoritative = authoritative
	strike.global_position = Vector2(data.get("x", owner.global_position.x), data.get("y", owner.global_position.y))
	var parent: Node = entity_parent if entity_parent else self
	parent.add_child(strike)
	_burple_strikes[sid] = strike
	strike.tree_exited.connect(func():
		if _burple_strikes.get(sid) == strike:
			_burple_strikes.erase(sid)
	)

func cast_dingus_orbital(owner_id: int, pos: Vector2, oid: String) -> void:
	if oid.is_empty():
		return
	if mode == Mode.ONLINE_CLIENT:
		Network.send_to_host({
			"type": "dingus_orbital_req",
			"pid": owner_id,
			"oid": oid,
			"x": pos.x,
			"y": pos.y
		})
		return
	var msg := _make_dingus_orbital_spawn(owner_id, pos, oid)
	if msg.is_empty():
		return
	_spawn_dingus_orbital(msg, true)
	if mode == Mode.ONLINE_HOST and Network.is_online():
		var out := msg.duplicate()
		out["type"] = "dingus_orbital_spawn"
		Network.broadcast(out)

func _handle_dingus_orbital_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var pid := int(data.get("pid", -1))
	if pid != from_id:
		return
	cast_dingus_orbital(pid, Vector2(data.get("x", 0.0), data.get("y", 0.0)), str(data.get("oid", "")))

func _handle_dingus_orbital_spawn(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	_spawn_dingus_orbital(data, false)

func _make_dingus_orbital_spawn(owner_id: int, pos: Vector2, oid: String) -> Dictionary:
	var player := get_player(owner_id)
	if player == null or not is_instance_valid(player):
		return {}
	return {
		"pid": owner_id,
		"oid": oid,
		"x": pos.x,
		"y": pos.y
	}

## Loan Shark dash-hit side effects (chomp visual + mark clear + ability1 cooldown refresh) are
## host-authoritative. See sync_bugs #4: we route them through a dedicated broadcast so clients
## only apply them when the host confirmed the hit.
func broadcast_loan_dash_hit(attacker_id: int, victim_id: int, was_marked: bool) -> void:
	if not is_host() or not Network.is_online():
		return
	Network.broadcast({
		"type": "loan_dash_hit",
		"a": attacker_id,
		"v": victim_id,
		"m": was_marked
	})

func _handle_loan_dash_hit(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var aid := int(data.get("a", -1))
	var vid := int(data.get("v", -1))
	var was_marked := bool(data.get("m", false))
	var attacker := get_player(aid)
	var victim := get_player(vid)
	if victim == null or not is_instance_valid(victim):
		return
	if was_marked and attacker and is_instance_valid(attacker) and attacker.hero:
		attacker.hero.refresh_ability1_cooldown()
		victim.clear_mark_effect()
	var chomp := ChompEffectScene.instantiate()
	victim.add_child(chomp)
	chomp.global_position = victim.global_position
	chomp.z_index = 5

## Owner client asks the host to roll Dingus's ult strike pattern; only the host should pick the
## RNG-driven strike coordinates (see sync_bugs #6) so malicious/broken clients can't aim
## orbitals anywhere on the map.
func _handle_dingus_ult_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var pid := int(data.get("pid", -1))
	if pid != from_id:
		return
	var seq := int(data.get("seq", 0))
	var owner := get_player(pid)
	if owner == null or not is_instance_valid(owner) or owner.hero == null:
		return
	if not (owner.hero is HeroAnderDingus):
		return
	_roll_and_cast_dingus_ult(owner, seq)

func _roll_and_cast_dingus_ult(owner: Player, seq: int) -> void:
	if owner == null or owner.hero == null or not (owner.hero is HeroAnderDingus):
		return
	var h := owner.hero as HeroAnderDingus
	h._play_ult_sfx()
	var area: Rect2 = h._get_map_area()
	var rng := RandomNumberGenerator.new()
	rng.seed = (owner.player_id * 1_000_003) ^ seq
	for i in range(h.ult_strike_count):
		var x := rng.randf_range(area.position.x, area.end.x)
		var y := rng.randf_range(area.position.y, area.end.y)
		cast_dingus_orbital(owner.player_id, Vector2(x, y), "%s:%s:%s" % [owner.player_id, seq, i])

func _spawn_dingus_orbital(data: Dictionary, authoritative: bool) -> void:
	var oid := str(data.get("oid", ""))
	if oid.is_empty():
		return
	var prev = _ander_orbitals.get(oid)
	if prev != null and is_instance_valid(prev):
		return
	var owner_id := int(data.get("pid", -1))
	var owner := get_player(owner_id)
	if owner == null or not is_instance_valid(owner):
		return
	var strike = AnderOrbitalScene.instantiate()
	strike.owner_player = owner
	strike.orbital_id = oid
	strike.authoritative = authoritative
	strike.global_position = Vector2(data.get("x", owner.global_position.x), data.get("y", owner.global_position.y))
	var parent: Node = entity_parent if entity_parent else self
	parent.add_child(strike)
	_ander_orbitals[oid] = strike
	strike.tree_exited.connect(func():
		if _ander_orbitals.get(oid) == strike:
			_ander_orbitals.erase(oid)
	)

# --- ELONGATED MUSKRAT SYNC ---

func has_muskrat_ult_for_owner(owner_id: int) -> bool:
	for ult in _muskrat_ults.values():
		if ult and is_instance_valid(ult) and ult.owner_player and ult.owner_player.player_id == owner_id:
			return true
	return false

func cast_muskrat_ult(owner_id: int, center: Vector2, uid: String, cfg: Dictionary) -> void:
	if uid.is_empty():
		return
	if mode == Mode.ONLINE_CLIENT:
		Network.send_to_host({
			"type": "muskrat_ult_req",
			"pid": owner_id,
			"uid": uid,
			"x": center.x,
			"y": center.y,
			"cfg": cfg,
		})
		return
	var msg := _make_muskrat_ult_spawn(owner_id, center, uid, cfg)
	if msg.is_empty():
		return
	_spawn_muskrat_ult(msg, true)
	if mode == Mode.ONLINE_HOST and Network.is_online():
		var out := msg.duplicate(true)
		out["type"] = "muskrat_ult_spawn"
		Network.broadcast(out)

func report_muskrat_ult_tp(uid: String, a: Vector2, b: Vector2) -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	Network.broadcast({
		"type": "muskrat_ult_tp",
		"uid": uid,
		"ax": a.x,
		"ay": a.y,
		"bx": b.x,
		"by": b.y,
	})

func report_muskrat_ult_end(uid: String) -> void:
	if mode != Mode.ONLINE_HOST or not Network.is_online():
		return
	Network.broadcast({
		"type": "muskrat_ult_end",
		"uid": uid,
	})

func request_muskrat_held_steal(thief_id: int, victim_id: int, crop_type: String, stg: int) -> void:
	if crop_type.is_empty():
		return
	if mode == Mode.ONLINE_CLIENT:
		Network.send_to_host({
			"type": "muskrat_hold_steal_req",
			"th": thief_id,
			"vi": victim_id,
			"ct": crop_type,
			"cs": stg,
		})
		return
	_apply_muskrat_hold_steal(thief_id, victim_id, crop_type, stg, true)

func _handle_muskrat_ult_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var pid := int(data.get("pid", -1))
	if pid != from_id:
		return
	cast_muskrat_ult(pid, Vector2(data.get("x", 0.0), data.get("y", 0.0)), str(data.get("uid", "")), data.get("cfg", {}))

func _handle_muskrat_ult_spawn(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	_spawn_muskrat_ult(data, false)

func _handle_muskrat_ult_tp_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var uid := str(data.get("uid", ""))
	var ult = _muskrat_ults.get(uid)
	if ult == null or not is_instance_valid(ult) or ult.owner_player == null:
		return
	if ult.owner_player.player_id != from_id:
		return
	ult.request_tp(Vector2(data.get("x", 0.0), data.get("y", 0.0)))

func _handle_muskrat_ult_tp(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var uid := str(data.get("uid", ""))
	var ult = _muskrat_ults.get(uid)
	if ult == null or not is_instance_valid(ult):
		return
	ult.play_remote_tp(Vector2(data.get("ax", 0.0), data.get("ay", 0.0)), Vector2(data.get("bx", 0.0), data.get("by", 0.0)))

func _handle_muskrat_ult_end(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var uid := str(data.get("uid", ""))
	var ult = _muskrat_ults.get(uid)
	if ult == null or not is_instance_valid(ult):
		return
	ult.force_end_remote()

func _handle_muskrat_hold_steal_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var thief := int(data.get("th", -1))
	if thief != from_id:
		return
	_apply_muskrat_hold_steal(thief, int(data.get("vi", -1)), str(data.get("ct", "")), int(data.get("cs", 1)), true)

func _handle_muskrat_hold_steal(data: Dictionary) -> void:
	_apply_muskrat_hold_steal(int(data.get("th", -1)), int(data.get("vi", -1)), str(data.get("ct", "")), int(data.get("cs", 1)), false)

func _make_muskrat_ult_spawn(owner_id: int, center: Vector2, uid: String, cfg: Dictionary) -> Dictionary:
	var p := get_player(owner_id)
	if p == null or not is_instance_valid(p):
		return {}
	return {
		"uid": uid,
		"pid": owner_id,
		"x": center.x,
		"y": center.y,
		"cfg": cfg.duplicate(true),
	}

func _spawn_muskrat_ult(data: Dictionary, authoritative: bool) -> void:
	var uid := str(data.get("uid", ""))
	if uid.is_empty():
		return
	var old = _muskrat_ults.get(uid)
	if old != null and is_instance_valid(old):
		return
	var owner_id := int(data.get("pid", -1))
	var owner_player := get_player(owner_id)
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var ult = MuskratUltScene.instantiate()
	ult.owner_player = owner_player
	ult.ult_id = uid
	ult.authoritative = authoritative
	var cfg: Dictionary = data.get("cfg", {})
	if cfg.has("radius"):
		ult.zone_radius = float(cfg.get("radius", ult.zone_radius))
	if cfg.has("dur"):
		ult.duration = float(cfg.get("dur", ult.duration))
	if cfg.has("tp"):
		ult.teleport_cd = float(cfg.get("tp", ult.teleport_cd))
	if cfg.has("ldmg"):
		ult.line_damage = float(cfg.get("ldmg", ult.line_damage))
	if cfg.has("llife"):
		ult.line_life = float(cfg.get("llife", ult.line_life))
	if cfg.has("edmg"):
		ult.explosion_damage = float(cfg.get("edmg", ult.explosion_damage))
	ult.global_position = Vector2(data.get("x", owner_player.global_position.x), data.get("y", owner_player.global_position.y))
	var parent: Node = entity_parent if entity_parent else self
	parent.add_child(ult)
	_muskrat_ults[uid] = ult
	ult.tree_exited.connect(func():
		if _muskrat_ults.get(uid) == ult:
			_muskrat_ults.erase(uid)
	)

func _apply_muskrat_hold_steal(thief_id: int, victim_id: int, crop_type: String, stg: int, should_broadcast: bool) -> void:
	if crop_type.is_empty():
		return
	var thief := get_player(thief_id)
	var victim := get_player(victim_id)
	if thief == null or victim == null or not is_instance_valid(thief) or not is_instance_valid(victim):
		return
	if not thief.can_receive_held_crop():
		return
	if not thief.get_any_held_crop_data().is_empty():
		return
	var available: Dictionary = victim.get_any_held_crop_data()
	if available.is_empty():
		return
	var real_type := str(available.get("type", crop_type))
	var real_stage := int(available.get("stage", stg))
	if _is_player_local_instance(victim):
		victim.force_clear_held_crop_local()
	else:
		victim.clear_remote_held_crop()
	if _is_player_local_instance(thief):
		thief.receive_stolen_crop(real_type, real_stage)
	else:
		thief.set_remote_held_crop(real_type, real_stage)
	_host_held_crops.erase(victim_id)
	_host_held_crops[thief_id] = {"t": real_type, "s": real_stage}
	if should_broadcast and mode == Mode.ONLINE_HOST and Network.is_online():
		Network.broadcast({
			"type": "muskrat_hold_steal",
			"th": thief_id,
			"vi": victim_id,
			"ct": real_type,
			"cs": real_stage,
		})

func _is_player_local_instance(p: Player) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	if mode == Mode.LOCAL:
		return true
	if p.input is NetworkInput:
		return p.input.is_local
	if p.input is LocalInput:
		return p.player_id == 0
	return false

# --- XYLER / FERGUS SYNC ---

func sync_xf_stance(pid: int, st: int) -> void:
	if not Network.is_online():
		return
	var msg := {"type": "xf_stance", "pid": pid, "st": st}
	if mode == Mode.ONLINE_HOST:
		Network.broadcast(msg)
	else:
		Network.send_to_host({"type": "xf_stance_req", "pid": pid, "st": st})

func xf_fergus_mark_hit(attacker_id: int, victim_id: int) -> void:
	if not Network.is_online():
		_xf_fergus_mark_impl(attacker_id, victim_id)
		return
	if mode == Mode.ONLINE_CLIENT:
		Network.send_to_host({"type": "xf_mark_hit", "a": attacker_id, "v": victim_id})
		return
	_xf_fergus_mark_impl(attacker_id, victim_id)

func _xf_fergus_mark_impl(attacker_id: int, victim_id: int) -> void:
	var key := "%d:%d" % [attacker_id, victim_id]
	var n: int = int(_xf_mark_counts.get(key, 0)) + 1
	var need := _xf_marks_needed(attacker_id)
	if n >= need:
		_xf_mark_counts.erase(key)
		_xf_do_xyler_slash(attacker_id, victim_id)
	else:
		_xf_mark_counts[key] = n

func _xf_marks_needed(attacker_id: int) -> int:
	var p := get_player(attacker_id)
	if p and is_instance_valid(p) and p.hero is HeroXylerFergus:
		return maxi(1, (p.hero as HeroXylerFergus).fergus_marks_for_slash)
	return XF_MARKS_FOR_SLASH_DEFAULT

func _xf_do_xyler_slash(attacker_id: int, victim_id: int) -> void:
	var attacker := get_player(attacker_id)
	var victim := get_player(victim_id)
	if attacker == null or victim == null or not is_instance_valid(attacker) or not is_instance_valid(victim):
		return
	victim.take_damage(XF_SLASH_DAMAGE, attacker)
	victim.spawn_mark_projectile_hit_fx()
	if Network.is_online() and mode == Mode.ONLINE_HOST:
		Network.broadcast({"type": "xf_slash", "a": attacker_id, "v": victim_id})

func _handle_xf_stance_req(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var pid := int(data.get("pid", -1))
	if pid != from_id:
		return
	Network.broadcast({"type": "xf_stance", "pid": pid, "st": int(data.get("st", 0))})

func _handle_xf_stance(data: Dictionary) -> void:
	var pid := int(data.get("pid", -1))
	var st := int(data.get("st", 0))
	var p := get_player(pid)
	if p == null or p.hero == null:
		return
	if p.hero is HeroXylerFergus:
		(p.hero as HeroXylerFergus).apply_remote_stance(st)

func _handle_xf_mark_hit(from_id: int, data: Dictionary) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	var aid := int(data.get("a", -1))
	if aid != from_id:
		return
	var vid := int(data.get("v", -1))
	_xf_fergus_mark_impl(aid, vid)

func _handle_xf_slash(data: Dictionary) -> void:
	if mode == Mode.ONLINE_HOST:
		return
	var vid := int(data.get("v", -1))
	var victim := get_player(vid)
	if victim and is_instance_valid(victim):
		victim.spawn_mark_projectile_hit_fx()

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
	"SpeedCarrot": preload("res://scenes/crops/speed_carrot.tscn"),
	"IronRoot": preload("res://scenes/crops/iron_root.tscn"),
	"BlastBerry": preload("res://scenes/crops/blast_berry.tscn"),
	"Dragonfruit": preload("res://scenes/crops/dragonfruit.tscn"),
	"CoffeeBean": preload("res://scenes/crops/coffee_bean.tscn"),
	"BulletBalloon": preload("res://scenes/crops/bullet_balloon.tscn"),
	"Heartburst": preload("res://scenes/crops/heartburst.tscn"),
	"RushRoom": preload("res://scenes/crops/rush_room.tscn"),
	"Hypnoflower": preload("res://scenes/crops/hypnoflower.tscn"),
	"Cloudberry": preload("res://scenes/crops/cloudberry.tscn"),
	"SweetPatchChild": preload("res://scenes/crops/sweet_patch_child.tscn"),
	"Star": preload("res://scenes/crops/star.tscn"),
}

var _host_held_crops: Dictionary = {}

## Crops that exist in the world (spawner + dropped) keyed by stable host-authoritative crop_id.
## Pickup arbitration uses this for exact identity (see sync_bugs #10 + position-desync cascade).
## Position-based lookup stays as a fallback for any un-id'd crop (legacy or starter).
var _world_crops: Dictionary = {}

func register_world_crop(crop: Crop) -> void:
	if crop == null or not is_instance_valid(crop):
		return
	if mode == Mode.LOCAL:
		return
	var cid := crop.crop_id
	if cid.is_empty():
		return
	_world_crops[cid] = crop
	crop.tree_exited.connect(func():
		if _world_crops.get(cid) == crop:
			_world_crops.erase(cid)
	)

func _find_world_crop_by_id(cid: String) -> Node:
	if cid.is_empty():
		return null
	var c = _world_crops.get(cid)
	if c != null and is_instance_valid(c) and c.is_inside_tree():
		return c
	if c != null:
		_world_crops.erase(cid)
	return null

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

func send_crop_pickup(picker_id: int, pos: Vector2, crop_type: String, stg: int, cid: String = "") -> void:
	var msg = {
		"type": "crop_pickup",
		"pid": picker_id,
		"x": pos.x,
		"y": pos.y,
		"ct": crop_type,
		"cs": stg,
		"cid": cid
	}
	if mode == Mode.ONLINE_HOST:
		_host_held_crops[picker_id] = {"t": crop_type, "s": stg}
		Network.broadcast(msg)
	else:
		Network.send_to_host(msg)

func send_crop_dropped(dropper_id: int, pos: Vector2, crop_type: String, stg: int, cid: String = "") -> void:
	var msg = {
		"type": "crop_dropped",
		"pid": dropper_id,
		"x": pos.x,
		"y": pos.y,
		"ct": crop_type,
		"cs": stg,
		"cid": cid
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
	var pos = Vector2(data.get("x", 0), data.get("y", 0))
	var cid := str(data.get("cid", ""))

	# Host arbitrates first-arrival by stable crop_id (falls back to position for any legacy
	# id-less crop). If the crop is already gone, reject the loser and force-clear their local
	# held crop. See sync_bugs #10 + the spawner/pickup desync fix.
	if mode == Mode.ONLINE_HOST:
		var world_crop: Node = _find_world_crop_by_id(cid)
		if world_crop == null:
			world_crop = _find_world_crop_at(pos)
		if world_crop == null:
			if picker_id != local_player_id:
				Network.send_to_player(picker_id, {
					"type": "crop_pickup_reject",
					"cid": cid,
					"x": pos.x,
					"y": pos.y
				})
			return
		# Synchronously evict from registry so back-to-back pickup msgs in the same frame can't
		# both succeed (queue_free is deferred; tree_exited fires later).
		if cid != "":
			_world_crops.erase(cid)
		world_crop.queue_free()
		_host_held_crops[picker_id] = {"t": data.get("ct", ""), "s": int(data.get("cs", 1))}
		Network.broadcast(data)
	if picker_id == local_player_id:
		return
	# On non-host peers the broadcast arrival is the authoritative pickup: remove the visual crop.
	if mode != Mode.ONLINE_HOST:
		var c: Node = _find_world_crop_by_id(cid)
		if c == null:
			c = _find_world_crop_at(pos)
		if c != null:
			c.queue_free()
	var picker = get_player(picker_id)
	if picker and is_instance_valid(picker):
		var ct = str(data.get("ct", ""))
		var cs = int(data.get("cs", 1))
		if ct != "":
			picker.set_remote_held_crop(ct, cs)

func _find_world_crop_at(pos: Vector2) -> Node:
	var parent = entity_parent if entity_parent else self
	for sid in _spawners:
		var spawner = _spawners[sid]
		if spawner and is_instance_valid(spawner) and spawner.current_crop and is_instance_valid(spawner.current_crop):
			var sc = spawner.current_crop
			# Skip if the crop was already picked up (parent is now a player, not the world layer).
			if sc.get_parent() != parent:
				continue
			if sc.global_position.distance_to(pos) < 80.0:
				spawner.current_crop = null
				return sc
	for child in parent.get_children():
		if child is Crop and not child.is_planted and child.global_position.distance_to(pos) < 80.0:
			return child
	return null

func _handle_crop_pickup_reject(data: Dictionary) -> void:
	if mode != Mode.ONLINE_CLIENT:
		return
	var player = get_local_player()
	if player == null or not is_instance_valid(player):
		return
	# Force the loser to drop what they locally picked up; the spawner crop they grabbed wasn't
	# actually available on the host.
	player.force_clear_held_crop_local()

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
	var cid := str(data.get("cid", ""))
	var scene = CROP_SCENES.get(type_id)
	if scene == null:
		return
	var crop = scene.instantiate() as Crop
	crop.stage = stg
	crop.crop_id = cid
	crop._setup()
	crop.global_position = pos
	var parent = entity_parent if entity_parent else self
	parent.add_child(crop)
	register_world_crop(crop)

# --- CROP SPAWNER SYNC ---

var _spawners: Dictionary = {}  # spawner_id -> CropSpawner node

func register_spawner(spawner: Node) -> void:
	var id = _spawners.size()
	spawner.spawner_id = id
	_spawners[id] = spawner

func send_crop_spawned(sid: int, crop_idx: int, stg: int, cid: String = "") -> void:
	if mode != Mode.ONLINE_HOST:
		return
	Network.broadcast({"type": "crop_spawned", "sid": sid, "ci": crop_idx, "cs": stg, "cid": cid})

func send_crop_bring(sid: int) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	Network.broadcast({"type": "crop_bring", "sid": sid})

func send_spawner_stage(sid: int, stg: int) -> void:
	if mode != Mode.ONLINE_HOST:
		return
	Network.broadcast({"type": "spawner_stage", "sid": sid, "cs": stg})

func _handle_crop_spawned(data: Dictionary) -> void:
	var sid = int(data.get("sid", -1))
	var spawner = _spawners.get(sid)
	if spawner and is_instance_valid(spawner):
		spawner.spawn_crop_remote(int(data.get("ci", 0)), int(data.get("cs", 1)), str(data.get("cid", "")))

func _handle_crop_bring(data: Dictionary) -> void:
	var sid = int(data.get("sid", -1))
	var spawner = _spawners.get(sid)
	if spawner and is_instance_valid(spawner):
		spawner.play_bring_remote()

func _handle_spawner_stage(data: Dictionary) -> void:
	var sid = int(data.get("sid", -1))
	var spawner = _spawners.get(sid)
	if spawner and is_instance_valid(spawner):
		spawner.stage = int(data.get("cs", 1))

# --- FIE SYNC ---

func send_fie_placed(pid: int, slot: int, pos: Vector2) -> void:
	if mode == Mode.LOCAL:
		return
	var msg = {"type": "fie_placed", "pid": pid, "slot": slot, "x": pos.x, "y": pos.y}
	if mode == Mode.ONLINE_HOST:
		Network.broadcast(msg)
	else:
		Network.send_to_host(msg)

func send_fie_destroyed(pid: int, slot: int) -> void:
	if mode == Mode.LOCAL:
		return
	var msg = {"type": "fie_destroyed", "pid": pid, "slot": slot}
	if mode == Mode.ONLINE_HOST:
		Network.broadcast(msg)
	else:
		Network.send_to_host(msg)

func _handle_fie_placed(from_id: int, data: Dictionary) -> void:
	if mode == Mode.ONLINE_HOST:
		Network.broadcast(data)
	var pid = int(data.get("pid", from_id))
	if pid == local_player_id:
		return
	var slot = int(data.get("slot", 0))
	var pos = Vector2(data.get("x", 0), data.get("y", 0))
	var p = get_player(pid)
	if p == null or not is_instance_valid(p) or p.hero == null:
		return
	if p.hero is HeroGarebare:
		p.hero._place_fie_remote(slot, pos)

func _handle_fie_destroyed(from_id: int, data: Dictionary) -> void:
	if mode == Mode.ONLINE_HOST:
		Network.broadcast(data)
	var pid = int(data.get("pid", from_id))
	if pid == local_player_id:
		return
	var p = get_player(pid)
	if p == null or not is_instance_valid(p) or p.hero == null:
		return
	if p.hero is HeroGarebare:
		var slot = int(data.get("slot", 0))
		if slot >= 0 and slot < p.hero.fies.size():
			var fie = p.hero.fies[slot]
			if fie and is_instance_valid(fie):
				p.hero._fie_remote_op = true
				fie._destroy()
				p.hero._fie_remote_op = false

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
