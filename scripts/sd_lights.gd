extends DirectionalLight2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.instance.connect("sudden_death_received", _on_sudden_death)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_sudden_death():
	print("lights")
	$AnimationPlayer.play("pulse")
