extends Node2D

# F1: Solo (you vs 3 AI)
# F2-F4: Local multiplayer (keyboard split)
# F5: Sandbox (no enemies)
# ESC: Back to menu

const MAP_SCENES := {
	"testArena": "res://scenes/maps/maze_map.tscn",
	"Moon": "res://scenes/maps/moon.tscn",
}
@export var DEFAULT_MAP:String = "testArena"

@onready var gm: GameManager = $GameManager
var map_node: Node = null

func _ready() -> void:
	var map_name = GameData.pending_settings.get("map", DEFAULT_MAP)
	_load_map(map_name)
	_setup_spawn_points()
	_setup_entity_layer()
	
	if GameData.is_online_game:
		_start_from_lobby()
	else:
		start_solo_vs_ai()

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
