extends Control

const SERVER_URL = "wss://server-still-cherry-1856.fly.dev"
const HEROES = ["Dealer", "Burple", "Alien", "Xyler", "Fergus", "LoanShark"]
const MAPS = ["testArena", "Moon"]
const CROPS = ["SpeedSprout", "IronRoot", "BlastBerry"]
const MAX_STARTERS := 3

@onready var code_label: Label = $VBox/CodeLabel
@onready var player_list: VBoxContainer = $VBox/PlayerList
@onready var hero_selector: OptionButton = $VBox/HeroSelector
@onready var settings_panel: Control = $VBox/SettingsPanel
@onready var map_selector: OptionButton = $VBox/SettingsPanel/MapSelector
@onready var start_btn: Button = $VBox/ButtonRow/StartBtn
@onready var leave_btn: Button = $VBox/ButtonRow/LeaveBtn
@onready var status_label: Label = $VBox/StatusLabel
@onready var join_panel: Control = $JoinPanel
@onready var host_panel: Control = $HostPanel
@onready var guestbg: TextureRect = $guestbg
@onready var hostbg: TextureRect = $hostbg

var player_rows: Dictionary = {}
var _username: String = ""
var crop_buttons: Dictionary = {}
var selected_crops: Array[String] = []

func _ready() -> void:
	_load_username()
	
	# Setup hero selector
	hero_selector.clear()
	for h in HEROES:
		hero_selector.add_item(h)
	hero_selector.item_selected.connect(_on_hero_selected)
	
	# Setup map selector
	map_selector.clear()
	for map in MAPS:
		map_selector.add_item(map)
	map_selector.item_selected.connect(_on_map_selected)
	
	# Setup crop selector
	_setup_crop_selector()
	
	# Buttons
	start_btn.pressed.connect(_on_start)
	leave_btn.pressed.connect(_on_leave)
	
	# Network signals
	Network.lobby_state_updated.connect(_on_lobby_state)
	Network.kicked.connect(_on_kicked)
	Network.game_started.connect(_on_game_started)
	Network.became_host.connect(_on_became_host)
	Network.disconnected.connect(_on_disconnected)
	Network.hosted.connect(_on_room_hosted)
	Network.joined_room.connect(_on_room_joined)
	Network.error.connect(_on_network_error)
	
	# Initial UI state
	status_label.text = ""
	hero_selector.select(0)
	
	# If returning from a game with an active connection, skip host/join flow
	if Network.is_online() and Network.room_code != "":
		_resume_lobby()
	else:
		match GameData.game_mode:
			GameData.GameMode.HOST:
				_start_hosting()
			GameData.GameMode.JOIN:
				_show_join_ui()
			_:
				_show_join_ui()

func _load_username() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		_username = config.get_value("player", "username", "")
	if _username.is_empty():
		_username = "Player" + str(randi() % 1000)

func _save_username() -> void:
	var config = ConfigFile.new()
	config.set_value("player", "username", _username)
	config.save("user://settings.cfg")

func _get_username() -> String:
	if _username.is_empty():
		return "Player" + str(randi() % 1000)
	return _username

func _resume_lobby() -> void:
	join_panel.visible = false
	host_panel.visible = false
	$VBox.visible = true
	code_label.text = "Room: " + Network.room_code
	status_label.visible = false
	_update_host_controls()
	if not Network.lobby_state.is_empty():
		_on_lobby_state(Network.lobby_state)

func _start_hosting() -> void:
	join_panel.visible = false
	$VBox.visible = false
	host_panel.visible = true
	status_label.text = ""
	
	# Pre-fill username
	$HostPanel/UsernameInput.text = _username

func _on_create_room_pressed() -> void:
	_username = $HostPanel/UsernameInput.text.strip_edges()
	if _username.length() > 15:
		_username = _username.substr(0, 15)
	if _username.is_empty():
		_username = "Player" + str(randi() % 1000)
	_save_username()
	
	host_panel.visible = false
	status_label.text = "Connecting..."
	status_label.visible = true
	
	Network.connected.connect(_on_connected_as_host, CONNECT_ONE_SHOT)
	Network.connect_to_server(SERVER_URL)

func _on_connected_as_host() -> void:
	status_label.text = "Creating room..."
	Network.host_room(_get_username())
	# UI will be shown when hosted signal fires

func _on_room_hosted(_room_code: String, _player_id: int) -> void:
	host_panel.visible = false
	$VBox.visible = true
	code_label.text = "Room: " + Network.room_code
	status_label.visible = false
	_update_host_controls()
	Network.set_hero(HEROES[0])

func _show_join_ui() -> void:
	$VBox.visible = false
	join_panel.visible = true
	status_label.text = ""
	# Pre-fill username if we have one
	if $JoinPanel.has_node("UsernameInput"):
		$JoinPanel/UsernameInput.text = _username

func _on_join_submit(code: String) -> void:
	if code.length() != 6:
		status_label.text = "Code must be 6 characters"
		return
	
	# Get username from input if available
	if $JoinPanel.has_node("UsernameInput"):
		_username = $JoinPanel/UsernameInput.text.strip_edges()
		if _username.length() > 15:
			_username = _username.substr(0, 15)
		_save_username()
	
	join_panel.visible = false
	status_label.text = "Connecting..."
	status_label.visible = true
	
	var room_code = code.to_upper()
	Network.connected.connect(func(): _on_connected_as_client(room_code), CONNECT_ONE_SHOT)
	Network.connect_to_server(SERVER_URL)

