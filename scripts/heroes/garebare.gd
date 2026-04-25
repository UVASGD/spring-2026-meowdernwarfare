class_name HeroGarebare
extends Hero

const SOUNDWAVE_SCENE := "res://scenes/heroes/garebare/soundwave.tscn"
const SONIC_BURST_SCENE := "res://scenes/heroes/garebare/sonic_burst.tscn"
const FIE_SCENE := "res://scenes/heroes/garebare/fie.tscn"
const GAREBARE_EXPLOSION = preload("res://scenes/heroes/garebare/garebare_explosion.tscn")

@export var pellet_count: int = 3
@export var spread_angle: float = 30.0
@export var stun_duration: float = 2.0
@export var fie_suppress_radius: float = 150.0
@export var fie_respawn_cd: float = 10.0
@export var ult_damage: float = 60.0
@export var ult_radius: float = 200.0
@export var fie_detonate_damage: float = 40.0

# FIE tracking: up to 2 slots
var fies: Array = [null, null]
var fie_cds: Array[float] = [0.0, 0.0]
var _fie_remote_op: bool = false
var _soundwave_scene: PackedScene = null
var _sonic_burst_scene: PackedScene = null
var _fie_scene: PackedScene = null

func _process(delta: float) -> void:
	super._process(delta)
	for i in range(fie_cds.size()):
		if fie_cds[i] > 0:
			fie_cds[i] = max(0.0, fie_cds[i] - delta)

func get_hero_name() -> String:
	return "Garebare"

func has_hero_ability2() -> bool:
	return true

func use_ability2_charge_row_ui() -> bool:
	return true

func get_ability2_ui_progress() -> float:
	var total := 0.0
	for i in range(fies.size()):
		total += get_ability2_charge_row_progress(i)
	return clamp(total / float(fies.size()), 0.0, 1.0)

func get_ability2_charge_row_progress(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= fies.size():
		return 1.0
	if fies[slot_index] != null and is_instance_valid(fies[slot_index]):
		return 0.0
	var cd := fie_cds[slot_index]
	if cd <= 0.0:
		return 1.0
	if fie_respawn_cd <= 0.0:
		return 1.0
	return clamp(1.0 - (cd / fie_respawn_cd), 0.0, 1.0)

func get_ability2_charge_count() -> int:
	var c := 0
	for i in range(fies.size()):
		if fies[i] == null or not is_instance_valid(fies[i]):
			if fie_cds[i] <= 0.0:
				c += 1
	return c

# --- SHOOT: shotgun soundwave spread ---

@warning_ignore("unused_parameter")
func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if _soundwave_scene == null:
		_soundwave_scene = load(SOUNDWAVE_SCENE) as PackedScene
	if _soundwave_scene == null:
		return
	var base_angle = aim_dir.angle()
	var half_spread = deg_to_rad(spread_angle / 2.0)
	for i in range(pellet_count):
		var t = float(i) / max(pellet_count - 1, 1)
		var angle = base_angle - half_spread + t * half_spread * 2.0
		var dir = Vector2(cos(angle), sin(angle))
		var bullet = _soundwave_scene.instantiate()
		bullet.direction = dir
		bullet.owner_player = player
		bullet.global_position = $bulletSpawnPoint.global_position
		bullet.rotation = angle
		get_tree().current_scene.add_child(bullet)

# --- ABILITY 1: sonic burst (stun projectile) ---

@warning_ignore("unused_parameter")
func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if _sonic_burst_scene == null:
		_sonic_burst_scene = load(SONIC_BURST_SCENE) as PackedScene
	if _sonic_burst_scene == null:
		return
	var burst = _sonic_burst_scene.instantiate()
	burst.direction = aim_dir
	burst.owner_player = player
	burst.stun_duration = stun_duration
	burst.global_position = player.global_position + aim_dir * 40
	burst.rotation = aim_dir.angle()
	get_tree().current_scene.add_child(burst)

# --- ABILITY 2: place FIE ---

func can_ability2() -> bool:
	if ability2_cd > 0 or _is_fie_suppressed():
		return false
	return _get_free_fie_slot() >= 0

@warning_ignore("unused_parameter")
func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var slot = _get_free_fie_slot()
	if slot < 0:
		return

	var place_pos = player.global_position + aim_dir * 60
	# Wall check: abort if placement would be inside a wall
	var space = player.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(player.global_position, place_pos, 2)
	var result = space.intersect_ray(query)
	if result:
		# Would collide with wall — refund cooldown
		ability2_cd = 0.0
		return

	var fie = _create_fie()
	if fie == null:
		ability2_cd = 0.0
		return
	fie.owner_player = player
	fie.suppress_radius = fie_suppress_radius
	fie.global_position = place_pos
	get_tree().current_scene.add_child(fie)
	fies[slot] = fie
	fie.destroyed.connect(_on_fie_destroyed.bind(slot, fie))

	# Broadcast FIE placement for network sync
	if GameManager.instance:
		GameManager.instance.send_fie_placed(player.player_id, slot, place_pos)

func _place_fie_remote(slot: int, pos: Vector2) -> void:
	if slot < 0 or slot >= fies.size():
		return
	_fie_remote_op = true
	var fie = _create_fie()
	if fie == null:
		_fie_remote_op = false
		return
	fie.owner_player = player
	fie.suppress_radius = fie_suppress_radius
	fie.global_position = pos
	get_tree().current_scene.add_child(fie)
	fies[slot] = fie
	fie.destroyed.connect(_on_fie_destroyed.bind(slot, fie))
	_fie_remote_op = false

func _get_free_fie_slot() -> int:
	for i in range(fies.size()):
		if (fies[i] == null or not is_instance_valid(fies[i])) and fie_cds[i] <= 0:
			return i
	return -1

func _on_fie_destroyed(slot: int, fie: Node2D) -> void:
	fies[slot] = null
	fie_cds[slot] = fie_respawn_cd
	if fie and is_instance_valid(fie):
		SfxBus.play_world(&"hero.garebare.fie_destroy", fie.global_position)
	if not _fie_remote_op and GameManager.instance:
		GameManager.instance.send_fie_destroyed(player.player_id, slot)

func _create_fie() -> StaticBody2D:
	if _fie_scene == null:
		_fie_scene = load(FIE_SCENE) as PackedScene
	if _fie_scene == null:
		return null
	return _fie_scene.instantiate()

# --- ULT: amplitude AOE + detonate FIEs ---

@warning_ignore("unused_parameter")
func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var exp = GAREBARE_EXPLOSION.instantiate()
	exp._set_owner(self.player)
	add_child(exp)


	# Detonate all existing FIEs (damage in their areas, then destroy)
	for i in range(fies.size()):
		if fies[i] != null and is_instance_valid(fies[i]):
			fies[i].ult_explode()
			fies[i] = null
			fie_cds[i] = 0.0  # Refresh cooldowns after ult
