class_name PlayerCrops
extends RefCounted

## Crop interaction for one Player: pickup area, held-crop visuals, drop /
## plant / uproot, and the remote-mirror sprite peers see. Injected with the
## owning Player; all shared state (held_crop, crop_count, drop_cd, farm)
## stays on the Player.

const SfxEvent = preload("res://scripts/audio/sfx_event.gd")
const SfxBus = preload("res://scripts/audio/sfx_bus.gd")

var player: Player

var area: Area2D = null
var held_sprite: Sprite2D = null
var _remote_held_sprite: Sprite2D = null
var _remote_held_type: String = ""
var _remote_held_stage: int = 1
var _drop_seq: int = 0

func _init(p: Player) -> void:
	player = p

func setup() -> void:
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 16
	area.monitoring = true
	area.monitorable = false
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	area.add_child(shape)
	player.add_child(area)
	area.area_entered.connect(_on_area_entered)

func set_pickup_enabled(enabled: bool) -> void:
	if area:
		area.monitoring = enabled

func _on_area_entered(a: Area2D) -> void:
	if player.in_spectate_mode: return
	if player.input is NetworkInput and not player.input.is_local: return
	if a is Crop and player.held_crop == null and player.drop_cd <= 0 and not a.is_planted:
		pickup_world_crop(a)

## Per-frame crop handling; returns true when a shoot click was consumed.
func handle(_delta: float) -> bool:
	if player.input == null:
		return false
	if player.hero and player.hero.blocks_crop_actions():
		return false
	var consumed_shoot := false

	# Gameplay branches (drop/plant/uproot) mutate shared state + send network traffic,
	# so only the local-owner peer may run them. The host's remote-player sim must NOT.
	if player._is_local_player() and player._target_mode == Player.TARGET_NONE:
		if player.input.drop_just and player.held_crop != null:
			drop_held_crop()
		elif player.input.shoot_just and player.held_crop != null:
			consumed_shoot = _try_plant()
		elif player.input.shoot_just and player.held_crop == null:
			consumed_shoot = _try_uproot()

	# Visuals run on every peer (local owner's held crop + remote-mirror sprite).
	if held_sprite and player.held_crop:
		var behind = -player.aim_dir.normalized() * 40.0
		held_sprite.global_position = player.global_position + behind
	if _remote_held_sprite and _remote_held_sprite.visible:
		_remote_held_sprite.position = Vector2(0, 40).rotated(-player.rotation_offset)
	return consumed_shoot

func pickup_world_crop(crop: Crop) -> void:
	var crop_pos = crop.global_position
	var type_id = crop.get_type_id()
	var stg = crop.stage
	var cid := crop.crop_id
	_attach_held_crop(crop)
	
	var gm = GameManager.instance
	if gm and not gm.is_local():
		gm.send_crop_pickup(player.player_id, crop_pos, type_id, stg, cid)

func _attach_held_crop(crop: Crop) -> void:
	player.held_crop = crop
	crop.picked_up.emit()
	if crop.get_parent():
		crop.get_parent().remove_child(crop)
	if held_sprite:
		held_sprite.queue_free()
	held_sprite = Sprite2D.new()
	held_sprite.texture = crop.icon if crop.icon else _make_placeholder_tex(crop)
	held_sprite.scale = Vector2(0.5, 0.5)
	held_sprite.z_index = 10
	player.get_parent().add_child(held_sprite)
	held_sprite.global_position = player.global_position + (-player.aim_dir.normalized() * 40.0)
	SfxBus.play_world(SfxEvent.PLAYER_CROP_PICKUP, player.global_position)

func can_receive_held_crop() -> bool:
	return player.held_crop == null and player.drop_cd <= 0.0 \
		and not player.in_spectate_mode and not player.is_awaiting_respawn and not player.is_dying

func get_any_held_crop_data() -> Dictionary:
	if player.held_crop != null:
		return {"type": player.held_crop.get_type_id(), "stage": player.held_crop.stage}
	if _remote_held_type != "":
		return {"type": _remote_held_type, "stage": _remote_held_stage}
	return {}

func force_clear_held_crop_local() -> void:
	if player.held_crop:
		player.held_crop.queue_free()
		player.held_crop = null
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null
	clear_remote_held_crop()

func receive_stolen_crop(type_id: String, stg: int) -> void:
	if not can_receive_held_crop():
		return
	var scene = GameManager.CROP_SCENES.get(type_id)
	if scene == null:
		return
	var crop = scene.instantiate() as Crop
	crop.stage = stg
	crop._setup()
	_attach_held_crop(crop)

