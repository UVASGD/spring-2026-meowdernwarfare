extends Control

@export var parallax_purple: Vector2 = Vector2(14.0, 10.0)
@export var parallax_blue: Vector2 = Vector2(30.0, 22.0)
@export var parallax_smooth: float = 12.0

@onready var bg_purple: AnimatedSprite2D = $bgPurple
@onready var bg_blue: AnimatedSprite2D = $bgBlue
@onready var host_tv = $tvs/HostTV
@onready var p2_tv = $tvs/P2TV
@onready var p3_tv = $tvs/P3TV
@onready var p4_tv = $tvs/P4TV
@onready var all_tvs: Array = []

@onready var remote = $CharSelectRemote
@onready var sponsor = $SponsorSelector
@onready var map_sel = $mapSelector
@onready var code_label: Label = $RoomCodeLabel/Label

var selected_crop := ""
var ready_states: Dictionary = {}
var tv_map: Dictionary = {} # pid -> tv index

var _purple_base: Vector2
var _blue_base: Vector2
var _purple_off: Vector2 = Vector2.ZERO
var _blue_off: Vector2 = Vector2.ZERO

func _ready() -> void:
	all_tvs = [host_tv, p2_tv, p3_tv, p4_tv]
	_purple_base = bg_purple.position
	_blue_base = bg_blue.position

	code_label.text = "room code:\n" + Network.room_code.to_lower()

	# Network signals
	Network.lobby_state_updated.connect(_on_lobby_state)
	Network.kicked.connect(_on_kicked)
	Network.game_started.connect(_on_game_started)
	Network.became_host.connect(_on_became_host)
	Network.disconnected.connect(_on_disconnected)
	Network.message_received.connect(_on_message)

	# CharSelectRemote
	remote.hero_selected.connect(_on_hero_selected)
	remote.hero_hovered.connect(_on_hero_hovered)
	remote.ready_toggled.connect(_on_ready_toggled)
	remote.leave_requested.connect(_on_leave)

	# Map selector
	map_sel.map_selected.connect(_on_map_selected)

	# TV kick buttons
	for tv in all_tvs:
		tv.kick_requested.connect(_on_kick)

	# Host-specific setup
	_apply_host_controls()
	if Network.is_host:
		Network.set_settings({"map": map_sel.selected_map})

	# Restore state when returning from a game
	if not Network.lobby_state.is_empty():
		_on_lobby_state(Network.lobby_state)

func _process(delta: float) -> void:
	_update_bg_parallax(delta)

func _update_bg_parallax(delta: float) -> void:
	var norm := MenuParallax.mouse_norm(get_viewport())
	if norm == Vector2.INF:
		return
	_purple_off = MenuParallax.step(_purple_off, norm, parallax_purple, delta, parallax_smooth)
	_blue_off = MenuParallax.step(_blue_off, norm, parallax_blue, delta, parallax_smooth)
	bg_purple.position = _purple_base + _purple_off
	bg_blue.position = _blue_base + _blue_off

# ---------- LOBBY STATE ----------

func _on_lobby_state(state: Dictionary) -> void:
	var players = state.get("players", [])
	var settings = state.get("settings", {})

	# Build tv_map: host always on TV 0, others fill 1-3 in order
	tv_map.clear()
	var host_p = null
	var others: Array = []
	for p in players:
		if p.get("is_host", false):
			host_p = p
		else:
			others.append(p)

	if host_p:
		tv_map[int(host_p["id"])] = 0
	for i in range(mini(others.size(), 3)):
		tv_map[int(others[i]["id"])] = i + 1

	# Purge stale ready states
	var active_pids: Array = []
	for p in players:
		active_pids.append(int(p["id"]))
	for pid in ready_states.keys():
		if pid not in active_pids:
			ready_states.erase(pid)

	# Refresh every TV
	for i in range(4):
		var tv = all_tvs[i]
		var pdata = _player_at_tv(i, players)
		if pdata:
			var pid = int(pdata["id"])
			tv.pid = pid
			tv.turn_on(GameData.ensure_username(str(pdata.get("username", "player"))), pdata.get("is_host", false))
			tv.show_hero(pdata.get("hero", ""))
			tv.set_ready(ready_states.get(pid, false))
			tv.show_kick(Network.is_host and pid != Network.my_player_id)
		else:
			tv.turn_off()

	# Guests sync map from server settings
	if not Network.is_host and settings.has("map"):
		map_sel.set_map(settings["map"])

	_update_start_btn()

