extends Node2D

# F1: Solo (you vs 3 AI)
# F2-F4: Local multiplayer (keyboard split)
# F5: Sandbox (no enemies)
# ESC: Pause menu

const MAP_SCENES := {
	"testArena": "res://scenes/maps/maze_map.tscn",
	"Moon": "res://scenes/maps/moon.tscn",
}
const CROP_SCENES := {
	"SpeedCarrot": preload("res://scenes/crops/speed_carrot.tscn"),
	"IronRoot": preload("res://scenes/crops/iron_root.tscn"),
	"BlastBerry": preload("res://scenes/crops/blast_berry.tscn"),
}
@export var DEFAULT_MAP: String = "Moon"

const DebugMenu = preload("res://scripts/ui/debug_menu.gd")
const Killzone = preload("res://scripts/killzone.gd")
const UltBannerScene = preload("res://scenes/ui/ultbanner.tscn")
const PauseMenuScene = preload("res://scenes/ui/pause_menu.tscn")

const GAME_DURATION := 300.0
const SUDDEN_DEATH_DURATION := 120.0

@onready var gm: GameManager = $GameManager
var map_node: Node = null
var map_theme: Node = null
var map_sd_theme: Node = null
var farms: Array = []
var game_timer: float = 0.0
var game_active: bool = false
var killzone_node: Node2D = null

# HUD
var _timer_layer: CanvasLayer = null
var _timer_label: Label = null
var _sudden_label: Label = null
var _ult_layer: CanvasLayer = null
var _ult_banner: CanvasGroup = null
var _pause_layer: CanvasLayer = null
var _pause_menu: Control = null

func _ready() -> void:
	GameData.stop_menu_theme()
	var dbg = DebugMenu.new()
	add_child(dbg)
	
	var map_name = GameData.pending_settings.get("map", DEFAULT_MAP)
	var starters = GameData.get_active_starters()
	_load_map(map_name)
	_setup_entity_layer()
	_collect_farms()
	gm.farm_spawns_received.connect(_on_farm_spawns_received)
	gm.ult_used_received.connect(_on_ult_used_received)
	_setup_ult_banner()
	
	if GameData.is_online_game:
		_start_from_lobby()
	elif GameData.game_mode == GameData.GameMode.SOLO:
		start_solo_practice()
	else:
		start_solo_vs_ai()
	
	_assign_farms()
	_play_map_theme()
	await get_tree().process_frame
	await get_tree().process_frame
	_collect_farms_tiles()
	_plant_starter_crops(starters)
	
	gm.player_eliminated.connect(_on_player_eliminated)
	gm.game_over_received.connect(_on_game_over_received)
	gm.sudden_death_received.connect(_activate_sudden_death)
	_setup_pause_menu()
	_create_timer_hud()
	game_timer = 0.0
	game_active = true

func _setup_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 120
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	_pause_menu = PauseMenuScene.instantiate()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.add_child(_pause_menu)
	_pause_menu.continue_pressed.connect(_close_pause_menu)
	_pause_menu.back_to_menu_pressed.connect(_pause_back_to_menu)

func _setup_ult_banner() -> void:
	_ult_layer = CanvasLayer.new()
	_ult_layer.layer = 90
	add_child(_ult_layer)
	_ult_banner = UltBannerScene.instantiate()
	_ult_layer.add_child(_ult_banner)

func _on_ult_used_received(player_id: int) -> void:
	if _ult_banner == null:
		return
	var p = gm.get_player(player_id)
	if p == null or not is_instance_valid(p) or p.hero == null:
		return
	var name = gm.get_player_username(player_id)
	if _ult_banner.has_method("show_ult"):
		_ult_banner.show_ult(p, name)

func _load_map(map_name: String) -> void:
	var path = MAP_SCENES.get(map_name, MAP_SCENES[DEFAULT_MAP])
	var scene = load(path)
	if scene:
		map_node = scene.instantiate()
		map_node.name = "map"
		add_child(map_node)
		move_child(map_node, 0)
		_cache_map_music_nodes()
	else:
		push_error("Game: Failed to load map scene: ", path)

func _cache_map_music_nodes() -> void:
	map_theme = null
	map_sd_theme = null
	if map_node == null:
		return
	map_theme = map_node.get_node_or_null("Theme")
	if map_theme == null:
		map_theme = map_node.find_child("Theme", true, false)
	map_sd_theme = map_node.get_node_or_null("SDTheme")
	if map_sd_theme == null:
		map_sd_theme = map_node.find_child("SDTheme", true, false)

