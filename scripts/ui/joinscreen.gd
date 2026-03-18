extends Control

const SERVER_URL = "wss://server-still-cherry-1856.fly.dev"
const SAVE_PATH = "user://settings.cfg"

@onready var username_input: LineEdit = $VBox/UsernameInput
@onready var code_label_node: Label = $VBox/CodeLabel
@onready var code_input: LineEdit = $VBox/CodeInput
@onready var action_btn: Button = $VBox/ActionBtn
@onready var status_label: Label = $VBox/StatusLabel
@onready var back_btn: Button = $VBox/BackBtn

var _is_host: bool = false

func _ready() -> void:
	_is_host = GameData.game_mode == GameData.GameMode.HOST
	_load_username()

	if _is_host:
		code_label_node.visible = false
		code_input.visible = false
		action_btn.text = "HOST"
	else:
		action_btn.text = "JOIN"

	action_btn.pressed.connect(_on_action)
	back_btn.pressed.connect(_on_back)
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
		username_input.text = config.get_value("player", "username", "")

func _save_username() -> void:
	var config = ConfigFile.new()
	config.set_value("player", "username", username_input.text.strip_edges())
	config.save(SAVE_PATH)

func _on_username_changed(new_text: String) -> void:
	if new_text.length() > 15:
		username_input.text = new_text.substr(0, 15)
		username_input.caret_column = 15

func _get_username() -> String:
	var n = username_input.text.strip_edges()
	if n.is_empty():
		n = "Player" + str(randi() % 1000)
	return n

func _on_action() -> void:
	if _is_host:
		_host()
	else:
		_join()

func _host() -> void:
	_save_username()
	status_label.text = "Connecting..."
	_set_buttons(false)
	if Network.is_online():
		Network.host_room(_get_username())
	else:
		Network.connected.connect(func(): Network.host_room(_get_username()), CONNECT_ONE_SHOT)
		Network.connect_to_server(SERVER_URL)

func _join() -> void:
	var code = code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		status_label.text = "Enter a 6-character room code"
		return
	_save_username()
	status_label.text = "Connecting..."
	_set_buttons(false)
	if Network.is_online():
		Network.join_room(code, _get_username())
	else:
		Network.connected.connect(func(): Network.join_room(code, _get_username()), CONNECT_ONE_SHOT)
		Network.connect_to_server(SERVER_URL)

func _on_connected() -> void:
	status_label.text = "Connected"

func _on_hosted(_room_code: String, _pid: int) -> void:
	GameData.change_scene("res://scenes/ui/lobby.tscn")

func _on_joined(_pid: int, _am_host: bool) -> void:
	GameData.change_scene("res://scenes/ui/lobby.tscn")

func _on_error(msg: String) -> void:
	status_label.text = "Error: " + msg
	_set_buttons(true)

func _on_disconnected() -> void:
	status_label.text = "Disconnected"
	_set_buttons(true)

func _set_buttons(enabled: bool) -> void:
	action_btn.disabled = not enabled
	back_btn.disabled = not enabled

func _on_back() -> void:
	GameData.change_scene("res://scenes/ui/main_menu.tscn")
