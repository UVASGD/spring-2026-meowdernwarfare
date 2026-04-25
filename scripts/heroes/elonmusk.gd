class_name HeroElongatedMuskrat
extends Hero

const FlameScene = preload("res://scenes/heroes/elonmusk/muskrat_flame.tscn")

@export_group("Shoot")
@export var flame_damage: float = 5.0
@export var flame_speed: float = 330.0
@export var flame_life: float = 1.25
@export var flame_spread_deg: float = 5.0

@export_group("Crop Magnet")
@export var magnet_range: float = Player.INTERACT_RANGE
@export var magnet_window: float = 5.0

@export_group("Cybertruck Ult")
@export var ult_range: float = 520.0
@export var ult_zone_radius: float = 420.0
@export var ult_duration: float = 10.0
@export var ult_tp_cd: float = 0.5
@export var ult_line_damage: float = 22.0
@export var ult_line_life: float = 1.0
@export var ult_explosion_damage: float = 40.0

var _magnet_left := 0.0
var _ult_seq := 0
var _shot_seq: int = 0
var _spread_rng := RandomNumberGenerator.new()

@onready var _magnet_ring: Node2D = $MagnetRing

func _ready() -> void:
	_setup_placeholder_frames()
	super._ready()
	_refresh_viz()

func _process(delta: float) -> void:
	super._process(delta)
	if _magnet_left > 0.0:
		_magnet_left = maxf(0.0, _magnet_left - delta)
		if _is_local_owner():
			if _try_steal_held_crop():
				_magnet_left = 0.0
			elif _player_wants_aim_steal():
				if _try_steal_planted_crop():
					_magnet_left = 0.0
	_refresh_viz()

func get_hero_name() -> String:
	return "ElonMusk"

func uses_ability1_targeting() -> bool:
	return false

func uses_ult_targeting() -> bool:
	return false

func get_ult_range() -> float:
	return ult_range

func can_shoot() -> bool:
	if _is_ult_active_local():
		return false
	return super.can_shoot()

func _do_shoot(aim_dir: Vector2, _aim_pos: Vector2) -> void:
	_shot_seq += 1
	var pid = player.player_id if player else 0
	# Deterministic seed: every peer computes the same spread for this shot.
	_spread_rng.seed = (pid * 1_000_003) ^ _shot_seq
	var spread := deg_to_rad(_spread_rng.randf_range(-flame_spread_deg, flame_spread_deg))
	var b = FlameScene.instantiate()
	b.owner_player = player
	b.damage = flame_damage
	b.speed = flame_speed
	b.life = flame_life
	b.dir = aim_dir.rotated(spread).normalized()
	b.global_position = $Marker2D.global_position + aim_dir * 10.0
	b.rotation = b.dir.angle()
	get_tree().current_scene.add_child(b)

func _do_ability1(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
	_magnet_left = magnet_window
	_refresh_viz()

func _do_ult(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
	_start_ult_after_anim()

func _start_ult_after_anim() -> void:
	if not _is_local_owner():
		return
	await get_tree().create_timer(maxf(ult_anim_duration, 0.0)).timeout
	if player == null or not is_instance_valid(player) or is_dead:
		return
	var gm := GameManager.instance
	if gm == null:
		return
	_ult_seq += 1
	var center := player.global_position
	var uid := "%s:%s" % [player.player_id, _ult_seq]
	gm.cast_muskrat_ult(player.player_id, center, uid, _ult_pack())

func _is_local_owner() -> bool:
	var gm := GameManager.instance
	if gm == null or gm.is_local():
		return true
	return player and player.player_id == gm.local_player_id

func _is_ult_active_local() -> bool:
	var gm := GameManager.instance
	if gm == null or player == null:
		return false
	return gm.has_muskrat_ult_for_owner(player.player_id)

func _refresh_viz() -> void:
	if _magnet_ring:
		_magnet_ring.visible = _magnet_left > 0.0
		_magnet_ring.scale = Vector2.ONE * (magnet_range / 64.0)
		_magnet_ring.modulate.a = 0.15 + 0.18 * clamp(_magnet_left / maxf(magnet_window, 0.001), 0.0, 1.0)

func _player_wants_aim_steal() -> bool:
	return player and player.input and player.input.shoot_just

func _try_steal_held_crop() -> bool:
	if player == null or not player.can_receive_held_crop():
		return false
	for node in get_tree().get_nodes_in_group("players"):
		if not (node is Player):
			continue
		var victim := node as Player
		if victim == player:
			continue
		if victim.global_position.distance_to(player.global_position) > magnet_range:
			continue
		var d: Dictionary = victim.get_any_held_crop_data()
		if d.is_empty():
			continue
		var gm := GameManager.instance
		if gm:
			gm.request_muskrat_held_steal(player.player_id, victim.player_id, d.get("type", ""), int(d.get("stage", 1)))
			return true
	return false

func _try_steal_planted_crop() -> bool:
	if player == null or not player.can_receive_held_crop():
		return false
	var aim: Vector2 = player.get_aim_position()
	for f in get_tree().get_nodes_in_group("farms"):
		var tiles := _plantable_tiles(f)
		var tile := _tile_at_pos(tiles, aim)
		if tile == null or tile.planted_crop == null:
			continue
		if tile.global_position.distance_to(player.global_position) > magnet_range:
			continue
		var idx := tiles.find(tile)
		var crop: Crop = f.remove_crop(tile.planted_crop)
		if crop == null:
			continue
		var victim := f.get("_owner") as Player
		if victim:
			victim.crop_count -= 1
		player.pickup_world_crop(crop)
		var gm := GameManager.instance
		if gm and not gm.is_local() and victim:
			gm.send_crop_uproot(victim.player_id, idx, crop.get_type_id(), crop.stage)
		return true
	return false

func _plantable_tiles(farm: Node) -> Array:
	var out: Array = []
	var tm = farm.get_node_or_null("TileMapLayer")
	if tm == null:
		return out
	for c in tm.get_children():
		if c.has_method("plant"):
			out.append(c)
	return out

func _tile_at_pos(tiles: Array, pos: Vector2) -> Node:
	for t in tiles:
		if t.global_position.distance_to(pos) <= Player.TILE_HALF:
			return t
	return null

func _clamp_range(target: Vector2, max_range: float) -> Vector2:
	var off := target - player.global_position
	if off.length() <= max_range:
		return target
	return player.global_position + off.normalized() * max_range

func _ult_pack() -> Dictionary:
	return {
		"radius": ult_zone_radius,
		"dur": ult_duration,
		"tp": ult_tp_cd,
		"ldmg": ult_line_damage,
		"llife": ult_line_life,
		"edmg": ult_explosion_damage
	}

func _setup_placeholder_frames() -> void:
	if sprite == null:
		return
	var tex: Texture2D = load("res://assets/sprites/icon.svg") as Texture2D
	if tex == null:
		return
	var sf := SpriteFrames.new()
	for anim_name in ["idle", "run", "shoot", "ability1", "ult", "reload", "death"]:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, anim_name == "idle" or anim_name == "run")
		sf.add_frame(anim_name, tex, 1.0)
	sprite.sprite_frames = sf
	sprite.modulate = Color(0.66, 0.79, 0.92, 1.0)
