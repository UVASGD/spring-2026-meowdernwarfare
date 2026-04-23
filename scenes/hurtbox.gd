class_name HeroHurtbox
extends Node2D

enum SwingMode { MELEE, DASH }

@export var damage : int
var owner_player
var hit_map := {}
var _swing_mode: SwingMode = SwingMode.MELEE
@onready var area: Area2D = $Area2D
const CHOMP_EFFECT = preload("res://scenes/heroes/loanshark/chomp_effect.tscn")

func _ready() -> void:
	if owner_player == null:
		owner_player = get_parent().get_parent()
	set_physics_process(false)

func start_swing(mode: SwingMode = SwingMode.MELEE) -> void:
	_swing_mode = mode
	hit_map.clear()
	area.monitoring = true
	_hit_overlaps()
	set_physics_process(true)

func end_swing() -> void:
	set_physics_process(false)
	area.monitoring = false
	hit_map.clear()

func _physics_process(_delta: float) -> void:
	if area.monitoring:
		_hit_overlaps()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if area.monitoring: 
		_try_hit(body)

func _hit_overlaps() -> void:
	if not area.monitoring:
		return 
	for body in area.get_overlapping_bodies():
		_try_hit(body)

func _spawn_chomp_visual(victim: Node2D) -> void:
	var chomp = CHOMP_EFFECT.instantiate()
	# Add it as a child of the victim so it follows them
	victim.add_child(chomp)
	chomp.global_position = victim.global_position
	# Ensure it's rendered on top
	chomp.z_index = 5
	
func _try_hit(body: Node2D) -> void:
	if body == owner_player:
		return

	var body_id := body.get_instance_id()
	if hit_map.has(body_id):
		return
	hit_map[body_id] = true

	if body is Player:
		var p := body as Player
		var was_marked := p.is_marked
		var dealt := p.take_damage(damage, owner_player)
		if not dealt:
			return
		match _swing_mode:
			SwingMode.DASH:
				_apply_dash_hit_fx(p, was_marked)
				var gm := GameManager.instance
				if gm and owner_player:
					gm.broadcast_loan_dash_hit(owner_player.player_id, p.player_id, was_marked)
			SwingMode.MELEE:
				pass
	elif body.has_method("take_damage"):
		body.take_damage(damage)

func _apply_dash_hit_fx(victim: Player, was_marked: bool) -> void:
	if was_marked:
		if owner_player and owner_player.hero:
			owner_player.hero.refresh_ability1_cooldown()
		victim.clear_mark_effect()
	_spawn_chomp_visual(victim)
