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

# Scene transition tracking
var is_first_load: bool = true
var _transition_overlay: ColorRect = null
var _transitioning: bool = false
var _transition_settings: TransitionSettings = null
var _menu_theme: AudioStreamPlayer = null

func _ready() -> void:
	_create_transition_overlay()
	_load_starter_crops()
	_create_menu_theme_player()

func _create_transition_overlay() -> void:
	_transition_settings = load("res://assets/resources/default_transition.tres")
	
	_transition_overlay = ColorRect.new()
	_transition_overlay.name = "TransitionOverlay"
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.color = Color.BLACK
	_transition_overlay.visible = false
	
	var shader = load("res://assets/shaders/scene_wipe.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("progress", 0.0)
		_apply_transition_settings(mat)
		_transition_overlay.material = mat
	
	call_deferred("_add_overlay_to_root")

func _apply_transition_settings(mat: ShaderMaterial) -> void:
	if not _transition_settings:
		return
	mat.set_shader_parameter("feather", _transition_settings.feather)
	mat.set_shader_parameter("direction", _transition_settings.direction)
	mat.set_shader_parameter("use_texture", _transition_settings.use_texture)
	if _transition_settings.custom_texture:
		mat.set_shader_parameter("custom_texture", _transition_settings.custom_texture)

func _add_overlay_to_root() -> void:
	get_tree().root.add_child(_transition_overlay)
	_transition_overlay.z_index = 100

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
	
	var mat = _transition_overlay.material as ShaderMaterial
	if mat == null:
		get_tree().change_scene_to_file(path)
		_transitioning = false
		return
	
	# Wipe to cover screen
	_transition_overlay.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(v): mat.set_shader_parameter("progress", v), -0.2, 1.2, duration)
	await tween.finished
	
	# Change scene
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Wipe to reveal new scene
	var tween2 = create_tween()
	tween2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween2.tween_method(func(v): mat.set_shader_parameter("progress", v), 1.2, -0.2, duration)
	await tween2.finished
	
	_transition_overlay.visible = false
	_transitioning = false

func mark_intro_seen() -> void:
	is_first_load = false

func set_transition_settings(settings: TransitionSettings) -> void:
	_transition_settings = settings
	var mat = _transition_overlay.material as ShaderMaterial
	if mat:
		_apply_transition_settings(mat)

func load_transition_settings(path: String) -> void:
	var settings = load(path)
	if settings is TransitionSettings:
		set_transition_settings(settings)
