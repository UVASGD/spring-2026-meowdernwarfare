extends CanvasLayer

var enabled = false
var clicked = false
@onready var default: AnimatedSprite2D = $default
@onready var click: Sprite2D = $click

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func enable():
	enabled = true
	visible = true
	default.show()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	print("enabled cursor")

func disable():
	enabled = false
	click.hide()
	default.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var clicked = event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT
	default.visible = !clicked
	click.visible = clicked
	return

func _process(delta: float) -> void:
	offset = get_viewport().get_mouse_position()
	#offset = get_global_mouse_position()
	return
