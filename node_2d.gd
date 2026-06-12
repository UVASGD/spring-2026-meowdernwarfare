extends Node2D
var colliders: Array[Player] = []
@export var dmg: float = 8.0
@export var tick_rate_ms: float = 0.5

var time := 0.0

func _process(delta: float) -> void:
	time += delta
	if time >= tick_rate_ms:
		time = 0
		hit()
	
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		if body not in colliders:
			colliders.append(body)

func hit():
	var gm = GameManager.instance
	if gm and not gm.is_host():
		return
	for player in colliders:
		if is_instance_valid(player):
			if player.has_method("take_acid_damage"):
				player.take_acid_damage(dmg)
			else:
				player.take_damage(dmg)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player and body in colliders:
		colliders.erase(body)
