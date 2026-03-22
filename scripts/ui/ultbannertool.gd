@tool
extends CanvasGroup

@export var progress: float = 1.0:
	set(v):
		progress = clamp(v, 0.0, 1.0)
		_apply()

var mats: Array[ShaderMaterial] = []
@onready var banner: Sprite2D = $banner
@onready var portrait: Sprite2D = $banner/Sprite
@onready var username: Label = $banner/username
@onready var anim: AnimationPlayer = $AnimationPlayer
var _fading: bool = false
var _fade_tw: Tween = null

func _ready() -> void:
	_collect(self)
	_apply()
	visible = false

func _collect(n: Node) -> void:
	if n is CanvasItem:
		var m = (n as CanvasItem).material
		if m is ShaderMaterial:
			mats.append(m)
	for c in n.get_children():
		_collect(c)

func _apply() -> void:
	for m in mats:
		if m:
			m.set_shader_parameter("progress", progress)

func tween_progress(to: float, dur: float = 0.5) -> void:
	var tw = create_tween()
	tw.tween_method(_set_progress, progress, clamp(to, 0.0, 1.0), dur)

func _set_progress(v: float) -> void:
	progress = v
	_apply()

func show_ult(player: Player, player_name: String) -> void:
	if player == null or player.hero == null:
		return
	if visible:
		fadeout(true)
	_set_content(player, player_name)
	progress = 1.0
	_apply()
	visible = true
	if anim:
		anim.stop()
		anim.play("ult")

func fadeout(force: bool = false) -> void:
	if not visible:
		return
	if _fading and not force:
		return
	if _fade_tw:
		_fade_tw.kill()
		_fade_tw = null
	_fading = true
	if anim and force and anim.is_playing():
		anim.stop()
	if force:
		_set_progress(0.0)
		visible = false
		_fading = false
		return
	_fade_tw = create_tween()
	_fade_tw.tween_method(_set_progress, progress, 0.0, 0.55)
	await _fade_tw.finished
	_fade_tw = null
	visible = false
	_fading = false

func _set_content(player: Player, player_name: String) -> void:
	username.text = player_name
	var tex = player.hero.get_hero_ult_profile()
	if tex == null:
		tex = player.hero.get_hero_default_profile()
	if tex:
		portrait.texture = tex
	var c = player.hero.get_hero_ui_color()
	var m = portrait.material as ShaderMaterial
	if m:
		m.set_shader_parameter("color_a", c.lerp(Color.WHITE, 0.2))
		m.set_shader_parameter("color_b", c.lerp(Color.BLACK, 0.35))
