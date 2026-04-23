extends Control

const CardAction = preload("res://scripts/ui/menu_hero_card.gd").CardAction

@export var unhover_delay: float = 0.25

@onready var option_banner = $introgroup1/paintstrip/OptionBanner
@onready var dealer = $introgroup1/cardholder/dealer
@onready var burple = $introgroup1/cardholder/burple
@onready var garebare = $introgroup1/cardholder/garebare
@onready var anim_player = $introgroup1/AnimationPlayer
@onready var burn_overlay = $BurnOverlay
@onready var bg_bottom = $introgroup1/bgbottomlayer
@onready var bg_top = $introgroup1/bgtoplayer
@onready var meowdern: Sprite2D = $introgroup1/meowdern

@export var bg_rot_bottom: Vector2 = Vector2(10.0, 7.0)
@export var bg_rot_top: Vector2 = Vector2(16.0, 11.0)
@export var text_rot_bottom: Vector2 = Vector2(10.0, 7.0)
@export var text_rot_top: Vector2 = Vector2(16.0, 11.0)
@export var text_rot_smooth: float = 12.0
@export var bg_rot_smooth: float = 12.0

var skippable = true
var _bg_bottom_mat: ShaderMaterial
var _bg_top_mat: ShaderMaterial
var _text_mat: ShaderMaterial
var _text_rot_b: Vector2 = Vector2.ZERO
var _text_rot_t: Vector2 = Vector2.ZERO
var _bg_rot_b: Vector2 = Vector2.ZERO
var _bg_rot_t: Vector2 = Vector2.ZERO
var _current_hovered: CardAction = CardAction.NONE
var _unhover_timer: SceneTreeTimer = null

func _ready() -> void:
	_bg_bottom_mat = bg_bottom.material as ShaderMaterial
	_bg_top_mat = bg_top.material as ShaderMaterial
	_text_mat = meowdern.material as ShaderMaterial
	_connect_card(dealer)
	_connect_card(burple)
	_connect_card(garebare)
	var local_theme = $introgroup1/AudioStreamPlayer
	local_theme.stop()
	local_theme.stream = null
	
	# Skip intro if returning from another scene
	if not GameData.is_first_load:
		GameData.ensure_menu_theme()
		_skip_intro()
	else:
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_inside_tree():
				GameData.ensure_menu_theme()
		, CONNECT_ONE_SHOT)
		GameData.mark_intro_seen()

func _skip_intro() -> void:
	if not skippable:
		return
	if burn_overlay:
		burn_overlay.queue_free()
	
	if anim_player:
		anim_player.stop()
		anim_player.play("idle2")
	GameData.ensure_menu_theme()
	# Ensure hover areas are enabled (animation keyframes at -0.1 won't apply)
	_enable_hover_areas()
	Cursor.switch_mode("MENU")
	Cursor.enable()

func _enable_hover_areas() -> void:
	for card in [dealer, burple, garebare]:
		if card:
			var hover = card.get_node_or_null("HoverArea")
			if hover:
				hover.input_pickable = true

func _connect_card(card: Node) -> void:
	if card and card.has_signal("card_hovered"):
		card.card_hovered.connect(_on_card_hovered)
	if card and card.has_signal("card_unhovered"):
		card.card_unhovered.connect(_on_card_unhovered)

func _process(delta: float) -> void:
	_update_bg_3d_mouse(delta)

func _update_bg_3d_mouse(delta: float) -> void:
	if _bg_bottom_mat == null or _bg_top_mat == null:
		return
	var norm := MenuParallax.mouse_norm(get_viewport())
	if norm == Vector2.INF:
		return
	_bg_rot_b = MenuParallax.step(_bg_rot_b, norm, bg_rot_bottom, delta, bg_rot_smooth)
	_bg_rot_t = MenuParallax.step(_bg_rot_t, norm, bg_rot_top, delta, bg_rot_smooth)
	_text_rot_b = MenuParallax.step(_text_rot_b, norm, text_rot_bottom, delta, bg_rot_smooth)
	_text_rot_t = MenuParallax.step(_text_rot_t, norm, text_rot_top, delta, bg_rot_smooth)
	_bg_bottom_mat.set_shader_parameter("y_rot", _bg_rot_b.x)
	_bg_bottom_mat.set_shader_parameter("x_rot", _bg_rot_b.y)
	_bg_top_mat.set_shader_parameter("y_rot", _bg_rot_t.x)
	_bg_top_mat.set_shader_parameter("x_rot", _bg_rot_t.y)
	_text_mat.set_shader_parameter("y_rot", _text_rot_b.x)
	_text_mat.set_shader_parameter("x_rot", _text_rot_b.y)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_skip_intro()
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		_quick_test()

