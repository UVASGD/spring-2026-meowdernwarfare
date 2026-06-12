# SFX Checklist + Wiring

Central drag-and-drop bank: `assets/resources/audio/sfx_bank.tres`

Global runtime manager: `Sfx` autoload from `scenes/globals/sfx.tscn`

How to add sounds:
1. Open `assets/resources/audio/sfx_bank.tres` in Godot inspector.
2. Expand `slots`.
3. For each slot, drag an `AudioStream` into `stream`.
4. Optionally tune `volume_db`, `pitch`, `pitch_rand`, `bus`, and `world`.
5. Run game; events auto-play through `Sfx`.

Per-scene explosion loudness:
- Generic explosion scene (`res://scenes/explosion_visual.tscn`) supports per-instance `sfx_db_offset`.
- Blast Berry uses `explosion_sfx_db_offset` in `scripts/crops/blast_berry.gd` so dash-proc explosions can stay quieter.

---

## UI

- [ ] `ui.hover` - button hover tick
- [ ] `ui.click` - standard confirm click
- [ ] `ui.back` - cancel/back click
- [ ] `ui.ready_on` - ready toggle on
- [ ] `ui.ready_off` - ready toggle off
- [ ] `ui.match_start` - match starts
- [ ] `ui.pause_open` - pause menu opens
- [ ] `ui.pause_close` - pause menu closes
- [ ] `ui.skill_on_cd` - tried to use skill while unavailable/on cooldown

## Core Combat / Player

- [ ] `weapon.shoot` - baseline shot fire
- [ ] `weapon.reload_start` - reload start
- [ ] `weapon.reload_done` - reload complete
- [ ] `player.dash` - movement dash
- [ ] `player.hurt` - player takes damage
- [ ] `player.death` - player death
- [ ] `player.respawn` - respawn
- [ ] `player.melee_swipe` - generic melee swipe (LoanShark + Xyler)
- [ ] `player.cd_ready` - a skill/reload cooldown finishes
- [ ] `player.ult_ready` - ultimate becomes fully available

## Farming / Objective

- [ ] `player.crop_pickup` - pick crop from world
- [ ] `player.crop_drop` - drop held crop
- [ ] `player.crop_plant` - plant crop
- [ ] `player.crop_uproot` - uproot enemy crop

## Generic Ability Layers

- [ ] `ability.1` - any ability 1 cast
- [ ] `ability.2` - any ability 2 cast
- [ ] `ability.ult` - any ultimate cast

## Shared FX

- [ ] `fx.explosion` - shared explosion scene SFX (Burple/Garebare/crops/etc.)

## Hero-Specific Layers

Dealer
- [ ] `hero.dealer.ability1` - invis start
- [ ] `hero.dealer.ability2` - drug pulse
- [ ] `hero.dealer.ult` - ult cast

Burple
- [ ] `hero.burple.ability1` - grenade cast
- [ ] `hero.burple.ult` - missile strike cast

LoanShark
- [ ] `hero.loanshark.melee` - melee swipe/chomp
- [ ] `hero.loanshark.ability1` - dash slash
- [ ] `hero.loanshark.ability2` - mark projectile
- [ ] `hero.loanshark.ult` - feeding frenzy

Gooblin
- [ ] `hero.gooblin.ability1` - boogie bomb throw
- [ ] `hero.gooblin.ability2` - retreat trigger
- [ ] `hero.gooblin.ult` - drooglin summon

Garebare
- [ ] `hero.garebare.ability1` - sonic burst
- [ ] `hero.garebare.ability2` - FIE place
- [ ] `hero.garebare.ult` - arena ult
- [ ] `hero.garebare.fie_destroy` - FIE destroyed

XylerFergus
- [ ] `hero.xylerfergus.swap` - stance swap
- [ ] `hero.xylerfergus.ult` - both stance ults

ElonMusk
- [ ] `hero.elonmusk.ability1` - magnet window
- [ ] `hero.elonmusk.ult` - cybertruck ult
- [ ] `hero.elonmusk.ult_move` - cybertruck reposition click during ult

AnderDingus
- [ ] `hero.anderdingus.ult` - orbital strike cast

---

## Naming Recommendation

Use predictable file names per event id:

- `ui_click_01.wav`
- `player_hurt_01.wav`
- `hero_loanshark_ability2_mark_01.wav`

If you want variation, keep same event slot and swap in a randomized stream type (or expand slots later with suffixes like `.a` / `.b`).
