extends Node

const TransitionSettings = preload("res://scripts/globals/transition_settings.gd")
const MENU_THEME = preload("res://assets/sound/mainthemev2.wav")

# Autoload for passing data between lobby and game scenes

enum GameMode { NONE, HOST, JOIN, PRACTICE, SOLO, TUTORIAL }

var game_mode: GameMode = GameMode.NONE
var pending_players: Array = []
var pending_settings: Dictionary = {}
var is_online_game: bool = false

# Starter crop selection (persisted)
var starter_crops: Array[String] = []
var pending_starter_crops: Array[String] = []

var train_last_hero: String = ""
const TRAIN_HERO_ALIAS := {
	"Anime Girl": "AnimeGirl",
	"Xyler and Fergus": "XylerFergus",
	"Elon. Musk.": "ElonMusk",
	"Alien": "AnimeGirl",
	"Xyler": "XylerFergus",
	"Fergus": "XylerFergus",
}

# Scene transition tracking
var is_first_load: bool = true
var _transition_layer: CanvasLayer = null
var _transition_overlay: ColorRect = null
var _transition_mat: ShaderMaterial = null
var _transition_duration: float = 0.5
var _transitioning: bool = false
var _transition_settings: TransitionSettings = null
var _menu_theme: AudioStreamPlayer = null

func _ready() -> void:
	_create_transition_overlay()
	_load_starter_crops()
	_load_train_hero()
	_create_menu_theme_player()

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
	var tex = _transition_settings.sheet_texture
	if tex == null:
		tex = load("res://assets/ui/chubbs-sheet.png")
	var fsize = Vector2(_transition_settings.frame_size)
	if fsize.x <= 0.0 or fsize.y <= 0.0:
		fsize = Vector2(1920.0, 1080.0)
	var fcount = maxi(1, int(_transition_settings.frame_count))
	mat.set_shader_parameter("feather", _transition_settings.feather)
	mat.set_shader_parameter("direction", _transition_settings.direction)
	mat.set_shader_parameter("use_texture", _transition_settings.use_texture)
	mat.set_shader_parameter("custom_texture", tex)
	mat.set_shader_parameter("frame_size", fsize)
	mat.set_shader_parameter("frame_count", fcount)
	mat.set_shader_parameter("frame_index", 0)

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
	game_mode = GameMode.NONE

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
	if train_last_hero.is_empty():
		return TestConfig.DEFAULT_HERO
	return _norm_train_hero(train_last_hero)

func _norm_train_hero(hero_id: String) -> String:
	return TRAIN_HERO_ALIAS.get(hero_id, hero_id)

const DEFAULT_STARTERS: Array[String] = ["BlastBerry"]

func get_active_starters() -> Array[String]:
	if not pending_starter_crops.is_empty():
		return pending_starter_crops
	if not starter_crops.is_empty():
		return starter_crops
	return DEFAULT_STARTERS

func change_scene(path: String, duration: float = -1.0) -> void:
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
	
	# Change scene
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

func mark_intro_seen() -> void:
	is_first_load = false

func set_transition_settings(settings: TransitionSettings) -> void:
	_transition_settings = settings
	if _transition_mat:
		_apply_transition_settings(_transition_mat)

func load_transition_settings(path: String) -> void:
	var settings = load(path)
	if settings is TransitionSettings:
		set_transition_settings(settings)
