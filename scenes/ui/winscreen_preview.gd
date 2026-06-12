extends Node

const WinScreenScene = preload("res://scenes/ui/gamewinscreen.tscn")
#const HeroScene = preload("res://scenes/heroes/elonmusk/elonmusk.tscn")
#const HeroScene = preload("res://scenes/heroes/anderdingus/anderdingus.tscn")
#const HeroScene = preload("res://scenes/heroes/animegirl/animegirl.tscn")
#const HeroScene = preload("res://scenes/heroes/burple/burple.tscn")
#const HeroScene = preload("res://scenes/heroes/dealer/dealer.tscn")
#const HeroScene = preload("res://scenes/heroes/garebare/garebare.tscn")
#const HeroScene = preload("res://scenes/heroes/gooblin/gooblin.tscn")
#const HeroScene = preload("res://scenes/heroes/loanshark/loanshark.tscn")
const HeroScene = preload("res://scenes/heroes/xylerfergus/xylerfergus.tscn")
var _hero: Hero

func _ready() -> void:
	_hero = HeroScene.instantiate()
	var ws = WinScreenScene.instantiate()
	ws.winner_hero = _hero
	ws.winner_name = "vince"
	add_child(ws)
