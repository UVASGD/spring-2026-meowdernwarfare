extends AnimatedSprite2D

@export var sfx_id: StringName = &"fx.explosion"
@export var sfx_db_offset: float = 0.0
@export var sfx_enabled: bool = true

func _ready() -> void:
	if sfx_enabled and sfx_id != &"":
		var sfx = get_node_or_null("/root/Sfx")
		if sfx and sfx.has_method("play_world_db"):
			sfx.call("play_world_db", sfx_id, global_position, sfx_db_offset)
	$AnimationPlayer.animation_finished.connect(_on_anim_finished)

func _on_anim_finished(_anim: StringName) -> void:
	queue_free()
