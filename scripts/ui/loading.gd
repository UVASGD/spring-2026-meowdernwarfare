extends Control

@onready var status_label: Label = $Center/Status

var _dots_time: float = 0.0
var _base_text: String = "loading"
var _done: bool = false

func _ready() -> void:
	if GameData.startup_step.is_connected(_on_startup_step) == false:
		GameData.startup_step.connect(_on_startup_step)
	call_deferred("_boot")

func _process(delta: float) -> void:
	_dots_time += delta
	var dots := int(floor(_dots_time * 2.0)) % 4
	status_label.text = "%s%s" % [_base_text, ".".repeat(dots)]

func _boot() -> void:
	await GameData.ensure_startup_warmed()
	if _done:
		return
	_done = true
	var next := "res://scenes/ui/main_menu.tscn"
	if GameData.is_first_load:
		next = "res://scenes/ui/intro.tscn"
	GameData.change_scene(next)

func _on_startup_step(step: String) -> void:
	_base_text = GameData.ui_lower(step)
