class_name SpriteButton extends Node2D

signal pressed()

@export var toggleable := false
@export var start_disabled := false
@export var custom_hover := false

@onready var off_sprite: Sprite2D = $off
@onready var hovered_sprite: Sprite2D = $hovered
@onready var on_sprite: Sprite2D = $on
@onready var disabled_sprite: Sprite2D = $disabled

var hovered := false
var is_disabled := false
var is_on := false

func _ready() -> void:
	print("[SpriteButton] _ready: ", name, " area=", $Area2D, " shape=", $Area2D/CollisionShape2D.shape if $Area2D/CollisionShape2D else "null")
	if start_disabled:
		disable()
	else:
		_show_off_state()

func _on_area_2d_mouse_entered() -> void:
	print("[SpriteButton] mouse_entered: ", name)
	if is_disabled:
		return
	hovered = true
	if toggleable and is_on:
		return
	_apply_hover()

func _on_area_2d_mouse_exited() -> void:
	hovered = false
	if is_disabled:
		return
	_remove_hover()
	if is_on:
		_show_on_state()
	else:
		_show_off_state()

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	print("[SpriteButton] input_event: ", name, " type=", event.get_class(), " hovered=", hovered, " disabled=", is_disabled)
	if not hovered or is_disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_confirm()

func _confirm() -> void:
	print("[SpriteButton] _confirm: ", name)
	if toggleable:
		is_on = not is_on
	if is_on:
		_show_on_state()
	else:
		_show_off_state()
	pressed.emit()

func enable() -> void:
	is_disabled = false
	if is_on:
		_show_on_state()
	else:
		_show_off_state()

func disable() -> void:
	is_disabled = true
	hovered = false
	_hide_all()
	if disabled_sprite:
		disabled_sprite.visible = true

func set_on() -> void:
	is_on = true
	_show_on_state()

func set_off() -> void:
	is_on = false
	_show_off_state()

func _show_on_state() -> void:
	_hide_all()
	if on_sprite:
		on_sprite.visible = true

func _show_off_state() -> void:
	_hide_all()
	if off_sprite:
		off_sprite.visible = true

func _hide_all() -> void:
	_remove_hover()
	for s in _get_visuals():
		if s:
			s.visible = false

func _get_visuals() -> Array:
	return [off_sprite, hovered_sprite, on_sprite, disabled_sprite]

func _apply_hover() -> void:
	if custom_hover:
		_hide_all()
		if hovered_sprite:
			hovered_sprite.visible = true
	else:
		if off_sprite:
			off_sprite.modulate = Color(0.7, 0.7, 0.7)

func _remove_hover() -> void:
	if custom_hover:
		hovered_sprite.visible = false
	else:
		if off_sprite:
			off_sprite.modulate = Color.WHITE
