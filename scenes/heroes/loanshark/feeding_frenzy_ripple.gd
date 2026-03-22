extends Node2D

## Expanding water-style ring from the Loan Shark; scales up from the center then fades.

@export var expand_duration: float = 0.9

var max_radius: float = 520.0

func _ready() -> void:
	z_index = 6
	modulate = Color(1, 1, 1, 0.92)
	scale = Vector2(0.04, 0.04)
	queue_redraw()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), expand_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, expand_duration)
	tw.finished.connect(queue_free)

func _draw() -> void:
	# Concentric rings; whole node scales from center + modulate fades for water-ripple read.
	var c1 := Color(0.32, 0.68, 0.96, 0.55)
	var c2 := Color(0.48, 0.82, 1.0, 0.42)
	var c3 := Color(0.22, 0.55, 0.88, 0.32)
	draw_arc(Vector2.ZERO, max_radius * 0.98, 0, TAU, 112, c1, 3.2, true)
	draw_arc(Vector2.ZERO, max_radius * 0.72, 0, TAU, 96, c2, 2.4, true)
	draw_arc(Vector2.ZERO, max_radius * 0.48, 0, TAU, 80, c3, 1.8, true)
