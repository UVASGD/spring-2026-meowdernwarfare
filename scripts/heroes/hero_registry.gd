class_name HeroRegistry
extends RefCounted

## Single source of truth for hero id -> scene path, plus legacy aliases.
## Merges what used to live in Player.HERO_SCENE_PATHS and GameData.TRAIN_HERO_ALIAS.

const SCENES := {
	"Dealer": "res://scenes/heroes/dealer/dealer.tscn",
	"Burple": "res://scenes/heroes/burple/burple.tscn",
	"BurpleBot": "res://scenes/heroes/burple_bot.tscn",
	"LoanShark": "res://scenes/heroes/loanshark/loanshark.tscn",
	"Gooblin": "res://scenes/heroes/gooblin/gooblin.tscn",
	"Garebare": "res://scenes/heroes/garebare/garebare.tscn",
	"AnimeGirl": "res://scenes/heroes/animegirl/animegirl.tscn",
	"XylerFergus": "res://scenes/heroes/xylerfergus/xylerfergus.tscn",
	"ElonMusk": "res://scenes/heroes/elonmusk/elonmusk.tscn",
	"AnderDingus": "res://scenes/heroes/anderdingus/anderdingus.tscn",
}

## Old display names kept around for backward compat with saved data / older packets.
const ALIASES := {
	"Anime Girl": "AnimeGirl",
	"Xyler and Fergus": "XylerFergus",
	"Elon. Musk.": "ElonMusk",
	"Alien": "AnimeGirl",
	"Xyler": "XylerFergus",
	"Fergus": "XylerFergus",
}

static var _scene_cache: Dictionary = {}

static func canonical(hero_id: String) -> String:
	return ALIASES.get(hero_id, hero_id)

static func scene_path(hero_id: String) -> String:
	return SCENES.get(canonical(hero_id), "")

static func load_scene(hero_id: String) -> PackedScene:
	var path := scene_path(hero_id)
	if path.is_empty():
		return null
	var cached: PackedScene = _scene_cache.get(path, null)
	if cached:
		return cached
	var scene: PackedScene = load(path) as PackedScene
	if scene:
		_scene_cache[path] = scene
	return scene

static func warm_scene(hero_id: String) -> void:
	# Keep warmup deterministic to avoid threaded race conditions when scripts compile.
	load_scene(hero_id)

static func warm_all() -> void:
	for id in SCENES.keys():
		warm_scene(id)

static func has(hero_id: String) -> bool:
	return SCENES.has(canonical(hero_id))

static func ids() -> Array:
	return SCENES.keys()
