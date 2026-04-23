class_name HeroLoanShark
extends Hero

const MarkProjectileScene = preload("res://scenes/heroes/loanshark/mark_projectile.tscn")
const FeedingFrenzyScene = preload("res://scenes/heroes/loanshark/feeding_frenzy.tscn")

const ABILITY2_CHARGE_MAX := 2

@export var mark_duration: float = 10.0
@export var feeding_frenzy_radius: float = 600.0
@export var feeding_frenzy_pulse_count: int = 3
@export var feeding_frenzy_pulse_interval: float = 3.0
@export var mark_projectile_speed: float = 2200.0
@export var mark_projectile_damage: float = 8.0
@export var mark_projectile_explosion_radius: float = 140.0
@export var ability2_charge_cooldown: float = 6.0

## Contract projectile charges (max 2, independent recharge per slot).
var ability2_charges: int = ABILITY2_CHARGE_MAX
var _ability2_slot_cds: Array[float] = [0.0, 0.0]

@onready var loanshark_animation: AnimatedSprite2D = $Sprite
@onready var hurtbox_animation : AnimationPlayer = $AnimationPlayer
@onready var hurtbox: HeroHurtbox = $hurtbox

func get_hero_name() -> String:
	return "LoanShark"

func allows_movement_dash() -> bool:
	return false

func uses_gun_ammo() -> bool:
	return false

func can_shoot() -> bool:
	# shoot_actionable is false: cannot fire again until melee anim lock clears (blocks held-click spam).
	return shoot_cd <= 0 and reload_cd <= 0 and not is_dead and not _is_action_blocked()

func reload() -> void:
	pass

func _ready() -> void:
	super._ready()
	shoot_actionable = false
	ability2_charges = ABILITY2_CHARGE_MAX
	_ability2_slot_cds = [0.0, 0.0]
	ability2_cd = 0.0
	ammo = mag_size
	reload_cd = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	_update_ability2_charge_timers(delta)

func _update_ability2_charge_timers(delta: float) -> void:
	for i in range(ABILITY2_CHARGE_MAX):
		if _ability2_slot_cds[i] <= 0:
			continue
		_ability2_slot_cds[i] = max(0.0, _ability2_slot_cds[i] - delta)
		if _ability2_slot_cds[i] <= 0:
			ability2_charges = mini(ABILITY2_CHARGE_MAX, ability2_charges + 1)

func can_ability2() -> bool:
	return ability2_charges > 0 and not _is_fie_suppressed() and not _is_action_blocked()

func ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_ability2() or is_dead:
		return
	_spend_ability2_charge()
	ability2_anim_timer = ability2_anim_duration
	_begin_skill("ability2")
	_play_action_anim("ability2")
	_capture_skill_anim()
	_do_ability2(aim_dir, aim_pos)

func _spend_ability2_charge() -> void:
	ability2_charges = maxi(0, ability2_charges - 1)
	for i in range(ABILITY2_CHARGE_MAX):
		if _ability2_slot_cds[i] <= 0:
			_ability2_slot_cds[i] = ability2_charge_cooldown
			break

## Per-slot recharge fill for UI: 1.0 = ready, 0.0 = just spent.
func get_ability2_charge_slot_recharge_progress(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= ABILITY2_CHARGE_MAX:
		return 1.0
	var cd := _ability2_slot_cds[slot_index]
	if cd <= 0:
		return 1.0
	return 1.0 - (cd / ability2_charge_cooldown)

## Full shoot override: base Hero.shoot() plays "shoot" anim and locks the wrong animation; melee must lock "melee".
func shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_shoot():
		return
	# Do not set shoot_cd here: default shoot_cooldown is shorter than melee length, so cooldown could
	# expire mid-swing and allow another shoot() while hurtbox is still active. Cooldown starts after swing ends.
	_begin_skill("shoot")
	current_anim = "melee"
	loanshark_animation.play("melee")
	_capture_skill_anim()
	SfxBus.play_world(SfxEvent.WEAPON_SHOOT, player.global_position if player else global_position)
	SfxBus.play_world(&"player.melee_swipe", player.global_position if player else global_position)
	SfxBus.play_world(SfxEvent.LOANSHARK_MELEE, player.global_position if player else global_position)
	_do_shoot(aim_dir, aim_pos)

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	# Hurtbox timing is driven only by code. Do not play hurtbox AnimationPlayer here: its track
	# sets monitoring=false at t=0 and overrides start_swing(), killing hit detection.
	hurtbox.start_swing(HeroHurtbox.SwingMode.MELEE)
	await loanshark_animation.animation_finished
	hurtbox.end_swing()
	shoot_cd = shoot_cooldown
	shot.emit()

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
	hurtbox.start_swing(HeroHurtbox.SwingMode.DASH)

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

func _do_ability2(aim_dir: Vector2, _aim_pos: Vector2) -> void:
	var dir := aim_dir.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	var bolt = MarkProjectileScene.instantiate()
	bolt.direction = dir
	bolt.owner_player = player
	bolt.speed = mark_projectile_speed
	bolt.damage = mark_projectile_damage
	bolt.mark_duration = mark_duration
	bolt.explosion_radius = mark_projectile_explosion_radius
	bolt.global_position = player.global_position + dir * 48.0
	bolt.rotation = dir.angle()
	get_tree().current_scene.add_child(bolt)

func _do_ult(aim_dir: Vector2, _aim_pos: Vector2) -> void:
	var frenzy := FeedingFrenzyScene.instantiate()
	frenzy.owner_player = player
	frenzy.effect_radius = feeding_frenzy_radius
	frenzy.mark_duration = mark_duration
	frenzy.pulse_count = feeding_frenzy_pulse_count
	frenzy.pulse_interval = feeding_frenzy_pulse_interval
	player.add_child(frenzy)

func _run_ghost_loop(duration: float) -> void:
	var t := duration
	while t > 0:
		if player and player.velocity.length() > 100:
			_spawn_ghost()
		await get_tree().create_timer(0.05).timeout
		t -= 0.05

func _spawn_ghost() -> void:
	spawn_trail_ghost(loanshark_animation.global_position, loanshark_animation.rotation)

## Cold Cash blue trail for dash (uses Loan Shark sprite frames).
func spawn_trail_ghost(pos: Vector2, rot: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if loanshark_animation == null or loanshark_animation.sprite_frames == null:
		return
	var ghost := Sprite2D.new()
	var frame_tex := loanshark_animation.sprite_frames.get_frame_texture(
		loanshark_animation.animation,
		loanshark_animation.frame
	)
	ghost.texture = frame_tex
	ghost.global_position = pos
	ghost.rotation = rot
	ghost.scale = loanshark_animation.scale
	ghost.flip_h = loanshark_animation.flip_h
	ghost.modulate = Color(0.3, 0.6, 1.0, 0.6)
	ghost.z_index = -1
	get_tree().current_scene.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.finished.connect(ghost.queue_free)
