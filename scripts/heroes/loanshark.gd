class_name HeroLoanShark
extends Hero

var meleeDamage = 20 #maybe for a melee character, we'd have a higher base damage 
var paymentPlanCooldown = 7
var paymentPlanAbilityCount = 2
var reapoCooldown = 8

@onready var loanshark_animation: AnimatedSprite2D = $Sprite
@onready var hurtbox_animation : AnimationPlayer = $AnimationPlayer
@onready var hurtbox = $hurtbox

func get_hero_name() -> String:
	return "LoanShark"

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: shoot")
	current_anim = "melee"
	loanshark_animation.play("melee")
	_capture_skill_anim()
	hurtbox.start_swing()
	hurtbox_animation.play("hurtbox")
	ammo += 1
	await loanshark_animation.animation_finished
	hurtbox.end_swing()
	print(current_anim)
	current_anim = "idle"
	

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ability1")
	current_anim = "reap"
	loanshark_animation.play("reap")
	_capture_skill_anim()
	await loanshark_animation.animation_finished
	print(current_anim)
	current_anim = "idle"

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ability2")

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ultimate")
