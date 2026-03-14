extends Node2D

@export var damage : int
var owner_player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	owner_player = get_parent().get_parent()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == owner_player:
		return
	
	if body is Player:
		body.take_damage(damage, owner_player)
		queue_free()
	elif body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
