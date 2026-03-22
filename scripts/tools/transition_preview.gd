@tool
extends Control

@export var settings: TransitionSettings:
	set(v):
		settings = v
		_apply_settings()

@export_range(0.0, 1.0) var preview_progress: float = 0.0:
	set(v):
		preview_progress = v
		_update_progress()

@export var play_preview: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_play_preview()

@export var save_as_default: bool = false:
	set(v):
		if v and settings:
			ResourceSaver.save(settings, "res://assets/resources/default_transition.tres")
			print("Saved transition settings to res://assets/resources/default_transition.tres")

var _overlay: ColorRect
var _tween: Tween

func _ready() -> void:
	_create_overlay()
	_apply_settings()

func _create_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color.BLACK
	
	var shader = load("res://assets/shaders/scene_wipe.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("progress", 0.0)
		_overlay.material = mat
	
	add_child(_overlay)

func _apply_settings() -> void:
	if not _overlay or not _overlay.material:
		return
	
	var mat = _overlay.material as ShaderMaterial
	if not mat or not settings:
		return
	
	mat.set_shader_parameter("direction", settings.direction)
	mat.set_shader_parameter("feather", settings.feather)
	mat.set_shader_parameter("use_texture", settings.use_texture)
	mat.set_shader_parameter("custom_texture", settings.sheet_texture)
	mat.set_shader_parameter("frame_size", Vector2(settings.frame_size))
	mat.set_shader_parameter("frame_count", settings.frame_count)
	mat.set_shader_parameter("frame_index", 0)

func _update_progress() -> void:
	if not _overlay or not _overlay.material:
		return
	var mat = _overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", preview_progress)
		if settings:
			var f := int(floor(preview_progress * settings.duration * settings.fps))
			mat.set_shader_parameter("frame_index", mini(f, settings.frame_count - 1))

func _play_preview() -> void:
	if _tween:
		_tween.kill()
	
	var dur = settings.duration if settings else 0.5
	
	_tween = create_tween()
	_tween.tween_property(self, "preview_progress", 1.0, dur).from(0.0)
	_tween.tween_property(self, "preview_progress", 0.0, dur)
