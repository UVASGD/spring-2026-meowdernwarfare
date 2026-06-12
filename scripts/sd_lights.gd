extends DirectionalLight2D

func _ready() -> void:
	if GameManager.instance:
		GameManager.instance.sudden_death_received.connect(_on_sudden_death)

func _on_sudden_death() -> void:
	$AnimationPlayer.play("pulse")
