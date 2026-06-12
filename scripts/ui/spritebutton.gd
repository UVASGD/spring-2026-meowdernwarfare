class_name SpriteButton extends Node2D

signal pressed()

const IDLE_MOD := Color(1, 1, 1, 1.0)
const HOVER_MOD := Color(0.55, 0.55, 0.55, 1.0)
const SfxEvent = preload("res://scripts/audio/sfx_event.gd")
const SfxBus = preload("res://scripts/audio/sfx_bus.gd")

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
	_fix_state_textures()
	if start_disabled:
		disable()
	else:
		_show_off_state()

func _on_area_2d_mouse_entered() -> void:
	if is_disabled:
		return
	hovered = true
	SfxBus.play_ui(SfxEvent.UI_HOVER)
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
	if not hovered or is_disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_confirm()

func _confirm() -> void:
	if toggleable:
		is_on = not is_on
	if is_on:
		_show_on_state()
	else:
		_show_off_state()
	SfxBus.play_ui(SfxEvent.UI_CLICK)
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
		on_sprite.modulate = Color.WHITE

func _show_off_state() -> void:
	_hide_all()
	if off_sprite:
		off_sprite.visible = true
		off_sprite.modulate = IDLE_MOD

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
		if off_sprite and off_sprite.visible:
			off_sprite.modulate = HOVER_MOD

func _remove_hover() -> void:
	if custom_hover:
		if hovered_sprite:
			hovered_sprite.visible = false

func _fix_state_textures() -> void:
	var ref_tex: Texture2D = null
	if off_sprite and not _is_missing_tex(off_sprite):
		ref_tex = off_sprite.texture
	elif on_sprite and not _is_missing_tex(on_sprite):
		ref_tex = on_sprite.texture
	if ref_tex == null:
		return
	if on_sprite and _is_missing_tex(on_sprite):
		on_sprite.texture = ref_tex
	if off_sprite and _is_missing_tex(off_sprite):
		off_sprite.texture = ref_tex
	if hovered_sprite and _is_missing_tex(hovered_sprite):
		hovered_sprite.texture = ref_tex
	if disabled_sprite and _is_missing_tex(disabled_sprite):
		disabled_sprite.texture = ref_tex

func _is_missing_tex(s: Sprite2D) -> bool:
	if s == null or s.texture == null:
		return true
	return s.texture is PlaceholderTexture2D
