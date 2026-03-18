extends Node2D

signal kick_requested(player_id: int)

const HERO_SCENE_MAP := {
	"Dealer": "res://scenes/heroes/dealer/dealer.tscn",
	"Burple": "res://scenes/heroes/burple.tscn",
	"ElonMusk": "res://scenes/heroes/alien.tscn",
	"XylerFergus": "res://scenes/heroes/xyler.tscn",
	"LoanShark": "res://scenes/heroes/loanshark.tscn",
	"Gooblin": "res://scenes/heroes/gooblin/gooblin.tscn",
	"Garebare": "res://scenes/heroes/garebare.tscn",
}
static var _portrait_cache: Dictionary = {}

@onready var on_node: Node2D = $on
@onready var off_sprite: Sprite2D = $off
@onready var hero_portrait: Sprite2D = $on/HeroPortrait
@onready var username_label: Label = $on/LabelBand/UserName
@onready var ready_ind: Sprite2D = $on/readyIndicator
@onready var host_ind: Sprite2D = $on/HostIndicator
@onready var static_overlay: Sprite2D = $on/staticoverlay
@onready var kick_btn = $kickButton

var pid: int = -1

func _ready() -> void:
	turn_off()

func turn_on(username: String, is_host: bool) -> void:
	on_node.show()
	off_sprite.hide()
	username_label.text = username
	host_ind.visible = is_host
	ready_ind.modulate = Color(0.5, 0.5, 0.5)
	static_overlay.visible = true

func turn_off() -> void:
	on_node.hide()
	off_sprite.show()
	hero_portrait.texture = null
	kick_btn.visible = false
	pid = -1

func show_hero(hero_name: String, preview := false) -> void:
	if hero_name.is_empty():
		hero_portrait.texture = null
		static_overlay.visible = true
		return
	hero_portrait.texture = _get_portrait(hero_name)
	hero_portrait.modulate.a = 0.5 if preview else 1.0
	static_overlay.visible = preview

func set_ready(ready: bool) -> void:
	ready_ind.modulate = Color(0.3, 1.0, 0.3) if ready else Color(0.5, 0.5, 0.5)

func show_kick(vis: bool) -> void:
	kick_btn.visible = vis

func _get_portrait(hero_name: String) -> Texture2D:
	if hero_name in _portrait_cache:
		return _portrait_cache[hero_name]
	var path = HERO_SCENE_MAP.get(hero_name, "")
	if path.is_empty():
		return null
	var scene = load(path)
	if scene == null:
		return null
	var inst = scene.instantiate()
	var tex = inst.normal_portrait if inst.get("normal_portrait") else null
	inst.free()
	_portrait_cache[hero_name] = tex
	return tex

func _on_kick_button_pressed() -> void:
	if pid >= 0:
		kick_requested.emit(pid)
