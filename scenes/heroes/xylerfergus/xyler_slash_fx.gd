extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	z_index = 9
	sprite.play("slash")
	sprite.animation_finished.connect(queue_free)
