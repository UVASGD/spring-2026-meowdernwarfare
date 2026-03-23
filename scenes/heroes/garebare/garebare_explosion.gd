extends Node2D
var owner_player:Player = null
signal finished
@export var damage:int = 200
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _set_owner(player:Player):
	owner_player = player
	return
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#called by animation track 
func _finish():
	finished.emit()
	queue_free()
	return


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == owner_player:
		return
	
	if body is Player:
		body.take_damage(damage, owner_player)
		queue_free()
	elif body is FIE and body.owner_player == owner_player:
		return
	elif body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	pass # Replace with function body.
