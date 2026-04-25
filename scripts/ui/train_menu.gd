extends Control

const TRAIN_TO_GAME := {
	"Anime Girl": "AnimeGirl",
	"Xyler and Fergus": "XylerFergus",
	"Elon. Musk.": "ElonMusk",
}

const _DEFAULT_HEROES: Array[HeroInfo] = [
	preload("res://assets/resources/heroes/dealer.tres"),
	preload("res://assets/resources/heroes/burple.tres"),
	preload("res://assets/resources/heroes/animegirl.tres"),
	preload("res://assets/resources/heroes/xylerfergus.tres"),
	preload("res://assets/resources/heroes/loanshark.tres"),
	preload("res://assets/resources/heroes/gooblin.tres"),
	preload("res://assets/resources/heroes/garebare.tres"),
	preload("res://assets/resources/heroes/elonmusk.tres"),
]

@export var heroes: Array[HeroInfo] = []

@onready var back_btn: Button = $Margin/VBox/TopBar/BackBtn
@onready var tutorial_btn: Button = $Margin/VBox/TopBar/TutorialBtn
@onready var vsai_btn: Button = $Margin/VBox/TopBar/VsAIBtn
@onready var solo_btn: Button = $Margin/VBox/TopBar/SoloBtn

@onready var hero_grid: GridContainer = $Margin/VBox/Content/HeroGridScroll/HeroGrid
@onready var portrait: TextureRect = $Margin/VBox/Content/SidePanel/Scroll/PanelContent/Portrait
@onready var hero_name_label: Label = $Margin/VBox/Content/SidePanel/Scroll/PanelContent/HeroName
@onready var hero_desc: RichTextLabel = $Margin/VBox/Content/SidePanel/Scroll/PanelContent/HeroDesc
@onready var shoot_section: VBoxContainer = $Margin/VBox/Content/SidePanel/Scroll/PanelContent/ShootSection
@onready var ability1_section: VBoxContainer = $Margin/VBox/Content/SidePanel/Scroll/PanelContent/Ability1Section
@onready var ability2_section: VBoxContainer = $Margin/VBox/Content/SidePanel/Scroll/PanelContent/Ability2Section
@onready var ult_section: VBoxContainer = $Margin/VBox/Content/SidePanel/Scroll/PanelContent/UltSection

var selected_hero: String = ""

func _ready() -> void:
	if heroes.is_empty():
		heroes = _DEFAULT_HEROES.duplicate()

	back_btn.pressed.connect(_on_back)
	tutorial_btn.pressed.connect(_on_tutorial)
	vsai_btn.pressed.connect(_on_vs_ai)
	solo_btn.pressed.connect(_on_solo)
	_populate_hero_grid()
	_restore_last_hero_ui()

func _game_id(info: HeroInfo) -> String:
	return TRAIN_TO_GAME.get(info.id, info.id)

func _restore_last_hero_ui() -> void:
	if GameData.train_last_hero.is_empty():
		return
	for info in heroes:
		if _game_id(info) == GameData.train_last_hero:
			_on_hero_selected(info)
			break

func _populate_hero_grid() -> void:
	for info in heroes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 140)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = GameData.ui_lower(info.id)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.pressed.connect(_on_hero_selected.bind(info))

		if info.portrait:
			btn.icon = info.portrait
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			btn.expand_icon = true

		hero_grid.add_child(btn)

func _on_hero_selected(info: HeroInfo) -> void:
	selected_hero = info.id
	GameData.set_train_last_hero(_game_id(info))

	if info.portrait:
		portrait.texture = info.portrait
		portrait.visible = true
	else:
		portrait.texture = null
		portrait.visible = false

	hero_name_label.text = GameData.ui_lower(info.id)
	hero_desc.text = GameData.ui_lower(info.desc)

	_update_skill_section(shoot_section, info.shoot_name, info.shoot_desc, info.shoot_video)
	_update_skill_section(ability1_section, info.ability1_name, info.ability1_desc, info.ability1_video)
	if info.ability2_name != "":
		_update_skill_section(ability2_section, info.ability2_name, info.ability2_desc, info.ability2_video)
	else:
		_set_skill_video(ability2_section, null)
		ability2_section.visible = false
	_update_skill_section(ult_section, info.ult_name, info.ult_desc, info.ult_video)

func _update_skill_section(section: VBoxContainer, skill_name: String, skill_desc: String, skill_video: VideoStream) -> void:
	section.visible = true
	section.get_node("Title").text = GameData.ui_lower(skill_name)
	section.get_node("Desc").text = GameData.ui_lower(skill_desc)
	_set_skill_video(section, skill_video)

func _set_skill_video(section: VBoxContainer, skill_video: VideoStream) -> void:
	var video_label := section.get_node("Video/Label") as Label
	var player := section.get_node("Video/Fit/Player") as VideoStreamPlayer
	player.loop = true
	player.autoplay = true

	if skill_video == null:
		player.stop()
		player.stream = null
		player.visible = false
		video_label.visible = true
		return

	video_label.visible = false
	player.visible = true
	player.stream = skill_video
	player.play()

	var cb := Callable(self, "_on_skill_video_finished").bind(player)
	if not player.finished.is_connected(cb):
		player.finished.connect(cb)

func _on_skill_video_finished(player: VideoStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	if not player.visible:
		return
	if player.stream == null:
		return
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