func _play_map_theme() -> void:
	if map_node == null:
		return
	if map_theme == null and map_sd_theme == null:
		_cache_map_music_nodes()
	_stop_audio_node(map_sd_theme)
	_play_audio_node(map_theme, "Theme")

func _play_sd_theme() -> void:
	if map_node == null:
		return
	if map_theme == null and map_sd_theme == null:
		_cache_map_music_nodes()
	_stop_audio_node(map_theme)
	_play_audio_node(map_sd_theme, "SDTheme")

func _play_audio_node(node: Node, label: String) -> void:
	if node == null:
		push_warning("Game: Map has no %s node" % label)
		return
	if not node.has_method("play"):
		push_warning("Game: %s node has no play() method" % label)
		return
	if node.has_method("is_playing") and bool(node.call("is_playing")):
		return
	node.call("play")

func _stop_audio_node(node: Node) -> void:
	if node == null:
		return
	node.call("stop")

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
	if farms.is_empty() or gm.players.is_empty():
		return
	var sorted_farms = farms.duplicate()
	sorted_farms.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
	var sorted_players = gm.players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.player_id < b.player_id)
	var assignments: Array = []
	var count = mini(sorted_farms.size(), sorted_players.size())
	for i in range(count):
		var farm = sorted_farms[i]
		var player = sorted_players[i]
		var spawn_pos = _get_farm_spawn_pos(farm)
		farm.assign_owner(player)
		player.global_position = spawn_pos
		assignments.append({
			"pid": player.player_id,
			"farm_path": str(farm.get_path()),
			"x": spawn_pos.x,
			"y": spawn_pos.y
		})
	if gm.mode == GameManager.Mode.ONLINE_HOST:
		gm.broadcast_farm_spawns(assignments)

func _get_farm_spawn_pos(farm: Node) -> Vector2:
	var sp = farm.get_node_or_null("Spawnpoint")
	if sp == null:
		sp = farm.get_node_or_null("spawnpoint")
	if sp and sp is Node2D:
		return sp.global_position
	return farm.global_position

func _on_farm_spawns_received(assignments: Array) -> void:
	if gm.mode != GameManager.Mode.ONLINE_CLIENT:
		return
	_apply_farm_spawns(assignments)

func _apply_farm_spawns(assignments: Array) -> void:
	var farm_by_path := {}
	for farm in farms:
		farm_by_path[str(farm.get_path())] = farm
	for item in assignments:
		if not (item is Dictionary):
			continue
		var pid = int(item.get("pid", -1))
		var player = gm.get_player(pid)
		if player == null or not is_instance_valid(player):
			continue
		var farm_path = str(item.get("farm_path", ""))
		var farm = farm_by_path.get(farm_path, null)
		if farm == null:
			continue
		farm.assign_owner(player)
		player.global_position = Vector2(
			item.get("x", player.global_position.x),
			item.get("y", player.global_position.y)
		)

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
	if event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return
	
	# Only allow mode switching in local mode
	if gm.mode != GameManager.Mode.LOCAL:
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

func _toggle_pause_menu() -> void:
	if _pause_menu == null:
		return
	if _pause_menu.visible:
		_close_pause_menu()
	else:
		_open_pause_menu()

func _pause_uses_tree_freeze() -> bool:
	return gm.mode == GameManager.Mode.LOCAL

func _open_pause_menu() -> void:
	if _pause_uses_tree_freeze():
		get_tree().paused = true
	else:
		GameData.menu_pause_local = true
	_pause_menu.open_menu()

func _close_pause_menu() -> void:
	GameData.menu_pause_local = false
	get_tree().paused = false
	if _pause_menu:
		_pause_menu.close_menu()

func _pause_back_to_menu() -> void:
	GameData.menu_pause_local = false
	get_tree().paused = false
	_back_to_menu()

func _back_to_menu() -> void:
	gm.disconnect_online()
	GameData.change_scene("res://scenes/ui/main_menu.tscn")

func start_solo_vs_ai() -> void:
	gm.disconnect_online()
	gm.clear_players()
	
	var human = gm.spawn_local_player(0)
	human.set_hero(GameData.train_hero_for_game())
	
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

