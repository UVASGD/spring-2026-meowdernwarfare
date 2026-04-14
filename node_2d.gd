extends Node2D
@onready var colliders: Array[Player]
@export var dmg: int
@export var tick_rate_ms: float

@onready var time = 0

func _process(delta: float) -> void:
	time += delta
	if time >= tick_rate_ms:
		time = 0
		hit()
	
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		if body not in colliders:
			colliders.append(body)
		
	pass # Replace with function body.

func hit():
	for player in colliders:
		player.take_damage(dmg)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player and body in colliders:
		colliders.erase(body)
	pass # Replace with function body.
