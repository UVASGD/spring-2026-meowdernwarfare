extends AnimatedSprite2D

@export var sfx_id: StringName = &"fx.explosion"
@export var sfx_db_offset: float = 0.0
@export var sfx_enabled: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if sfx_enabled and sfx_id != &"":
		var sfx = get_node_or_null("/root/Sfx")
		if sfx and sfx.has_method("play_world_db"):
			sfx.call("play_world_db", sfx_id, global_position, sfx_db_offset)
	$AnimationPlayer.connect("animation_finished", die)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func die(idk):
	queue_free()
	return
