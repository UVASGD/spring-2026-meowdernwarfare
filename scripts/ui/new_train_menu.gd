extends Control

const HEROES: Array[HeroInfo] = [
	preload("res://assets/resources/heroes/dealer.tres"),
	preload("res://assets/resources/heroes/burple.tres"),
	preload("res://assets/resources/heroes/animegirl.tres"),
	preload("res://assets/resources/heroes/xylerfergus.tres"),
	preload("res://assets/resources/heroes/loanshark.tres"),
	preload("res://assets/resources/heroes/gooblin.tres"),
	preload("res://assets/resources/heroes/garebare.tres"),
	preload("res://assets/resources/heroes/elonmusk.tres"),
]

@onready var char_bg: ColorRect = $Control/mask/sliding_charbg
@onready var back_btn: Button = $HitButtons/BackButton
@onready var tutorial_btn: Button = $HitButtons/TutorialButton
@onready var vs_ai_btn: Button = $HitButtons/VsAiButton
@onready var solo_btn: Button = $HitButtons/SoloButton
@onready var hero_buttons: Array[SpriteButton] = [
	$Frame1,
	$Frame2,
	$Frame3,
	$Frame4,
	$Frame5,
	$Frame6,
	$Frame7,
	$Frame8,
]

var selected_hero := ""
var active_panel: ColorRect = null
var active_frame: SpriteButton = null

const PANEL_IN_X := 140.0
const PANEL_OUT_X := 857.0
const SLIDE_TIME := 0.32


func _ready() -> void:
	char_bg.visible = false
	back_btn.pressed.connect(_on_back)
	tutorial_btn.pressed.connect(_on_tutorial)
	vs_ai_btn.pressed.connect(_on_vs_ai)
	solo_btn.pressed.connect(_on_solo)

	for i in mini(hero_buttons.size(), HEROES.size()):
		hero_buttons[i].pressed.connect(_select.bind(HEROES[i]))

	_restore_last_hero()


func _restore_last_hero() -> void:
	if GameData.train_last_hero.is_empty():
		_select(HEROES[0])
		return

	for info in HEROES:
		if HeroRegistry.canonical(info.id) == GameData.train_last_hero:
			_select(info)
			return

	_select(HEROES[0])


func _select(info: HeroInfo) -> void:
	if selected_hero == info.id:
		_update_frame_state(info)
		return

	selected_hero = info.id
	GameData.set_train_last_hero(HeroRegistry.canonical(info.id))
	_update_frame_state(info)

	var panel := _make_panel(info)
	$Control/mask.add_child(panel)
	panel.position.x = PANEL_OUT_X
	panel.visible = true

	var old_panel := active_panel
	active_panel = panel

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "position:x", PANEL_IN_X, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if old_panel and is_instance_valid(old_panel):
		tw.tween_property(old_panel, "position:x", -old_panel.size.x, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.set_parallel(false)
		tw.tween_callback(old_panel.queue_free)


func _update_frame_state(info: HeroInfo) -> void:
	for i in mini(hero_buttons.size(), HEROES.size()):
		if HEROES[i] == info:
			hero_buttons[i].set_on()
			active_frame = hero_buttons[i]
		else:
			hero_buttons[i].set_off()


func _make_panel(info: HeroInfo) -> ColorRect:
	var panel := char_bg.duplicate(DUPLICATE_USE_INSTANTIATION) as ColorRect
	panel.color = info.portrait_outline_color
	panel.name = "InfoPanel_%s" % HeroRegistry.canonical(info.id)

	var title := panel.get_node("InfoPanel/Scroll/Content/HeroName") as Label
	var desc := panel.get_node("InfoPanel/Scroll/Content/HeroDesc") as RichTextLabel
	var shoot := panel.get_node("InfoPanel/Scroll/Content/ShootSection") as VBoxContainer
	var ability1 := panel.get_node("InfoPanel/Scroll/Content/Ability1Section") as VBoxContainer
	var ability2 := panel.get_node("InfoPanel/Scroll/Content/Ability2Section") as VBoxContainer
	var ult := panel.get_node("InfoPanel/Scroll/Content/UltSection") as VBoxContainer

	title.text = GameData.ui_lower(info.id)
	desc.text = GameData.ui_lower(info.desc)

	_set_section(shoot, info.shoot_name, info.shoot_desc, info.shoot_video)
	_set_section(ability1, info.ability1_name, info.ability1_desc, info.ability1_video)
	_set_section(ability2, info.ability2_name, info.ability2_desc, info.ability2_video)
	ability2.visible = info.ability2_name != ""
	_set_section(ult, info.ult_name, info.ult_desc, info.ult_video)
	return panel


func _set_section(section: VBoxContainer, skill_name: String, skill_desc: String, video: VideoStream) -> void:
	section.visible = true
	section.get_node("Title").text = GameData.ui_lower(skill_name)
	section.get_node("Desc").text = GameData.ui_lower(skill_desc)

	var label := section.get_node("Video/Label") as Label
	var player := section.get_node("Video/Fit/Player") as VideoStreamPlayer
	player.loop = true
	player.autoplay = true

	if video == null:
		player.stop()
		player.stream = null
		player.visible = false
		label.visible = true
		return

	label.visible = false
	player.visible = true
	player.stream = video
	player.play()

	var cb := Callable(self, "_on_video_finished").bind(player)
	if not player.finished.is_connected(cb):
		player.finished.connect(cb)


func _on_video_finished(player: VideoStreamPlayer) -> void:
	if is_instance_valid(player) and player.visible and player.stream:
		player.play()


func _on_back() -> void:
	GameData.change_scene("res://scenes/ui/main_menu.tscn")


func _on_tutorial() -> void:
	GameData.set_mode(GameData.GameMode.TUTORIAL)
	GameData.change_scene("res://scenes/game.tscn")


func _on_vs_ai() -> void:
	GameData.set_mode(GameData.GameMode.PRACTICE)
	GameData.change_scene("res://scenes/game.tscn")


func _on_solo() -> void:
	GameData.set_mode(GameData.GameMode.SOLO)
	GameData.change_scene("res://scenes/game.tscn")