func _player_at_tv(idx: int, players: Array):
	for p in players:
		if tv_map.get(int(p["id"]), -1) == idx:
			return p
	return null

# ---------- HERO SELECTION ----------

func _on_hero_selected(hero_name: String) -> void:
	HeroRegistry.warm_scene(hero_name)
	Network.set_hero(hero_name)
	_update_local_tv(hero_name, false)
	_update_start_btn()

func _on_hero_hovered(hero_name: String) -> void:
	HeroRegistry.warm_scene(hero_name)
	_update_local_tv(hero_name, true)

func _update_local_tv(hero_name: String, preview: bool) -> void:
	var idx = tv_map.get(Network.my_player_id, -1)
	if idx >= 0:
		all_tvs[idx].show_hero(hero_name, preview)

# ---------- READY / START ----------

func _on_ready_toggled(is_ready: bool) -> void:
	if Network.is_host:
		Network.start_game()
	else:
		ready_states[Network.my_player_id] = is_ready
		Network.broadcast({"action": "ready", "ready": is_ready})
		var idx = tv_map.get(Network.my_player_id, -1)
		if idx >= 0:
			all_tvs[idx].set_ready(is_ready)
		sponsor.set_interactive(not is_ready)

func _on_message(from_id: int, data: Dictionary) -> void:
	if data.get("action") == "ready":
		ready_states[from_id] = data.get("ready", false)
		var idx = tv_map.get(from_id, -1)
		if idx >= 0:
			all_tvs[idx].set_ready(ready_states[from_id])
		_update_start_btn()

func _update_start_btn() -> void:
	if not Network.is_host:
		return
	var can_start = _all_guests_ready() and not remote.current_hero.is_empty()
	if can_start:
		remote.ready_btn.enable()
	else:
		remote.ready_btn.disable()

func _all_guests_ready() -> bool:
	for pid in tv_map:
		if pid == Network.my_player_id:
			continue
		if not ready_states.get(pid, false):
			return false
	return true

# ---------- SPONSOR ----------

func _on_crop_selected(crop_name: String) -> void:
	selected_crop = crop_name

# ---------- MAP ----------

func _on_map_selected(map_name) -> void:
	if Network.is_host:
		Network.set_settings({"map": map_name})

# ---------- KICK / LEAVE ----------

func _on_kick(player_id: int) -> void:
	if Network.is_host:
		Network.kick_player(player_id)

func _on_leave() -> void:
	Network.leave_room()
	Network.disconnect_from_server()
	GameData.change_scene("res://scenes/ui/main_menu.tscn")

# ---------- HOST CONTROLS ----------

func _apply_host_controls() -> void:
	map_sel.set_interactive(Network.is_host)
	if Network.is_host:
		remote.ready_btn.toggleable = false
		remote.ready_btn.disable()

func _on_became_host() -> void:
	ready_states.clear()
	_apply_host_controls()
	if not Network.lobby_state.is_empty():
		_on_lobby_state(Network.lobby_state)

# ---------- NETWORK EVENTS ----------

func _on_kicked() -> void:
	Network.disconnect_from_server()
	GameData.change_scene("res://scenes/ui/joinscreen.tscn")

func _on_game_started(players: Array, settings: Dictionary) -> void:
	GameData.set_online_game(players, settings)
	if not selected_crop.is_empty():
		GameData.pending_starter_crops = [selected_crop]
		GameData.starter_crops = [selected_crop]
		GameData.save_starter_crops()
	GameData.change_scene("res://scenes/game.tscn")

func _on_disconnected() -> void:
	GameData.change_scene("res://scenes/ui/main_menu.tscn")
