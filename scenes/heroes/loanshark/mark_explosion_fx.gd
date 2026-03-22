extends Node2D

@export var ring_radius: float = 120.0
@export var duration: float = 0.22

func _ready() -> void:
	z_index = 6
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.finished.connect(queue_free)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, ring_radius, Color(1, 1, 1, 0.22))
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 72, Color(0.9, 0.95, 1.0, 0.42), 2.0, true)
