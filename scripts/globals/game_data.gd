extends Node

const TransitionSettings = preload("res://scripts/globals/transition_settings.gd")
const MENU_THEME = preload("res://assets/sound/mainthemev2.wav")
const STARTUP_SHADER_PATHS := [
	"res://assets/shaders/scene_wipe.gdshader",
	"res://assets/shaders/3deffect.gdshader",
	"res://assets/shaders/burn_reveal.gdshader",
	"res://scenes/ui/squiggle.gdshader",
]
const STARTUP_RESOURCE_PATHS := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/intro.tscn",
	"res://scenes/game.tscn",
	"res://scenes/ui/lobby.tscn",
	"res://assets/resources/audio/sfx_bank.tres",
	"res://assets/resources/default_transition.tres",
]
# Pre-warm map scenes at startup so entering a match doesn't hitch on a big
# synchronous load. Loading is spread one map per frame to avoid stalling.
const STARTUP_MAP_PATHS := [
	"res://scenes/maps/moon.tscn",
	"res://scenes/maps/city.tscn",
	"res://scenes/maps/maze_map.tscn",
]

# Autoload for passing data between lobby and game scenes

enum GameMode { NONE, HOST, JOIN, PRACTICE, SOLO, TUTORIAL }

var game_mode: GameMode = GameMode.NONE
var pending_players: Array = []
var pending_settings: Dictionary = {}
var is_online_game: bool = false
var menu_pause_local: bool = false
var end_screen_data: Dictionary = {}

# Starter crop selection (persisted)
var starter_crops: Array[String] = []
var pending_starter_crops: Array[String] = []

var train_last_hero: String = ""
const SECRET_USERNAME := "DINGUS"
const SECRET_HERO := "AnderDingus"
const MAX_USERNAME_LEN := 15

# Scene transition tracking
var is_first_load: bool = true
var _transition_layer: CanvasLayer = null
var _transition_overlay: ColorRect = null
var _transition_mat: ShaderMaterial = null
var _transition_duration: float = 0.5
var _transitioning: bool = false
var _transition_settings: TransitionSettings = null
var _menu_theme: AudioStreamPlayer = null
var _heroes_warming: bool = false
var _heroes_warmed: bool = false
var _startup_warming: bool = false
var _startup_warmed: bool = false
var _maps_warmed: bool = false
# Strong refs so warmed scenes (and their texture deps) don't get GC'd
# between warmup and use; otherwise Godot re-loads them on first match entry.
var _warmed_maps: Dictionary = {}
var _warmed_resources: Dictionary = {}
const MAX_TEX_SIZE := 16384
signal startup_step(step: String)

func _ready() -> void:
	_load_intro_flag()
	_create_transition_overlay()
	_load_starter_crops()
	_load_train_hero()
	_create_menu_theme_player()
	call_deferred("_warm_startup_async")

