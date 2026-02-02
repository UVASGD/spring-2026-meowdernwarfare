@tool
extends Control

@export var delay: float = 1.0  # Seconds before transition starts
@export var duration: float = 1.5  # Transition duration
@export var auto_start: bool = true  # Start automatically on ready
@export var edge_color: Color = Color(1.0, 0.5, 0.1, 1.0)
@export var edge_color_inner: Color = Color(1.0, 0.9, 0.3, 1.0)
@export var edge_width: float = 0.05
@export var noise_scale: float = 1.0

@export var preview_progress: float = 1.0:  # For editor preview
	set(value):
		preview_progress = value
		if material:
			material.set_shader_parameter("progress", value)

var _tween: Tween
var _started = false

func _ready() -> void:
	_setup_material()
	
	if Engine.is_editor_hint():
		return
	
	# Start hidden
	if material:
		material.set_shader_parameter("progress", 1.0)
	
	if auto_start:
		start_reveal()

func _setup_material() -> void:
	if not material or not material is ShaderMaterial:
		return
	
	material.set_shader_parameter("edge_color", edge_color)
	material.set_shader_parameter("edge_color_inner", edge_color_inner)
	material.set_shader_parameter("edge_width", edge_width)
	material.set_shader_parameter("noise_scale", noise_scale)
	
	if Engine.is_editor_hint():
		material.set_shader_parameter("progress", preview_progress)

func start_reveal() -> void:
	if _started or Engine.is_editor_hint():
		return
	_started = true
	
	await get_tree().create_timer(delay).timeout
	
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.tween_method(_set_progress, 1.0, 0.0, duration)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

func _set_progress(value: float) -> void:
	if material:
		material.set_shader_parameter("progress", value)

func reset() -> void:
	_started = false
	if _tween:
		_tween.kill()
	if material:
		material.set_shader_parameter("progress", 1.0)
