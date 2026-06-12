extends Node2D

signal finished

@export var damage: int = 200

var owner_player: Player = null
var _hit_ids := {}

func _set_owner(player: Player) -> void:
	owner_player = player

# Called by animation method track
func _finish() -> void:
	finished.emit()
	queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == owner_player:
		return
	if body is FIE and body.owner_player == owner_player:
		return
	# Damage each body once; the node frees itself via _finish() when the
	# animation ends. Freeing on first hit would cut the AOE short and leave
	# fie.ult_explode() awaiting a `finished` signal that never fires.
	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true
	if body is Player:
		body.take_damage(damage, owner_player)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
