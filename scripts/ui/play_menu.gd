extends Control

const SERVER_URL = "wss://server-still-cherry-1856.fly.dev"
const SAVE_PATH = "user://settings.cfg"

@onready var username_input: LineEdit = $VBox/UsernameInput
@onready var host_btn: Button = $VBox/HostBtn
@onready var join_btn: Button = $VBox/JoinBtn
@onready var code_input: LineEdit = $VBox/CodeInput
@onready var status_label: Label = $VBox/StatusLabel

func _ready() -> void:
	_load_username()
	
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	username_input.text_changed.connect(_on_username_changed)
	
	Network.connected.connect(_on_connected)
	Network.hosted.connect(_on_hosted)
	Network.joined_room.connect(_on_joined)
	Network.error.connect(_on_error)
	Network.disconnected.connect(_on_disconnected)
	
	status_label.text = ""

func _load_username() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		username_input.text = GameData.normalize_username(str(config.get_value("player", "username", "")))

func _save_username() -> void:
	var config = ConfigFile.new()
	config.set_value("player", "username", GameData.ensure_username(username_input.text))
	config.save(SAVE_PATH)

func _on_username_changed(new_text: String) -> void:
	var fixed := GameData.normalize_username(new_text)
	if fixed != new_text:
		username_input.text = fixed
		username_input.caret_column = fixed.length()

func _get_username() -> String:
	return GameData.ensure_username(username_input.text, "player")

func _on_host() -> void:
	_save_username()
	status_label.text = "connecting..."
	_set_buttons_enabled(false)
	
	if Network.is_online():
		Network.host_room(_get_username())
	else:
		Network.connected.connect(func(): Network.host_room(_get_username()), CONNECT_ONE_SHOT)
		Network.connect_to_server(SERVER_URL)

func _on_join() -> void:
	var code = code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		status_label.text = "enter a 6-character room code"
		return
	
	_save_username()
	status_label.text = "connecting..."
	_set_buttons_enabled(false)
	
	if Network.is_online():
		Network.join_room(code, _get_username())
	else:
		Network.connected.connect(func(): Network.join_room(code, _get_username()), CONNECT_ONE_SHOT)
		Network.connect_to_server(SERVER_URL)

func _on_connected() -> void:
	status_label.text = "connected"

func _on_hosted(room_code: String, player_id: int) -> void:
	status_label.text = "room created: " + room_code.to_lower()
	GameData.change_scene("res://scenes/ui/lobby.tscn")

func _on_joined(player_id: int, am_host: bool) -> void:
	status_label.text = "joined room"
	GameData.change_scene("res://scenes/ui/lobby.tscn")

func _on_error(msg: String) -> void:
	status_label.text = "error: " + GameData.ui_lower(msg)
	_set_buttons_enabled(true)

func _on_disconnected() -> void:
	status_label.text = "disconnected"
	_set_buttons_enabled(true)

func _set_buttons_enabled(enabled: bool) -> void:
	host_btn.disabled = not enabled
	join_btn.disabled = not enabled
