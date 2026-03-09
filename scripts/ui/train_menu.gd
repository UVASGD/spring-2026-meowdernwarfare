extends Control

const _DEFAULT_HEROES: Array[HeroInfo] = [
	preload("res://assets/resources/heroes/dealer.tres"),
	preload("res://assets/resources/heroes/burple.tres"),
	preload("res://assets/resources/heroes/alien.tres"),
	preload("res://assets/resources/heroes/xylerfergus.tres"),
	preload("res://assets/resources/heroes/loanshark.tres"),
	preload("res://assets/resources/heroes/gooblin.tres"),
	preload("res://assets/resources/heroes/garebare.tres"),
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

func _populate_hero_grid() -> void:
	for info in heroes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 140)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = info.id
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

	if info.portrait:
		portrait.texture = info.portrait
		portrait.visible = true
	else:
		portrait.texture = null
		portrait.visible = false

	hero_name_label.text = info.id
	hero_desc.text = info.desc

	_update_skill_section(shoot_section, info.shoot_name, info.shoot_desc)
	_update_skill_section(ability1_section, info.ability1_name, info.ability1_desc)
	if info.ability2_name != "":
		_update_skill_section(ability2_section, info.ability2_name, info.ability2_desc)
	else:
		ability2_section.visible = false
	_update_skill_section(ult_section, info.ult_name, info.ult_desc)

func _update_skill_section(section: VBoxContainer, skill_name: String, skill_desc: String) -> void:
	section.visible = true
	section.get_node("Title").text = skill_name
	section.get_node("Desc").text = skill_desc

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
