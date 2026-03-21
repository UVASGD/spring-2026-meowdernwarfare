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

func _do_ability1(aim_dir: Vector2, _aim_pos: Vector2) -> void:
	var dash_power = 1400.0 # This is the variable impacting how strong the dash feels
	var duration = 0.4 #This is the variable that manages how long the ability duration is (longer than a traditional dash)
	
	if is_multiplayer_authority() and player:
		player.is_dashing = true
		player.dash_dir = aim_dir.normalized()
		player.dash_timer = duration
		# Give it that "oomph" immediately
		player.velocity = player.dash_dir * dash_power 

	# Visuals & Animation
	loanshark_animation.play("reap")
	_capture_skill_anim()
	hurtbox.start_swing()

	# Ghosting (Local Only)
	if not DisplayServer.get_name() == "headless":
		_run_ghost_loop(duration)

	# Wait for the active "Strike" phase
	await get_tree().create_timer(duration).timeout
	
	# --- The "Smooth" Part ---
	hurtbox.end_swing()
	
	if is_multiplayer_authority() and player:
		# Don't set velocity to zero! 
		# Let Player.gd's friction take over naturally now that is_dashing is false
		player.is_dashing = false
	if is_multiplayer_authority() and player.camera:
	# Small directional shake in the direction of the dash
		var shake_tween = get_tree().create_tween()
		player.camera.offset = aim_dir.normalized() * 10
		shake_tween.tween_property(player.camera, "offset", Vector2.ZERO, 0.2)

func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ability2")

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	print("LoanShark: ultimate")

func _run_ghost_loop(duration: float) -> void: 
	var dash_time = dash_anim_duration
	while dash_time > 0:
		# Only spawn ghost if the character is actually moving
		if player and player.velocity.length() > 100:
			_spawn_ghost()
		
		await get_tree().create_timer(0.05).timeout
		dash_time -= 0.05

func _spawn_ghost() -> void:
	var ghost = Sprite2D.new()
	var frame_tex = loanshark_animation.sprite_frames.get_frame_texture(
		loanshark_animation.animation, 
		loanshark_animation.frame
	)
	
	ghost.texture = frame_tex
	ghost.global_position = loanshark_animation.global_position
	ghost.rotation = loanshark_animation.rotation
	ghost.scale = loanshark_animation.scale
	ghost.flip_h = loanshark_animation.flip_h
	ghost.modulate = Color(0.3, 0.6, 1.0, 0.6) # Cold Cash Blue
	ghost.z_index = -1 

	# Add to scene, not as a child of the player (so it stays behind)
	get_tree().current_scene.add_child(ghost)
	
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.finished.connect(ghost.queue_free)
