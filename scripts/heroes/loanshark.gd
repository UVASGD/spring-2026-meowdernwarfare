class_name HeroLoanShark
extends Hero

func get_hero_name() -> String:
	return "LoanShark"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: shoot")

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ability1")

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ability2")