func _create_transition_overlay() -> void:
	_transition_settings = load("res://assets/resources/default_transition.tres")
	
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "TransitionLayer"
	_transition_layer.layer = 100
	
	_transition_overlay = ColorRect.new()
	_transition_overlay.name = "TransitionOverlay"
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.color = Color.BLACK
	_transition_overlay.visible = false
	_transition_overlay.light_mask = 0
	
	var shader = load("res://assets/shaders/scene_wipe.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("progress", 0.0)
		_apply_transition_settings(mat)
		_transition_overlay.material = mat
		_transition_mat = mat
	
	call_deferred("_add_overlay_to_root")

func _apply_transition_settings(mat: ShaderMaterial) -> void:
	if not _transition_settings:
		return
	var tex: Texture2D = _transition_settings.sheet_texture
	if tex == null:
		var loaded = load("res://assets/ui/chubbs-sheet.png")
		if loaded is Texture2D:
			tex = loaded
	var fsize: Vector2 = Vector2(_transition_settings.frame_size)
	if fsize.x <= 0.0 or fsize.y <= 0.0:
		fsize = Vector2(1920.0, 1080.0)
	var safe: Dictionary = _safe_transition_sheet(tex, fsize)
	var st: Variant = safe.get("tex", null)
	if st is Texture2D:
		tex = st
	else:
		tex = null
	var new_frame: Variant = safe.get("frame", fsize)
	if new_frame is Vector2:
		fsize = new_frame
	var fcount = maxi(1, int(_transition_settings.frame_count))
	mat.set_shader_parameter("feather", _transition_settings.feather)
	mat.set_shader_parameter("direction", _transition_settings.direction)
	mat.set_shader_parameter("use_texture", _transition_settings.use_texture)
	mat.set_shader_parameter("custom_texture", tex)
	mat.set_shader_parameter("frame_size", fsize)
	mat.set_shader_parameter("frame_count", fcount)
	mat.set_shader_parameter("frame_index", 0)

func _safe_transition_sheet(tex: Variant, frame: Vector2) -> Dictionary:
	if tex == null or not (tex is Texture2D):
		return {"tex": null, "frame": frame}
	var src_tex: Texture2D = tex as Texture2D
	var tw: int = src_tex.get_width()
	var th: int = src_tex.get_height()
	if tw > 0 and th > 0 and tw <= MAX_TEX_SIZE and th <= MAX_TEX_SIZE:
		return {"tex": src_tex, "frame": frame}
	var img: Image = src_tex.get_image()
	if img == null:
		return {"tex": null, "frame": frame}
	if img.is_compressed():
		if img.decompress() != OK:
			return {"tex": null, "frame": frame}
	tw = img.get_width()
	th = img.get_height()
	if tw <= 0 or th <= 0:
		return {"tex": null, "frame": frame}
	var scale: float = minf(1.0, minf(float(MAX_TEX_SIZE) / float(tw), float(MAX_TEX_SIZE) / float(th)))
	if scale < 1.0:
		var nw: int = maxi(1, int(roundf(float(tw) * scale)))
		var nh: int = maxi(1, int(roundf(float(th) * scale)))
		img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var out: ImageTexture = ImageTexture.create_from_image(img)
	var out_frame: Vector2 = frame * scale
	out_frame.x = maxf(1.0, roundf(out_frame.x))
	out_frame.y = maxf(1.0, roundf(out_frame.y))
	return {"tex": out, "frame": out_frame}

func _set_transition_cover_t(t: float) -> void:
	if _transition_mat:
		_transition_mat.set_shader_parameter("progress", clamp(t, 0.0, 1.0))
		var fps = maxf(1.0, float(_transition_settings.fps))
		var fcount = maxi(1, int(_transition_settings.frame_count))
		var f := int(floor(clamp(t, 0.0, 1.0) * _transition_duration * fps))
		_transition_mat.set_shader_parameter("frame_index", mini(f, fcount - 1))

func _set_transition_reveal_t(t: float) -> void:
	if _transition_mat:
		_transition_mat.set_shader_parameter("progress", 1.0 - clamp(t, 0.0, 1.0))
		var fcount = maxi(1, int(_transition_settings.frame_count))
		_transition_mat.set_shader_parameter("frame_index", fcount - 1)

func _add_overlay_to_root() -> void:
	get_tree().root.add_child(_transition_layer)
	_transition_layer.add_child(_transition_overlay)

func _create_menu_theme_player() -> void:
	if _menu_theme != null:
		return
	_menu_theme = AudioStreamPlayer.new()
	_menu_theme.name = "MenuTheme"
	_menu_theme.stream = MENU_THEME
	_menu_theme.volume_db = -12.0
	add_child(_menu_theme)

func ensure_menu_theme() -> void:
	if _menu_theme == null:
		_create_menu_theme_player()
	if _menu_theme and not _menu_theme.playing:
		_menu_theme.play()

func stop_menu_theme() -> void:
	if _menu_theme and _menu_theme.playing:
		_menu_theme.stop()

func set_mode(mode: GameMode) -> void:
	game_mode = mode
	is_online_game = mode == GameMode.HOST or mode == GameMode.JOIN

func set_online_game(players: Array, settings: Dictionary) -> void:
	pending_players = players
	pending_settings = settings
	is_online_game = true

func clear() -> void:
	pending_players.clear()
	pending_settings.clear()
	pending_starter_crops.clear()
	is_online_game = false
	menu_pause_local = false
	game_mode = GameMode.NONE
	end_screen_data.clear()

func set_end_screen_data(data: Dictionary) -> void:
	end_screen_data = data.duplicate(true)

func consume_end_screen_data() -> Dictionary:
	var data := end_screen_data.duplicate(true)
	end_screen_data.clear()
	return data

func _load_starter_crops() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var saved = config.get_value("crops", "starters", [])
		starter_crops.assign(saved)

func save_starter_crops() -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("crops", "starters", Array(starter_crops))
	config.save("user://settings.cfg")

func _load_train_hero() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		train_last_hero = _norm_train_hero(str(config.get_value("train", "last_hero", "")))

func save_train_hero() -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("train", "last_hero", train_last_hero)
	config.save("user://settings.cfg")

func set_train_last_hero(game_id: String) -> void:
	train_last_hero = _norm_train_hero(game_id)
	save_train_hero()

func train_hero_for_game() -> String:
	var hero := TestConfig.DEFAULT_HERO if train_last_hero.is_empty() else _norm_train_hero(train_last_hero)
	return resolve_hero_for_username(get_local_username(), hero)

func _norm_train_hero(hero_id: String) -> String:
	return HeroRegistry.canonical(hero_id)

func resolve_hero_for_username(username: String, hero_id: String) -> String:
	if is_secret_username(username):
		return SECRET_HERO
	if hero_id == SECRET_HERO:
		return TestConfig.DEFAULT_HERO
	return hero_id

func is_secret_username(username: String) -> bool:
	return normalize_username(username).to_upper() == SECRET_USERNAME

func get_local_username() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return ""
	return normalize_username(str(cfg.get_value("player", "username", "")))

func ui_lower(value: Variant) -> String:
	return str(value).to_lower()

func normalize_username(raw: String) -> String:
	var name := raw.strip_edges().to_lower()
	if name.length() > MAX_USERNAME_LEN:
		name = name.substr(0, MAX_USERNAME_LEN)
	return name

func ensure_username(raw: String, fallback_prefix: String = "player") -> String:
	var name := normalize_username(raw)
	if name.is_empty():
		name = "%s%d" % [normalize_username(fallback_prefix), randi() % 1000]
	return normalize_username(name)

const DEFAULT_STARTERS: Array[String] = ["BlastBerry"]

func get_active_starters() -> Array[String]:
	if not pending_starter_crops.is_empty():
		return pending_starter_crops
	if not starter_crops.is_empty():
		return starter_crops
	return DEFAULT_STARTERS

func change_scene(path: String, duration: float = -1.0) -> void:
	if _needs_hero_warm(path):
		await ensure_heroes_warmed()
	if path == "res://scenes/game.tscn":
		await ensure_maps_warmed()
	if duration < 0:
		duration = _transition_settings.duration if _transition_settings else 0.5
	if _transitioning:
		return
	_transitioning = true
	
	if _transition_mat == null:
		get_tree().change_scene_to_file(path)
		_transitioning = false
		return
	
	# Wipe to cover screen
	_transition_overlay.visible = true
	_transition_duration = duration
	_set_transition_cover_t(0.0)
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_transition_cover_t, 0.0, 1.0, duration)
	await tween.finished
	
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Wipe to reveal new scene
	var tween2 = create_tween()
	tween2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween2.tween_method(_set_transition_reveal_t, 0.0, 1.0, duration)
	await tween2.finished
	
	_transition_overlay.visible = false
	_transitioning = false

