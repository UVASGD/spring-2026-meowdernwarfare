extends RefCounted

## Crop pickup, carrying, planting and uprooting for one player.
## Shared gameplay state (held_crop, crop_count, farm) stays on Player;
## this owns the pickup area and held-crop visuals.

const INTERACT_RANGE := 400.0
const TILE_HALF := 80.0
const DROP_CD_TIME := 0.5

var player: Player
var drop_cd: float = 0.0
var held_sprite: Sprite2D = null
var _remote_held_sprite: Sprite2D = null
var _remote_held_type: String = ""
var _crop_area: Area2D = null

func _init(p: Player) -> void:
	player = p
	_setup_crop_area()

func _setup_crop_area() -> void:
	_crop_area = Area2D.new()
	_crop_area.collision_layer = 0
	_crop_area.collision_mask = 16
	_crop_area.monitoring = true
	_crop_area.monitorable = false
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	_crop_area.add_child(shape)
	player.add_child(_crop_area)
	_crop_area.area_entered.connect(_on_crop_area_entered)

func set_pickup_enabled(enabled: bool) -> void:
	if _crop_area:
		_crop_area.monitoring = enabled

func _on_crop_area_entered(area: Area2D) -> void:
	if player.in_spectate_mode: return
	if not player.is_locally_controlled(): return
	if area is Crop and player.held_crop == null and drop_cd <= 0 and not area.is_planted:
		pickup_world_crop(area)

## Returns true when the shoot click was consumed by planting/uprooting.
func handle(delta: float) -> bool:
	var input = player.input
	if input == null:
		return false
	if drop_cd > 0:
		drop_cd -= delta

	# Held-crop sprite positions update on every peer
	if held_sprite and player.held_crop:
		held_sprite.global_position = player.global_position + (-player.aim_dir.normalized() * 40.0)
	if _remote_held_sprite and _remote_held_sprite.visible:
		_remote_held_sprite.position = Vector2(0, 40).rotated(-player.rotation_offset)

	# Crop interaction only runs on the peer that controls this player. Remote
	# copies have no aim_position (always (0,0)), so simulating plant/uproot here
	# could phantom-uproot tiles near the world origin. Crop state for remote
	# players arrives via crop_* network messages instead.
	if not player.is_locally_controlled():
		return false

	if input.drop_just and player.held_crop != null:
		drop_held_crop()
		return false

	# Plant held crop (LMB click while holding)
	if input.shoot_just and player.held_crop != null:
		return _try_plant()

	# Pick up planted crop (LMB click on planted crop, not holding anything)
	if input.shoot_just and player.held_crop == null:
		return _try_uproot()

	return false

func pickup_world_crop(crop: Crop) -> void:
	var crop_pos = crop.global_position
	var type_id = crop.get_type_id()
	var stg = crop.stage
	player.held_crop = crop
	crop.picked_up.emit()
	if crop.get_parent():
		crop.get_parent().remove_child(crop)

	held_sprite = Sprite2D.new()
	held_sprite.texture = crop.icon if crop.icon else _make_placeholder_tex(crop)
	held_sprite.scale = Vector2(0.5, 0.5)
	held_sprite.z_index = 10
	player.get_parent().add_child(held_sprite)
	held_sprite.global_position = player.global_position + (-player.aim_dir.normalized() * 40.0)

	var gm = GameManager.instance
	if gm and not gm.is_local():
		gm.send_crop_pickup(player.player_id, crop_pos, type_id, stg)

func drop_held_crop() -> void:
	if player.held_crop == null:
		return
	var crop = player.held_crop
	var type_id = crop.get_type_id()
	var stg = crop.stage
	crop.global_position = player.global_position
	player.get_parent().add_child(crop)
	player.held_crop = null
	drop_cd = DROP_CD_TIME
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null
	var gm = GameManager.instance
	if gm and not gm.is_local():
		gm.send_crop_dropped(player.player_id, player.global_position, type_id, stg)

func _tile_at_cursor(tiles: Array) -> Node:
	var aim_pos = player.get_aim_position()
	for tile in tiles:
		if tile.global_position.distance_to(aim_pos) <= TILE_HALF:
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
	if tile.global_position.distance_to(player.global_position) > INTERACT_RANGE:
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

	var gm = GameManager.instance
	if gm and not gm.is_local():
		gm.send_crop_planted(player.player_id, tiles.find(tile), crop_type, stg)
	return true

func _try_uproot() -> bool:
	for f in player.get_tree().get_nodes_in_group("farms"):
		var tiles = _get_plantable_tiles(f)
		var tile = _tile_at_cursor(tiles)
		if tile == null or tile.planted_crop == null:
			continue
		if tile.global_position.distance_to(player.global_position) > INTERACT_RANGE:
			continue
		var tile_idx = tiles.find(tile)
		var crop = f.remove_crop(tile.planted_crop)
		if crop:
			var victim = f._owner
			if victim:
				victim.crop_count -= 1
			pickup_world_crop(crop)
			var gm = GameManager.instance
			if gm and not gm.is_local() and victim:
				gm.send_crop_uproot(victim.player_id, tile_idx, crop.get_type_id(), crop.stage)
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

# --- REMOTE HELD-CROP VISUAL ---

func set_remote_held_crop(type_id: String, stg: int) -> void:
	if type_id == _remote_held_type and _remote_held_sprite != null:
		return
	_remote_held_type = type_id
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
	if _remote_held_sprite:
		_remote_held_sprite.visible = false
