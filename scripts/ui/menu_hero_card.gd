extends Node2D

signal card_hovered(action: CardAction)
signal card_unhovered()

enum CardAction { NONE, HOST, JOIN, PRACTICE }
const SfxEvent = preload("res://scripts/audio/sfx_event.gd")
const SfxBus = preload("res://scripts/audio/sfx_bus.gd")

@export var next_scene_path: String
@export var card_action: CardAction = CardAction.NONE

var hovered = false

func _ready() -> void:
	pass

func _on_hover_enter() -> void:
	hovered = true
	SfxBus.play_ui(SfxEvent.UI_HOVER)
	card_hovered.emit(card_action)
	if $char2.texture:
		$char2.show()
		$char.hide()
	$AnimationPlayer.play("hover")

func _on_hover_exit() -> void:
	hovered = false
	card_unhovered.emit()
	if $char2.texture:
		$char.show()
		$char2.hide()
	$AnimationPlayer.play("unhover")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hovered:
			_activate()

func _activate() -> void:
	SfxBus.play_ui(SfxEvent.UI_CLICK)
	# Set game mode based on card action
	match card_action:
		CardAction.HOST:
			GameData.set_mode(GameData.GameMode.HOST)
		CardAction.JOIN:
			GameData.set_mode(GameData.GameMode.JOIN)
		CardAction.PRACTICE:
			GameData.set_mode(GameData.GameMode.PRACTICE)
	
	if next_scene_path:
		GameData.change_scene(next_scene_path)