func start_solo_practice() -> void:
	gm.disconnect_online()
	gm.clear_players()
	var human = gm.spawn_local_player(0)
	human.set_hero(GameData.train_hero_for_game())
	var npc = gm.spawn_ai_player(1)
	npc.is_invulnerable = true
	npc.modulate = Color(0.7, 0.7, 1.0)
	npc.input.owner_node = null
	print("SOLO PRACTICE - invincible NPC, debug menu available (TAB)")

# ---------- Game Timer / Sudden Death / Win Condition ----------

func _process(delta: float) -> void:
	if not game_active:
		return
	
	game_timer += delta
	_update_timer_hud()
	
	if not gm.sudden_death and game_timer >= GAME_DURATION:
		_trigger_sudden_death()

func _trigger_sudden_death() -> void:
	if gm.sudden_death:
		return
	gm.broadcast_sudden_death()
	_activate_sudden_death()

func _activate_sudden_death() -> void:
	gm.sudden_death = true
	print("SUDDEN DEATH activated")
	_play_sd_theme()
	if _sudden_label:
		_sudden_label.visible = true
	_spawn_killzone()

func _spawn_killzone() -> void:
	killzone_node = Node2D.new()
	killzone_node.set_script(Killzone)
	killzone_node.set("duration", SUDDEN_DEATH_DURATION)
	killzone_node.set("start_radius", 3000.0)
	killzone_node.set("end_radius", 100.0)
	var parent = map_node if map_node else self
	parent.add_child(killzone_node)

func _on_player_eliminated(elim_player: Player) -> void:
	print("[GAME] _on_player_eliminated: pid=", elim_player.player_id, " game_over=", gm.game_over)
	if gm.game_over:
		return
	var alive = gm.get_alive_players()
	alive.erase(elim_player)
	print("[GAME] alive after erase: ", alive.size(), " players")
	if alive.size() <= 1:
		_end_game(alive[0] if alive.size() == 1 else null)

func _end_game(winner: Player) -> void:
	print("[GAME] _end_game called. winner=", winner.player_id if winner else "null", " game_over=", gm.game_over)
	if gm.game_over:
		print("[GAME] _end_game: already game_over, returning")
		return
	gm.game_over = true
	game_active = false
	
	if killzone_node and is_instance_valid(killzone_node):
		killzone_node.queue_free()
		killzone_node = null
	
	if winner == null:
		winner = _resolve_tie()
	
	print("[GAME] _end_game: broadcasting game_over, showing winner screen for pid=", winner.player_id if winner else -1)
	gm.broadcast_game_over(winner.player_id if winner else -1)
	_show_winner_screen(winner)

func _on_game_over_received(winner_id: int) -> void:
	print("[GAME] _on_game_over_received: winner_id=", winner_id, " game_over=", gm.game_over)
	if gm.game_over:
		print("[GAME] _on_game_over_received: already game_over, returning")
		return
	gm.game_over = true
	game_active = false
	
	if killzone_node and is_instance_valid(killzone_node):
		killzone_node.queue_free()
		killzone_node = null
	
	var winner = gm.get_player(winner_id)
	print("[GAME] _on_game_over_received: showing winner screen for ", winner.player_id if winner else "null")
	for p in gm.players:
		p.clear_elimination_ui()
	_show_winner_screen(winner)

func _resolve_tie() -> Player:
	var best: Player = null
	var best_crops := -1
	var best_kills := -1
	for p in gm.players:
		if not is_instance_valid(p):
			continue
		var s = gm.get_stats(p.player_id)
		var crops = p.crop_count
		var kills = s["kills"]
		if crops > best_crops or (crops == best_crops and kills > best_kills):
			best = p
			best_crops = crops
			best_kills = kills
		elif crops == best_crops and kills == best_kills:
			if randi() % 2 == 0:
				best = p
				best_crops = crops
				best_kills = kills
	return best

# ---------- Timer HUD ----------

func _create_timer_hud() -> void:
	_timer_layer = CanvasLayer.new()
	_timer_layer.layer = 80
	add_child(_timer_layer)
	
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer_label.position.y = 12
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_layer.add_child(_timer_label)
	
	_sudden_label = Label.new()
	_sudden_label.text = "SUDDEN DEATH"
	_sudden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sudden_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sudden_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sudden_label.position.y = 42
	_sudden_label.add_theme_font_size_override("font_size", 20)
	_sudden_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_sudden_label.visible = false
	_timer_layer.add_child(_sudden_label)

