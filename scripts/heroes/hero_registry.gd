class_name HeroRegistry
extends RefCounted

## Single source of truth for hero id -> scene path, plus legacy aliases.
## Merges what used to live in Player.HERO_SCENE_PATHS and GameData.TRAIN_HERO_ALIAS.

const SCENES := {
	"Dealer": "res://scenes/heroes/dealer/dealer.tscn",
	"Burple": "res://scenes/heroes/burple/burple.tscn",
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

static func canonical(hero_id: String) -> String:
	return ALIASES.get(hero_id, hero_id)

static func scene_path(hero_id: String) -> String:
	return SCENES.get(canonical(hero_id), "")

static func load_scene(hero_id: String) -> PackedScene:
	var path := scene_path(hero_id)
	if path.is_empty():
		return null
	return load(path)

static func has(hero_id: String) -> bool:
	return SCENES.has(canonical(hero_id))

static func ids() -> Array:
	return SCENES.keys()
