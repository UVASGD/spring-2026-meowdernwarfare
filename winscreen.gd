extends Control

signal leaderboard_requested

@export var hero_portrait: Texture2D
@export var hero_color: Color
@export var portrait_bg: Texture2D
@export var winner_name: String
@export var winner_hero: Hero
@export var initial_fade_time: float = 1.15
@export var parallax_smooth: float = 10.0
@export var portrait_shift: Vector2 = Vector2(40.0, 24.0)
@export var shadow_shift: Vector2 = Vector2(72.0, 40.0)
@export var text_shift: Vector2 = Vector2(18.0, 10.0)
@export var portrait_bg_spin_speed: float = 0.16
@export var name_swipe_delay: float = 1.5
@export var name_swipe_dist: float = 700.0
@export var name_swipe_time: float = 0.55

@onready var black_bg: ColorRect = $blackBG
@onready var fallback_bg: ColorRect = $fallbackBG
@onready var portrait_bg_node: TextureRect = $portraitBG
@onready var winner: Label = $Winner
@onready var winnerusername: Label = $winnerusername
@onready var winnerheroname: Label = $winnerheroname
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var portraitshadow: TextureRect = $portraitshadow
@onready var portrait: TextureRect = $portrait

var _running := true
var _parallax_on := false
var _portrait_base := Vector2.ZERO
var _shadow_base := Vector2.ZERO
var _winner_base := Vector2.ZERO
var _username_base := Vector2.ZERO
var _hero_name_base := Vector2.ZERO
var _username_swipe := 0.0
var _hero_name_swipe := 0.0
var _portrait_off := Vector2.ZERO
var _shadow_off := Vector2.ZERO
var _text_off := Vector2.ZERO
var _text_parallax_on := false
var _leader_rows: Array = []
var _leader_shown := false

func _ready() -> void:
	modulate.a = 0.0
	_setup_bg_cover()
	_portrait_base = portrait.position
	_shadow_base = portraitshadow.position
	_winner_base = winner.position
	_username_base = winnerusername.position
	_hero_name_base = winnerheroname.position
	_apply_data()
	prime_swipe_positions()
	_disable_anim_pos_tracks()
	animation_player.play("default")
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, initial_fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_start_name_swipe()
	_start_parallax()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_setup_bg_cover()

func _process(delta: float) -> void:
	portrait_bg_node.rotation += portrait_bg_spin_speed * delta
	if not _running or not _parallax_on:
		return
	var norm := MenuParallax.mouse_norm(get_viewport())
	if norm == Vector2.INF:
		return
	_portrait_off = MenuParallax.step(_portrait_off, norm, portrait_shift, delta, parallax_smooth)
	_shadow_off = MenuParallax.step(_shadow_off, norm, shadow_shift, delta, parallax_smooth)
	_text_off = MenuParallax.step(_text_off, norm, text_shift, delta, parallax_smooth)
	portrait.position = _portrait_base + _portrait_off
	portraitshadow.position = _shadow_base + _shadow_off
	var text_off := _text_off if _text_parallax_on else Vector2.ZERO
	winner.position = _winner_base + text_off * 0.35
	winnerusername.position = _username_base + Vector2(_username_swipe, 0) + text_off
	winnerheroname.position = _hero_name_base + Vector2(_hero_name_swipe, 0) + text_off

func _apply_data() -> void:
	var d: Dictionary = GameData.consume_end_screen_data()
	if not d.is_empty():
		winner_name = GameData.ui_lower(d.get("winner_name", winner_name))
		winnerheroname.text = GameData.ui_lower(d.get("hero_name", winnerheroname.text))
		var dc = d.get("hero_color", hero_color)
		if dc is Color:
			hero_color = dc
		var dp = d.get("hero_portrait", hero_portrait)
		if dp is Texture2D:
			hero_portrait = dp
		var dbg = d.get("portrait_bg", portrait_bg)
		if dbg is Texture2D:
			portrait_bg = dbg
		var lr = d.get("leaderboard", [])
		if lr is Array:
			_leader_rows = lr
	var h := winner_hero
	var c := hero_color
	if h != null:
		hero_portrait = h.get_hero_default_profile()
		winnerheroname.text = GameData.ui_lower(h.get_hero_name())
		c = h.portrait_outline_color
		if portrait_bg == null:
			portrait_bg = h.tv_and_win_bg
	if not winner_name.is_empty():
		winnerusername.text = GameData.ui_lower(winner_name)
	if hero_portrait != null:
		portrait.texture = hero_portrait
		portraitshadow.texture = hero_portrait
	portraitshadow.modulate = Color(0, 0, 0, 0.7)
	var has_bg := portrait_bg != null
	portrait_bg_node.visible = has_bg
	fallback_bg.visible = not has_bg
	if has_bg:
		portrait_bg_node.texture = portrait_bg
	fallback_bg.color = c
	var ls := winnerheroname.label_settings
	if ls != null:
		ls = ls.duplicate()
		ls.font_color = c
		winnerheroname.label_settings = ls
	else:
		winnerheroname.add_theme_color_override("font_color", c)

