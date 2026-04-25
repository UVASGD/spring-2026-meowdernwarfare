extends Control

@onready var anim: AnimationPlayer = $AnimationPlayer

var _done := false

func _ready() -> void:
	if not GameData.is_first_load:
		_go_menu()
		return
	GameData.mark_intro_seen()
	if anim == null:
		_go_menu()
		return
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("intro")

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_accept"):
		_go_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_menu()
	elif event is InputEventKey and event.pressed:
		_go_menu()

func _on_anim_finished(name: StringName) -> void:
	if name == "intro":
		_go_menu()

func _go_menu() -> void:
	if _done:
		return
	_done = true
	GameData.change_scene("res://scenes/ui/main_menu.tscn")
