extends Node2D

signal kick_requested(player_id: int)

const HERO_SCENE_MAP := {
	"Dealer": "res://scenes/heroes/dealer/dealer.tscn",
	"Burple": "res://scenes/heroes/burple/burple.tscn",
	"ElonMusk": "res://scenes/heroes/elonmusk/elonmusk.tscn",
	"XylerFergus": "res://scenes/heroes/xylerfergus/xylerfergus.tscn",
	"LoanShark": "res://scenes/heroes/loanshark/loanshark.tscn",
	"Gooblin": "res://scenes/heroes/gooblin/gooblin.tscn",
	"Garebare": "res://scenes/heroes/garebare/garebare.tscn",
	"AnimeGirl": "res://scenes/heroes/animegirl/animegirl.tscn",
}
const HERO_INFO_PATH := {
	"Dealer": "res://assets/resources/heroes/dealer.tres",
	"Burple": "res://assets/resources/heroes/burple.tres",
	"ElonMusk": "res://assets/resources/heroes/elonmusk.tres",
	"XylerFergus": "res://assets/resources/heroes/xylerfergus.tres",
	"LoanShark": "res://assets/resources/heroes/loanshark.tres",
	"Gooblin": "res://assets/resources/heroes/gooblin.tres",
	"Garebare": "res://assets/resources/heroes/garebare.tres",
	"AnimeGirl": "res://assets/resources/heroes/animegirl.tres",
}
const GOOBLIN_TV_TEX := "res://assets/sprites/gooblin/Gooblin__Base_-removebg-preview.png"
const GOOBLIN_TV_OUTLINE := Color(0.917647, 0.486275, 0.341176, 1)

static var _portrait_cache: Dictionary = {}
static var _color_cache: Dictionary = {}
static var _warm_i: int = 0
static var _warm_pending: bool = false

@onready var on_node: Node2D = $on
@onready var off_sprite: Sprite2D = $off
@onready var hero_portrait: Sprite2D = $on/HeroPortrait
@onready var username_label: Label = $LabelBand/UserName
@onready var ready_ind: Sprite2D = $readyIndicator
@onready var host_ind: Sprite2D = $HostIndicator
@onready var static_overlay: Sprite2D = $on/staticoverlay
@onready var kick_btn = $kickButton
@onready var on_screen: Sprite2D = $on/onScreen
@onready var screenlight: PointLight2D = $on/screenlight


var pid: int = -1

func _ready() -> void:
	turn_off()
	if not _warm_pending:
		_warm_pending = true
		call_deferred("_warm_one_hero")


static func _ensure(hero_name: String) -> void:
	if hero_name.is_empty():
		return
	if _portrait_cache.has(hero_name) and _color_cache.has(hero_name):
		return
	if hero_name == "Gooblin":
		var gt: Texture2D = load(GOOBLIN_TV_TEX)
		_portrait_cache[hero_name] = gt
		_color_cache[hero_name] = GOOBLIN_TV_OUTLINE
		return
	var info_path: String = HERO_INFO_PATH.get(hero_name, "")
	if not info_path.is_empty():
		var info = load(info_path) as HeroInfo
		if info and info.portrait:
			_portrait_cache[hero_name] = info.portrait
			_color_cache[hero_name] = info.portrait_outline_color
			return
	_cache_from_scene(hero_name)


static func _cache_from_scene(hero_name: String) -> void:
	var path: String = HERO_SCENE_MAP.get(hero_name, "")
	if path.is_empty():
		_portrait_cache[hero_name] = null
		_color_cache[hero_name] = Color(0.5, 0.5, 0.5, 1)
		return
	var scene = load(path) as PackedScene
	if scene == null:
		_portrait_cache[hero_name] = null
		_color_cache[hero_name] = Color(0.5, 0.5, 0.5, 1)
		return
	var inst = scene.instantiate()
	var tex = inst.normal_portrait if inst.get("normal_portrait") else null
	var col = inst.portrait_outline_color if inst.get("portrait_outline_color") else Color(1, 1, 1, 1)
	inst.free()
	_portrait_cache[hero_name] = tex
	_color_cache[hero_name] = col


func _warm_one_hero() -> void:
	var keys: Array = HERO_SCENE_MAP.keys()
	if _warm_i >= keys.size():
		_warm_pending = false
		return
	_ensure(keys[_warm_i])
	_warm_i += 1
	call_deferred("_warm_one_hero")


func turn_on(username: String, is_host: bool) -> void:
	on_node.show()
	off_sprite.hide()
	username_label.text = username
	host_ind.visible = is_host
	ready_ind.modulate = Color(0.5, 0.5, 0.5)
	static_overlay.visible = true
	screenlight.energy = 11

func turn_off() -> void:
	on_node.hide()
	off_sprite.show()
	hero_portrait.texture = null
	kick_btn.visible = false
	kick_btn.disable()
	username_label.text = ""
	set_ready(false)
	pid = -1
	screenlight.energy = 0

func show_hero(hero_name: String, preview := false) -> void:
	if hero_name.is_empty():
		hero_portrait.texture = null
		static_overlay.visible = true
		return
	_ensure(hero_name)
	hero_portrait.texture = _portrait_cache.get(hero_name)
	hero_portrait.modulate.a = 0.5 if preview else 1.0
	on_screen.modulate = Color(0.5, 0.5, 0.5, 1.0) if preview else _color_cache.get(hero_name, Color(0.5, 0.5, 0.5, 1))
	screenlight.color = Color(1, 1, 1, 1) if preview else _color_cache.get(hero_name, Color(1, 1, 1, 1))
	static_overlay.visible = preview

func set_ready(ready: bool) -> void:
	ready_ind.modulate = Color(0.3, 1.0, 0.3) if ready else Color(0.0, 0.0, 0.0)

func show_kick(vis: bool) -> void:
	kick_btn.visible = vis
	if vis:
		kick_btn.enable()
	else:
		kick_btn.disable()

func _on_kick_button_pressed() -> void:
	if pid >= 0:
		kick_requested.emit(pid)