func _update_timer_hud() -> void:
	if _timer_label == null:
		return
	var remaining = max(GAME_DURATION - game_timer, 0.0)
	if gm.sudden_death:
		var sd_elapsed = game_timer - GAME_DURATION
		var sd_remaining = max(SUDDEN_DEATH_DURATION - sd_elapsed, 0.0)
		var mins = int(sd_remaining) / 60
		var secs = int(sd_remaining) % 60
		_timer_label.text = "%d:%02d" % [mins, secs]
		_timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		var mins = int(remaining) / 60
		var secs = int(remaining) % 60
		_timer_label.text = "%d:%02d" % [mins, secs]
		if remaining <= 30.0:
			_timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
		else:
			_timer_label.add_theme_color_override("font_color", Color.WHITE)

# ---------- Winner Screen ----------

func _show_winner_screen(winner: Player) -> void:
	print("[GAME] _show_winner_screen: winner=", winner.player_id if winner else "null")
	var layer = CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	bg.add_child(vbox)
	
	var crown = Label.new()
	crown.text = "GAME WINNER"
	crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown.add_theme_font_size_override("font_size", 28)
	crown.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(crown)
	
	var name_label = Label.new()
	var winner_name = "Nobody"
	if winner:
		winner_name = gm.get_player_username(winner.player_id)
	name_label.text = winner_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 48)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	await get_tree().create_timer(5.0).timeout
	layer.queue_free()
	_show_game_over_screen()

# ---------- Game Over Screen ----------

func _show_game_over_screen() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(500, 0)
	center.add_theme_constant_override("separation", 16)
	bg.add_child(center)
	
	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(title)
	
	# Leaderboard
	var lb = _build_leaderboard()
	center.add_child(lb)
	
	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	center.add_child(btn_row)
	
	var lobby_btn = Button.new()
	lobby_btn.text = "Return to Lobby"
	lobby_btn.custom_minimum_size = Vector2(180, 48)
	lobby_btn.pressed.connect(_on_return_to_lobby)
	btn_row.add_child(lobby_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(180, 48)
	quit_btn.pressed.connect(_on_quit_to_menu)
	btn_row.add_child(quit_btn)

func _build_leaderboard() -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Header row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	for col in ["#", "Player", "Crops", "Kills", "Deaths"]:
		var lbl = Label.new()
		lbl.text = col
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(lbl)
	vbox.add_child(header)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Sorted player list
	var sorted = _get_sorted_players()
	for i in sorted.size():
		var p = sorted[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		
		var rank_l = Label.new()
		rank_l.text = str(i + 1)
		rank_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(rank_l)
		
		var name_l = Label.new()
		name_l.text = p["name"]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not p["alive"]:
			name_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(name_l)
		
		for key in ["crops", "kills", "deaths"]:
			var val_l = Label.new()
			val_l.text = str(p[key])
			val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if not p["alive"]:
				val_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(val_l)
		
		vbox.add_child(row)
	
	return panel

func _get_sorted_players() -> Array:
	var list: Array = []
	for p in gm.players:
		if not is_instance_valid(p):
			continue
		var s = gm.get_stats(p.player_id)
		var pname = gm.get_player_username(p.player_id)
		list.append({
			"name": pname,
			"crops": p.crop_count,
			"kills": s["kills"],
			"deaths": s["deaths"],
			"alive": not p.in_spectate_mode
		})
	list.sort_custom(func(a, b):
		if a["alive"] != b["alive"]:
			return a["alive"]
		if a["crops"] != b["crops"]:
			return a["crops"] > b["crops"]
		return a["kills"] > b["kills"]
	)
	return list

# ---------- Return to Lobby / Quit ----------

func _on_return_to_lobby() -> void:
	if Network.is_online():
		GameData.game_mode = GameData.GameMode.HOST if Network.is_host else GameData.GameMode.JOIN
	else:
		GameData.game_mode = GameData.GameMode.NONE
	gm.clear_players()
	GameData.change_scene("res://scenes/ui/lobby.tscn")

func _on_quit_to_menu() -> void:
	gm.disconnect_online()
	GameData.change_scene("res://scenes/ui/main_menu.tscn")
