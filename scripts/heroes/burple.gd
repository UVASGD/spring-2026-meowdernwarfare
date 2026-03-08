class_name HeroBurple
extends Hero

func get_hero_name() -> String:
	return "Burple"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Burple: shoot")

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Burple: ability1")

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Burple: ult")
