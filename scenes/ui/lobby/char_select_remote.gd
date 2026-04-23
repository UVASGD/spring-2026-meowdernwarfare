extends Node2D

signal hero_selected(hero_name: String)
signal hero_hovered(hero_name: String)
signal ready_toggled(is_ready: bool)
signal leave_requested

const SfxEvent = preload("res://scripts/audio/sfx_event.gd")
const SfxBus = preload("res://scripts/audio/sfx_bus.gd")

@onready var char_buttons = $charButtons
@onready var ready_btn = $controlbuttons/readyUp
@onready var leave_btn = $controlbuttons/Leave

var current_hero: String = ""
var hovered_hero: String = ""
var is_ready := false

func _on_char_pressed(str_name: String) -> void:
	if is_ready:
		return
	if current_hero == str_name:
		current_hero = ""
		_sync_char_btns("")
		hero_selected.emit("")
	else:
		current_hero = str_name
		_sync_char_btns(str_name)
		hero_selected.emit(str_name)

func _on_char_hovered(str_name: String) -> void:
	hovered_hero = str_name
	if current_hero.is_empty():
		hero_hovered.emit(str_name)

func _on_char_unhovered() -> void:
	hovered_hero = ""

func _on_ready_up_pressed() -> void:
	if ready_btn.is_on and current_hero.is_empty():
		ready_btn.set_off()
		return
	is_ready = ready_btn.is_on
	SfxBus.play_ui(SfxEvent.UI_READY_ON if is_ready else SfxEvent.UI_READY_OFF)
	ready_toggled.emit(is_ready)
	_set_chars_interactive(not is_ready)

func _on_leave_pressed() -> void:
	SfxBus.play_ui(SfxEvent.UI_BACK)
	leave_requested.emit()

func reset() -> void:
	current_hero = ""
	hovered_hero = ""
	is_ready = false
	ready_btn.set_off()
	_sync_char_btns("")
	_set_chars_interactive(true)

func _set_chars_interactive(enabled: bool) -> void:
	for btn in char_buttons.get_children():
		if enabled:
			btn.enable()
		else:
			btn.disable()

func _sync_char_btns(hero_name: String) -> void:
	for btn in char_buttons.get_children():
		if not btn is CharSelectSpriteButton:
			continue
		if hero_name.is_empty():
			btn.set_off()
		elif btn.charName == hero_name:
			btn.set_on()
		else:
			btn.set_off()
