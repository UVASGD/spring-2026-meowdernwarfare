class_name HeroXyler
extends Hero

func get_hero_name() -> String:
	return "Xyler"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Xyler: shoot")

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Xyler: ability1")

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Xyler: ult")
