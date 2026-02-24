extends Node2D

# F1: Solo (you vs 3 AI)
# F2-F4: Local multiplayer (keyboard split)
# F5: Sandbox (no enemies)
# ESC: Back to menu

const MAP_SCENES := {
	"testArena": "res://scenes/maps/maze_map.tscn",
	"Moon": "res://scenes/maps/moon.tscn",
}
const CROP_SCENES := {
	"SpeedSprout": preload("res://scenes/crops/speed_sprout.tscn"),
	"IronRoot": preload("res://scenes/crops/iron_root.tscn"),
	"BlastBerry": preload("res://scenes/crops/blast_berry.tscn"),
}
@export var DEFAULT_MAP: String = "testArena"

const DebugMenu = preload("res://scripts/ui/debug_menu.gd")

@onready var gm: GameManager = $GameManager
var map_node: Node = null
var farms: Array = []

func _ready() -> void:
	var dbg = DebugMenu.new()
	add_child(dbg)
	
	var map_name = GameData.pending_settings.get("map", DEFAULT_MAP)
	var starters = GameData.get_active_starters()
	_load_map(map_name)
	_setup_spawn_points()
	_setup_entity_layer()
	_collect_farms()
	
	if GameData.is_online_game:
		_start_from_lobby()
	else:
		start_solo_vs_ai()
	
	_assign_farms()
	# Scene tiles in TileMapLayer aren't instantiated until the first frame update
	await get_tree().process_frame
	await get_tree().process_frame
	_collect_farms_tiles()
	_plant_starter_crops(starters)

func _load_map(map_name: String) -> void:
	var path = MAP_SCENES.get(map_name, MAP_SCENES[DEFAULT_MAP])
	var scene = load(path)
	if scene:
		map_node = scene.instantiate()
		map_node.name = "map"
		add_child(map_node)
		move_child(map_node, 0)
	else:
		push_error("Game: Failed to load map scene: ", path)

func _setup_spawn_points() -> void:
	gm.spawn_points.clear()
	
	var target = map_node if map_node else self
	var spawns = target.get_node_or_null("SpawnPoints")
	if spawns == null:
		spawns = target.find_child("SpawnPoints", true, false)
	if spawns == null:
		push_warning("Game: No SpawnPoints node found in map")
		return
	
	for child in spawns.get_children():
		if child is Marker2D:
			gm.spawn_points.append(child)
	
	print("Found ", gm.spawn_points.size(), " spawn points")

func _setup_entity_layer() -> void:
	if map_node == null:
		return
	var ysort = _find_ysort_container(map_node)
	if ysort:
		gm.entity_parent = ysort

func _find_ysort_container(node: Node) -> Node2D:
	for child in node.get_children():
		if not (child is Node2D and child.y_sort_enabled):
			continue
		var has_ysort_child = false
		for gc in child.get_children():
			if gc is Node2D and gc.y_sort_enabled:
				has_ysort_child = true
				break
		if has_ysort_child:
			var deeper = _find_ysort_container(child)
			return deeper if deeper else child
	return null

func _collect_farms() -> void:
	farms = get_tree().get_nodes_in_group("farms")

func _collect_farms_tiles() -> void:
	#print("[CROP] _collect_farms_tiles (post-frame): re-checking tile counts")
	#for i in farms.size():
	#	var f = farms[i]
	#	var tilemap = f.get_node_or_null("TileMapLayer")
	#	if tilemap:
	#		var tile_count = 0
	#		for child in tilemap.get_children():
	#			if child.has_method("plant"):
	#				tile_count += 1
	#		print("[CROP]   farm[", i, "] '", f.name, "': ", tilemap.get_child_count(), " children, ", tile_count, " plantable tiles")
	#	else:
	#		print("[CROP]   farm[", i, "] '", f.name, "': no TileMapLayer")
	pass

func _assign_farms() -> void:
	var available = farms.duplicate()
	for player in gm.players:
		var best_farm = null
		var best_dist := INF
		for f in available:
			var dist = f.global_position.distance_to(player.global_position)
			if dist < best_dist:
				best_dist = dist
				best_farm = f
		if best_farm:
			best_farm.assign_owner(player)
			available.erase(best_farm)

func _plant_starter_crops(starters: Array[String] = []) -> void:
	if starters.is_empty():
		starters = GameData.get_active_starters()
	if starters.is_empty():
		return
	
	for player in gm.players:
		if player.farm == null:
			continue
		var tiles = _get_empty_tiles(player.farm)
		for j in range(mini(starters.size(), tiles.size())):
			var scene = CROP_SCENES.get(starters[j])
			if scene == null:
				continue
			var crop = scene.instantiate() as Crop
			crop.stage = 2
			crop._setup()
			player.farm.plant_crop(crop, tiles[j])
			player.crop_count += 1

func _get_empty_tiles(f) -> Array:
	var tiles: Array = []
	var tilemap = f.get_node_or_null("TileMapLayer")
	if tilemap == null:
		return tiles
	for child in tilemap.get_children():
		if child.has_method("plant") and child.planted_crop == null:
			tiles.append(child)
	return tiles

func _start_from_lobby() -> void:
	gm.start_online_game(GameData.pending_players, GameData.pending_settings)
	GameData.clear()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	
	# Only allow mode switching in local mode
	if gm.mode != GameManager.Mode.LOCAL:
		if event.keycode == KEY_ESCAPE:
			_back_to_menu()
		return
	
	match event.keycode:
		KEY_F1:
			start_solo_vs_ai()
		KEY_F2:
			start_local(2)
		KEY_F3:
			start_local(3)
		KEY_F4:
			start_local(4)
		KEY_F5:
			start_sandbox()
		KEY_ESCAPE:
			_back_to_menu()

func _back_to_menu() -> void:
	gm.disconnect_online()
	GameData.change_scene("res://scenes/ui/main_menu.tscn")

func start_solo_vs_ai() -> void:
	gm.disconnect_online()
	gm.clear_players()
	
	var human = gm.spawn_local_player(0)
	
	for i in range(1, 4):
		var ai = gm.spawn_ai_player(i, human)
		ai.modulate = Color(1, 0.5, 0.5)
	
	print("SOLO VS AI - WASD move, Mouse aim, LMB shoot, E ability, R reload, Space dash")

func start_local(count: int) -> void:
	gm.disconnect_online()
	gm.start_local_game(count)
	print("LOCAL ", count, " PLAYERS")

func start_sandbox() -> void:
	gm.disconnect_online()
	gm.clear_players()
	gm.spawn_local_player(0)
	print("SANDBOX MODE")
