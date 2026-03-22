extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	z_index = 8
	sprite.scale = Vector2(0.15, 0.15)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(0.42, 0.42), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.38).set_delay(0.12)
	tw.finished.connect(queue_free)
