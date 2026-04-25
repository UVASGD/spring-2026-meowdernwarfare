extends Control


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		GameData.change_scene("res://scenes/ui/main_menu.tscn")
