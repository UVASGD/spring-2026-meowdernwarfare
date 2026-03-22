extends AnimatedSprite2D

func _ready() -> void:
	# 1. Play the chomp
	play("default") 
	
	# 2. Random slight rotation so it doesn't look robotic 
	# if multiple chomps happen at once
	rotation = randf_range(-0.2, 0.2)
	
	# 3. Clean up when the animation ends
	animation_finished.connect(queue_free)
	get_tree().create_timer(.5).timeout.connect(queue_free)
