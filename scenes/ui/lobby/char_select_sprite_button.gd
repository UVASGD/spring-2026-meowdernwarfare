class_name CharSelectSpriteButton extends "res://scripts/ui/spritebutton.gd"

signal char_pressed(str_name:String)
signal char_hovered(str_name:String)
signal char_unhovered()
@export var charName:String = ""

func _confirm() -> void:
	super()
	char_pressed.emit(charName)

func _apply_hover():
	super()
	char_hovered.emit(charName)
	
	return

func _remove_hover():
	super()
	char_unhovered.emit()
	return
