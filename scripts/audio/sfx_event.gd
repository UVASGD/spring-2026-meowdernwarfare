class_name SfxEvent
extends RefCounted

const UI_HOVER: StringName = &"ui.hover"
const UI_CLICK: StringName = &"ui.click"
const UI_BACK: StringName = &"ui.back"
const UI_READY_ON: StringName = &"ui.ready_on"
const UI_READY_OFF: StringName = &"ui.ready_off"
const UI_MATCH_START: StringName = &"ui.match_start"
const UI_PAUSE_OPEN: StringName = &"ui.pause_open"
const UI_PAUSE_CLOSE: StringName = &"ui.pause_close"
const UI_SKILL_ON_CD: StringName = &"ui.skill_on_cd"

const PLAYER_DASH: StringName = &"player.dash"
const PLAYER_HURT: StringName = &"player.hurt"
const PLAYER_DEATH: StringName = &"player.death"
const PLAYER_RESPAWN: StringName = &"player.respawn"
const PLAYER_MELEE_SWIPE: StringName = &"player.melee_swipe"
const PLAYER_CD_READY: StringName = &"player.cd_ready"
const PLAYER_ULT_READY: StringName = &"player.ult_ready"
const PLAYER_CROP_PICKUP: StringName = &"player.crop_pickup"
const PLAYER_CROP_DROP: StringName = &"player.crop_drop"
const PLAYER_CROP_PLANT: StringName = &"player.crop_plant"
const PLAYER_CROP_UPROOT: StringName = &"player.crop_uproot"

const WEAPON_SHOOT: StringName = &"weapon.shoot"
const WEAPON_RELOAD_START: StringName = &"weapon.reload_start"
const WEAPON_RELOAD_DONE: StringName = &"weapon.reload_done"

const ABILITY_1: StringName = &"ability.1"
const ABILITY_2: StringName = &"ability.2"
const ABILITY_ULT: StringName = &"ability.ult"

const DEALER_ABILITY_1: StringName = &"hero.dealer.ability1"
const DEALER_ABILITY_2: StringName = &"hero.dealer.ability2"
const DEALER_ULT: StringName = &"hero.dealer.ult"

const BURPLE_ABILITY_1: StringName = &"hero.burple.ability1"
const BURPLE_ULT: StringName = &"hero.burple.ult"

const LOANSHARK_MELEE: StringName = &"hero.loanshark.melee"
const LOANSHARK_ABILITY_1: StringName = &"hero.loanshark.ability1"
const LOANSHARK_ABILITY_2: StringName = &"hero.loanshark.ability2"
const LOANSHARK_ULT: StringName = &"hero.loanshark.ult"

const GOOBLIN_ABILITY_1: StringName = &"hero.gooblin.ability1"
const GOOBLIN_ABILITY_2: StringName = &"hero.gooblin.ability2"
const GOOBLIN_ULT: StringName = &"hero.gooblin.ult"

const GAREBARE_ABILITY_1: StringName = &"hero.garebare.ability1"
const GAREBARE_ABILITY_2: StringName = &"hero.garebare.ability2"
const GAREBARE_ULT: StringName = &"hero.garebare.ult"
const GAREBARE_FIE_DESTROY: StringName = &"hero.garebare.fie_destroy"

const XYLER_FERGUS_SWAP: StringName = &"hero.xylerfergus.swap"
const XYLER_FERGUS_ULT: StringName = &"hero.xylerfergus.ult"

const ELONMUSK_ABILITY_1: StringName = &"hero.elonmusk.ability1"
const ELONMUSK_ULT: StringName = &"hero.elonmusk.ult"
const ELONMUSK_ULT_MOVE: StringName = &"hero.elonmusk.ult_move"

const ANDERDINGUS_ULT: StringName = &"hero.anderdingus.ult"
const FX_EXPLOSION: StringName = &"fx.explosion"

static func all_ids() -> Array[StringName]:
	return [
		UI_HOVER,
		UI_CLICK,
		UI_BACK,
		UI_READY_ON,
		UI_READY_OFF,
		UI_MATCH_START,
		UI_PAUSE_OPEN,
		UI_PAUSE_CLOSE,
		UI_SKILL_ON_CD,
		PLAYER_DASH,
		PLAYER_HURT,
		PLAYER_DEATH,
		PLAYER_RESPAWN,
		PLAYER_MELEE_SWIPE,
		PLAYER_CD_READY,
		PLAYER_ULT_READY,
		PLAYER_CROP_PICKUP,
		PLAYER_CROP_DROP,
		PLAYER_CROP_PLANT,
		PLAYER_CROP_UPROOT,
		WEAPON_SHOOT,
		WEAPON_RELOAD_START,
		WEAPON_RELOAD_DONE,
		ABILITY_1,
		ABILITY_2,
		ABILITY_ULT,
		DEALER_ABILITY_1,
		DEALER_ABILITY_2,
		DEALER_ULT,
		BURPLE_ABILITY_1,
		BURPLE_ULT,
		LOANSHARK_MELEE,
		LOANSHARK_ABILITY_1,
		LOANSHARK_ABILITY_2,
		LOANSHARK_ULT,
		GOOBLIN_ABILITY_1,
		GOOBLIN_ABILITY_2,
		GOOBLIN_ULT,
		GAREBARE_ABILITY_1,
		GAREBARE_ABILITY_2,
		GAREBARE_ULT,
		GAREBARE_FIE_DESTROY,
		XYLER_FERGUS_SWAP,
		XYLER_FERGUS_ULT,
		ELONMUSK_ABILITY_1,
		ELONMUSK_ULT,
		ELONMUSK_ULT_MOVE,
		ANDERDINGUS_ULT,
		FX_EXPLOSION,
	]