func _on_card_hovered(action: CardAction) -> void:
	if not option_banner:
		return
	
	# Cancel any pending unhover reset
	_unhover_timer = null
	_current_hovered = action
	
	match action:
		CardAction.JOIN:
			option_banner.set_option(1)
		CardAction.HOST:
			option_banner.set_option(2)
		CardAction.PRACTICE:
			option_banner.set_option(3)

func _on_card_unhovered() -> void:
	if not option_banner:
		return
	
	# Delay the reset to allow switching directly between cards
	_unhover_timer = get_tree().create_timer(unhover_delay)
	_unhover_timer.timeout.connect(_on_unhover_timeout)

func _on_unhover_timeout() -> void:
	# Only reset if no card is currently hovered
	if _unhover_timer != null:
		_unhover_timer = null
		option_banner.set_option(0)

func _on_intro_finish():
	$introgroup1/AnimationPlayer.play("idle2")
	skippable = false
	Cursor.switch_mode("MENU")
	Cursor.enable()

# --- Quick Test (K key) ---

const _QUICK_TEST_FILE := "user://quick_test_room.txt"

func _quick_test() -> void:
	var code = _read_room_code()
	if code.is_empty():
		_quick_host()
	else:
		_quick_join(code)

func _read_room_code() -> String:
	if not FileAccess.file_exists(_QUICK_TEST_FILE):
		return ""
	var f = FileAccess.open(_QUICK_TEST_FILE, FileAccess.READ)
	if f == null:
		return ""
	var code = f.get_as_text().strip_edges()
	f.close()
	if code.length() != 6:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_QUICK_TEST_FILE))
		return ""
	return code

func _write_room_code(code: String) -> void:
	var f = FileAccess.open(_QUICK_TEST_FILE, FileAccess.WRITE)
	if f:
		f.store_string(code)
		f.close()

func _clear_room_code() -> void:
	if FileAccess.file_exists(_QUICK_TEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_QUICK_TEST_FILE))

func _quick_host() -> void:
	print("[QuickTest] Hosting...")
	GameData.set_mode(GameData.GameMode.HOST)

	Network.hosted.connect(_on_quick_hosted, CONNECT_ONE_SHOT)
	Network.game_started.connect(_on_quick_game_started, CONNECT_ONE_SHOT)
	Network.player_joined.connect(_on_quick_player_joined)

	Network.connected.connect(func():
		Network.host_room(TestConfig.DEFAULT_USERNAME + "1")
	, CONNECT_ONE_SHOT)
	Network.connect_to_server(TestConfig.SERVER_URL)

func _on_quick_hosted(room_code: String, _pid: int) -> void:
	print("[QuickTest] Hosted room: ", room_code)
	_write_room_code(room_code)
	Network.set_hero(TestConfig.DEFAULT_HERO)
	Network.set_settings({"map": TestConfig.DEFAULT_MAP})

func _on_quick_player_joined(_pid: int, _username: String) -> void:
	print("[QuickTest] Player joined, starting game...")
	Network.start_game()

func _quick_join(code: String) -> void:
	print("[QuickTest] Joining room: ", code)
	_clear_room_code()
	GameData.set_mode(GameData.GameMode.JOIN)

	Network.game_started.connect(_on_quick_game_started, CONNECT_ONE_SHOT)

	Network.connected.connect(func():
		Network.join_room(code, TestConfig.DEFAULT_USERNAME + "2")
	, CONNECT_ONE_SHOT)
	Network.joined_room.connect(func(_pid: int, _is_host: bool):
		Network.set_hero(TestConfig.DEFAULT_HERO)
	, CONNECT_ONE_SHOT)
	Network.connect_to_server(TestConfig.SERVER_URL)

func _on_quick_game_started(players: Array, settings: Dictionary) -> void:
	_clear_room_code()
	if Network.player_joined.is_connected(_on_quick_player_joined):
		Network.player_joined.disconnect(_on_quick_player_joined)
	GameData.set_online_game(players, settings)
	GameData.change_scene("res://scenes/game.tscn")
