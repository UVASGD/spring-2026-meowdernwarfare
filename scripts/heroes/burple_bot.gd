class_name BurpleBot extends Hero

const BulletScene = preload("res://scenes/heroes/burplebot_laser.tscn")

func _ready() -> void:
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)

func get_hero_name() -> String:
	return "BurpleBot"

@warning_ignore("unused_parameter")
func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	bullet.global_position = player.global_position + aim_dir * 30
	bullet.rotation = aim_dir.angle()
	
	get_tree().current_scene.add_child(bullet)
