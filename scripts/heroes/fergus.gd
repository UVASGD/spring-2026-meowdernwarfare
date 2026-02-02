class_name HeroFergus
extends Hero

func get_hero_name() -> String:
	return "Fergus"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Fergus: shoot")

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Fergus: ability1")

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Fergus: ability2")
