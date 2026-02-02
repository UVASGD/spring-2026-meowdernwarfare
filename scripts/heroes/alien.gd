class_name HeroAlien
extends Hero

func get_hero_name() -> String:
	return "Alien"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if player.input is not DummyInput:
		print("Alien: shoot")

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Alien: ability1")

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("Alien: ability2")