func _needs_hero_warm(path: String) -> bool:
	return path == "res://scenes/ui/lobby.tscn" or path == "res://scenes/game.tscn"

func _warm_startup_async() -> void:
	await ensure_startup_warmed()

func ensure_startup_warmed() -> void:
	if _startup_warmed:
		return
	if _startup_warming:
		while _startup_warming:
			await get_tree().process_frame
		return
	_startup_warming = true

	startup_step.emit("loading players")
	await ensure_heroes_warmed()

	startup_step.emit("loading shaders")
	_warm_shaders()
	await get_tree().process_frame

	startup_step.emit("loading resources")
	_warm_resources()
	await get_tree().process_frame

	startup_step.emit("loading maps")
	await ensure_maps_warmed()

	startup_step.emit("finishing up")
	_startup_warming = false
	_startup_warmed = true

func _warm_shaders() -> void:
	for path in STARTUP_SHADER_PATHS:
		load(path)

func _warm_resources() -> void:
	for path in STARTUP_RESOURCE_PATHS:
		var res := load(path)
		# Hold a strong ref so the cached resource (and its deps) survive
		# until they're actually used; otherwise Godot drops them and we pay
		# the load cost again on first use.
		if res != null:
			_warmed_resources[path] = res

func ensure_maps_warmed() -> void:
	if _maps_warmed:
		return
	for path in STARTUP_MAP_PATHS:
		var scene := load(path)
		if scene != null:
			_warmed_maps[path] = scene
		await get_tree().process_frame
	_maps_warmed = true

func get_warmed_map(path: String) -> PackedScene:
	var scene = _warmed_maps.get(path, null)
	if scene is PackedScene:
		return scene
	return null

func ensure_heroes_warmed() -> void:
	if _heroes_warmed:
		return
	if _heroes_warming:
		while _heroes_warming:
			await get_tree().process_frame
		return
	_heroes_warming = true
	for hero_id in HeroRegistry.ids():
		HeroRegistry.warm_scene(str(hero_id))
		await get_tree().process_frame
	_heroes_warming = false
	_heroes_warmed = true

func mark_intro_seen() -> void:
	if not is_first_load:
		return
	is_first_load = false
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("app", "intro_seen", true)
	cfg.save("user://settings.cfg")

func _load_intro_flag() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		is_first_load = true
		return
	var seen := bool(cfg.get_value("app", "intro_seen", false))
	is_first_load = not seen

func set_transition_settings(settings: TransitionSettings) -> void:
	_transition_settings = settings
	if _transition_mat:
		_apply_transition_settings(_transition_mat)

func load_transition_settings(path: String) -> void:
	var settings = load(path)
	if settings is TransitionSettings:
		set_transition_settings(settings)
