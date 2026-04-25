extends Node

const WinScreenScene = preload("res://scenes/ui/gamewinscreen.tscn")
const HeroScene = preload("res://scenes/heroes/elonmusk/elonmusk.tscn")

var _hero: Hero

func _ready() -> void:
	_hero = HeroScene.instantiate()
	var ws = WinScreenScene.instantiate()
	ws.winner_hero = _hero
	ws.winner_name = "vince"
	add_child(ws)