func drop_held_crop() -> void:
	if player.held_crop == null:
		return
	var crop = player.held_crop
	var type_id = crop.get_type_id()
	var stg = crop.stage
	_drop_seq += 1
	var cid := "dr:%d:%d" % [player.player_id, _drop_seq]
	crop.crop_id = cid
	crop.global_position = player.global_position
	player.get_parent().add_child(crop)
	var gm = GameManager.instance
	if gm:
		gm.register_world_crop(crop)
	player.held_crop = null
	player.drop_cd = Player.DROP_CD_TIME
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null
	if gm and not gm.is_local():
		gm.send_crop_dropped(player.player_id, player.global_position, type_id, stg, cid)
	SfxBus.play_world(SfxEvent.PLAYER_CROP_DROP, player.global_position)

func _tile_at_cursor(tiles: Array) -> Node:
	var aim_pos = player.get_aim_position()
	for tile in tiles:
		if tile.global_position.distance_to(aim_pos) <= Player.TILE_HALF:
			return tile
	return null

func _try_plant() -> bool:
	var farm = player.farm
	if farm == null or player.held_crop == null:
		return false
	if not farm.has_space():
		return false
	
	var tiles = _get_plantable_tiles(farm)
	var tile = _tile_at_cursor(tiles)
	if tile == null or tile.planted_crop != null:
		return false
	if tile.global_position.distance_to(player.global_position) > Player.INTERACT_RANGE:
		return false
	
	var crop = player.held_crop
	var crop_type = crop.get_type_id()
	var stg = crop.stage
	player.held_crop = null
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null
	
	farm.plant_crop(crop, tile)
	player.crop_count += 1
	SfxBus.play_world(SfxEvent.PLAYER_CROP_PLANT, player.global_position)
	
	var gm = GameManager.instance
	if gm and not gm.is_local():
		var tile_idx = tiles.find(tile)
		gm.send_crop_planted(player.player_id, tile_idx, crop_type, stg)
	return true

func _try_uproot() -> bool:
	var gm = GameManager.instance
	var farms_list = gm.get_farms() if gm else player.get_tree().get_nodes_in_group("farms")
	for f in farms_list:
		var tiles = _get_plantable_tiles(f)
		var tile = _tile_at_cursor(tiles)
		if tile == null or tile.planted_crop == null:
			continue
		if tile.global_position.distance_to(player.global_position) > Player.UPROOT_RANGE:
			continue
		var tile_idx = tiles.find(tile)
		var crop = f.remove_crop(tile.planted_crop)
		if crop:
			var victim = f._owner
			if victim:
				victim.crop_count -= 1
			pickup_world_crop(crop)
			if gm and not gm.is_local() and victim:
				gm.send_crop_uproot(victim.player_id, tile_idx, crop.get_type_id(), crop.stage)
			SfxBus.play_world(SfxEvent.PLAYER_CROP_UPROOT, player.global_position)
			return true
		return false
	return false

func _get_plantable_tiles(f) -> Array:
	var tiles: Array = []
	var tilemap = f.get_node_or_null("TileMapLayer")
	if tilemap == null:
		return tiles
	for child in tilemap.get_children():
		if child.has_method("plant"):
			tiles.append(child)
	return tiles

func _make_placeholder_tex(crop: Crop) -> Texture2D:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(crop.get_stage_color())
	return ImageTexture.create_from_image(img)

func set_remote_held_crop(type_id: String, stg: int) -> void:
	if type_id == _remote_held_type and stg == _remote_held_stage and _remote_held_sprite != null:
		return
	_remote_held_type = type_id
	_remote_held_stage = stg
	if _remote_held_sprite == null:
		_remote_held_sprite = Sprite2D.new()
		_remote_held_sprite.scale = Vector2(0.5, 0.5)
		_remote_held_sprite.z_index = 10
		_remote_held_sprite.position = Vector2(0, 40)
		player.add_child(_remote_held_sprite)
	var gm = GameManager.instance
	if gm:
		_remote_held_sprite.texture = gm.make_crop_icon(type_id, stg)
	_remote_held_sprite.visible = true

func clear_remote_held_crop() -> void:
	_remote_held_type = ""
	_remote_held_stage = 1
	if _remote_held_sprite:
		_remote_held_sprite.visible = false
