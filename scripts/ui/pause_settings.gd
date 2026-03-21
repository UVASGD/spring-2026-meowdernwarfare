extends Control

signal back_pressed

@onready var back_btn: Button = $VBox/BackBtn

func _ready() -> void:
	back_btn.pressed.connect(func(): back_pressed.emit())
