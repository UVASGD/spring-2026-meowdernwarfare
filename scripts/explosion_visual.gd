extends AnimatedSprite2D

func _ready() -> void:
	$AnimationPlayer.animation_finished.connect(_on_anim_finished)

func _on_anim_finished(_anim: StringName) -> void:
	queue_free()
