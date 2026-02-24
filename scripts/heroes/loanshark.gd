class_name HeroLoanShark
extends Hero

var meleeDamage = 20 #maybe for a melee character, we'd have a higher base damage 
var meleeCooldown = 1 #one swing per second
var paymentPlanCooldown = 7
var paymentPlanAbilityCount = 2
var reapoCooldown = 8

func get_hero_name() -> String:
	return "LoanShark"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: shoot")

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ability1")

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ability2")

func _do_ultimate(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ultimate")
