extends Node2D

# F1: Solo (you vs 3 AI)
# F2-F4: Local multiplayer (keyboard split)
# F5: Sandbox (no enemies)
# ESC: Back to menu

@onready var gm: GameManager = $GameManager

func _ready() -> void:
	# Collect spawn points from the map
	_setup_spawn_points()
	
	# Check if we're coming from the lobby
	if GameData.is_online_game:
		_start_from_lobby()
	else:
		start_solo_vs_ai()

func _setup_spawn_points() -> void:
	gm.spawn_points.clear()
	
	# Find SpawnPoints node in the map
	var map = get_node_or_null("testMap")
	if map == null:
		map = self
	
	var spawns = map.get_node_or_null("SpawnPoints")
	if spawns == null:
		push_warning("Game: No SpawnPoints node found in map")
		return
	
	for child in spawns.get_children():
		if child is Marker2D:
			gm.spawn_points.append(child)
	
	print("Found ", gm.spawn_points.size(), " spawn points")



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