func _on_connected_as_client(code: String) -> void:
	status_label.text = "Joining room..."
	Network.join_room(code, _get_username())

func _on_room_joined(_player_id: int, _is_host: bool) -> void:
	$VBox.visible = true
	code_label.text = "Room: " + Network.room_code
	_update_host_controls()
	Network.set_hero(HEROES[0])
	
	if not Network.lobby_state.is_empty():
		_on_lobby_state(Network.lobby_state)

func _on_network_error(msg: String) -> void:
	status_label.text = "Error: " + msg
	status_label.visible = true
	if not $VBox.visible:
		# Show the appropriate panel based on game mode
		if GameData.game_mode == GameData.GameMode.HOST:
			host_panel.visible = true
		else:
			join_panel.visible = true

func _on_lobby_state(state: Dictionary) -> void:
	var players = state.get("players", [])
	
	for child in player_list.get_children():
		child.queue_free()
	player_rows.clear()
	
	for p in players:
		var pid = int(p.get("id", -1))
		var row = _create_player_row(p)
		player_list.add_child(row)
		player_rows[pid] = row

func _create_player_row(p: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	var pid = int(p.get("id", -1))
	var username = p.get("username", "Player")
	var hero = p.get("hero", "")
	var is_host = p.get("is_host", false)
	
	var name_label = Label.new()
	name_label.text = username
	if is_host:
		name_label.text += " (Host)"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	
	var hero_label = Label.new()
	hero_label.text = hero if hero else "[No hero]"
	hero_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hero_label)
	
	if Network.is_host and pid != Network.my_player_id:
		var kick_btn = Button.new()
		kick_btn.text = "Kick"
		kick_btn.pressed.connect(func(): _kick_player(pid))
		row.add_child(kick_btn)
	
	return row

func _kick_player(pid: int) -> void:
	Network.kick_player(pid)

func _on_hero_selected(idx: int) -> void:
	var hero = HEROES[idx]
	Network.set_hero(hero)

func _on_map_selected(idx: int) -> void:
	var map_name = map_selector.get_item_text(idx)
	Network.set_settings({"map": map_name})

func _update_host_controls() -> void:
	if Network.is_host:
		settings_panel.visible = true
		start_btn.visible = true
		hostbg.visible = true
		
		guestbg.visible = false
	else:
		settings_panel.visible = false
		start_btn.visible = false
		hostbg.visible = false
		
		guestbg.visible = true
	

func _on_became_host() -> void:
	_update_host_controls()

func _on_start() -> void:
	Network.start_game()

func _on_leave() -> void:
	Network.leave_room()
	Network.disconnect_from_server()
	GameData.change_scene("res://scenes/ui/main_menu.tscn")

func _on_kicked() -> void:
	status_label.text = "You were kicked"
	await get_tree().create_timer(1.5).timeout
	Network.disconnect_from_server()
	GameData.change_scene("res://scenes/ui/main_menu.tscn")

func _on_game_started(players: Array, settings: Dictionary) -> void:
	GameData.set_online_game(players, settings)
	if not selected_crops.is_empty():
		GameData.pending_starter_crops = selected_crops.duplicate()
		GameData.starter_crops = selected_crops.duplicate()
		GameData.save_starter_crops()
	GameData.change_scene("res://scenes/game.tscn")

func _on_disconnected() -> void:
	status_label.text = "Disconnected"
	await get_tree().create_timer(1.0).timeout
	GameData.change_scene("res://scenes/ui/main_menu.tscn")

func _on_join_btn_pressed() -> void:
	var code = $JoinPanel/CodeInput.text.strip_edges()
	_on_join_submit(code)

func _on_back_btn_pressed() -> void:
	GameData.change_scene("res://scenes/ui/main_menu.tscn")

# --- CROP SELECTOR ---

func _setup_crop_selector() -> void:
	selected_crops = GameData.starter_crops.duplicate()
	
	var vbox = $VBox
	var container = VBoxContainer.new()
	container.name = "CropSelector"
	
	var title = Label.new()
	title.text = "Starter Crops (%d/%d)" % [selected_crops.size(), MAX_STARTERS]
	title.name = "CropTitle"
	container.add_child(title)
	
	var grid = HBoxContainer.new()
	grid.name = "CropGrid"
	for crop_name in CROPS:
		var btn = Button.new()
		btn.text = crop_name
		btn.toggle_mode = true
		btn.button_pressed = crop_name in selected_crops
		btn.toggled.connect(func(pressed): _on_crop_toggled(crop_name, pressed))
		grid.add_child(btn)
		crop_buttons[crop_name] = btn
	container.add_child(grid)
	
	# Insert before ButtonRow
	var btn_row = $VBox/ButtonRow
	vbox.add_child(container)
	vbox.move_child(container, btn_row.get_index())

func _on_crop_toggled(crop_name: String, pressed: bool) -> void:
	if pressed:
		if selected_crops.size() >= MAX_STARTERS:
			crop_buttons[crop_name].button_pressed = false
			return
		if crop_name not in selected_crops:
			selected_crops.append(crop_name)
	else:
		selected_crops.erase(crop_name)
	
	var title = $VBox/CropSelector/CropTitle
	if title:
		title.text = "Starter Crops (%d/%d)" % [selected_crops.size(), MAX_STARTERS]
	
	GameData.pending_starter_crops = selected_crops.duplicate()
