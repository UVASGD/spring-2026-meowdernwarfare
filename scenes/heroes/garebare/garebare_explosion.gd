extends Node2D
var owner_player:Player = null
signal finished
@export var damage:int = 200
@export var sfx_db_offset: float = 0.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx and sfx.has_method("play_world_db"):
		sfx.call("play_world_db", &"fx.explosion", global_position, sfx_db_offset)
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