func _setup_bg_cover() -> void:
	if portrait_bg_node == null:
		return
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		s = get_viewport_rect().size
	var diag := s.length()
	var min_side := minf(s.x, s.y)
	var k := 1.0
	if min_side > 0.0:
		k = (diag / min_side) + 0.06
	portrait_bg_node.pivot_offset = s * 0.5
	portrait_bg_node.scale = Vector2(k, k)

func prime_swipe_positions() -> void:
	winnerusername.modulate.a = 0.0
	winnerheroname.modulate.a = 0.0
	_username_swipe = -name_swipe_dist
	_hero_name_swipe = name_swipe_dist

func _start_name_swipe() -> void:
	await get_tree().create_timer(name_swipe_delay).timeout
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "_username_swipe", 0.0, name_swipe_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_hero_name_swipe", 0.0, name_swipe_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(winnerusername, "modulate:a", 1.0, name_swipe_time * 0.65)
	tw.tween_property(winnerheroname, "modulate:a", 1.0, name_swipe_time * 0.65)
	await tw.finished
	_text_parallax_on = true

func _start_parallax() -> void:
	await get_tree().create_timer(1.0).timeout
	_portrait_base = portrait.position
	_shadow_base = portraitshadow.position
	_winner_base = winner.position
	_parallax_on = true

func _disable_anim_pos_tracks() -> void:
	for anim_name in ["default", "RESET"]:
		var anim := animation_player.get_animation(anim_name)
		if anim == null:
			continue
		for i in anim.get_track_count():
			var p: NodePath = anim.track_get_path(i)
			if p == NodePath("portrait:position") or p == NodePath("portraitshadow:position"):
				anim.track_set_enabled(i, false)

func show_leaderboard():
	_running = false
	_show_leaderboard_overlay()
	leaderboard_requested.emit()

func _show_leaderboard_overlay() -> void:
	if _leader_shown:
		return
	_leader_shown = true
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(500, 0)
	center.add_theme_constant_override("separation", 16)
	bg.add_child(center)
	var title = Label.new()
	title.text = "game over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(title)
	center.add_child(_build_leaderboard())
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	center.add_child(btn_row)
	var lobby_btn = Button.new()
	lobby_btn.text = "return to lobby"
	lobby_btn.custom_minimum_size = Vector2(180, 48)
	lobby_btn.pressed.connect(_on_return_to_lobby)
	btn_row.add_child(lobby_btn)
	var quit_btn = Button.new()
	quit_btn.text = "quit to menu"
	quit_btn.custom_minimum_size = Vector2(180, 48)
	quit_btn.pressed.connect(_on_quit_to_menu)
	btn_row.add_child(quit_btn)

func _build_leaderboard() -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	for col in ["#", "player", "crops", "kills", "deaths"]:
		var lbl = Label.new()
		lbl.text = col
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(lbl)
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())
	for i in _leader_rows.size():
		var p = _leader_rows[i]
		if not (p is Dictionary):
			continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var rank_l = Label.new()
		rank_l.text = str(i + 1)
		rank_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(rank_l)
		var name_l = Label.new()
		name_l.text = GameData.ui_lower(p.get("name", "player"))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var alive := bool(p.get("alive", true))
		if not alive:
			name_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(name_l)
		for key in ["crops", "kills", "deaths"]:
			var val_l = Label.new()
			val_l.text = str(p.get(key, 0))
			val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if not alive:
				val_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(val_l)
		vbox.add_child(row)
	return panel

func _on_return_to_lobby() -> void:
	if Network.is_online():
		GameData.game_mode = GameData.GameMode.HOST if Network.is_host else GameData.GameMode.JOIN
	else:
		GameData.game_mode = GameData.GameMode.NONE
	GameData.change_scene("res://scenes/ui/lobby.tscn")

func _on_quit_to_menu() -> void:
	Network.disconnect_from_server()
	GameData.change_scene("res://scenes/ui/main_menu.tscn")
