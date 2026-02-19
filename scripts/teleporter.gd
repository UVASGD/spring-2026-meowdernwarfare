extends Area2D
@export var id: int
@export var target_id: int
@export var cycle_speed := 0.3

@onready var light: PointLight2D = $light

var hue := 0.0

func _ready() -> void:
	if light:
		hue = randf()

func _process(delta: float) -> void:
	if light:
		hue = fmod(hue + delta * cycle_speed, 1.0)
		light.color = Color.from_hsv(hue, 1.0, 1.0)
