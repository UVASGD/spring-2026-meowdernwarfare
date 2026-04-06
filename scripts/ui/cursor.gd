extends CanvasLayer

var enabled = false
const MODE_MENU := "MENU"
const MODE_BATTLE := "BATTLE"
const MODE_GRENADE := "GRENADE"
const MODES: Array[String] = [MODE_MENU, MODE_BATTLE, MODE_GRENADE]

var mode: String = MODE_MENU

@onready var _menu_root: Node2D = $MENU
@onready var _battle_root: Node2D = $BATTLE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_menu_root.show()
	_battle_root.hide()

func switch_mode(new_mode: String) -> void:
	if new_mode not in MODES:
		printerr("[CURSOR] nonexistent cursor mode: ", new_mode)
		return
	if mode == new_mode:
		return
	_mode_root().hide()
	get_node(NodePath(new_mode)).show()
	mode = new_mode
	if enabled:
		get_click().hide()
		get_default().show()

func _mode_root() -> Node2D:
	return get_node(NodePath(mode)) as Node2D

func get_default() -> AnimatedSprite2D:
	return _mode_root().get_node("default") as AnimatedSprite2D

func get_click() -> Sprite2D:
	return _mode_root().get_node("click") as Sprite2D

func enable():
	enabled = true
	visible = true
	get_default().show()
	get_click().hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func disable():
	enabled = false
	get_click().hide()
	get_default().hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var clicked = event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT
	get_default().visible = !clicked
	get_click().visible = clicked

func _process(_delta: float) -> void:
	offset = get_viewport().get_mouse_position()
