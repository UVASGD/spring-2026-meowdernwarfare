# Sync / Bug Audit — `sync-cleanup-refactor` follow-up

Audit of `scripts/globals/game_manager.gd`, `scripts/player.gd`, `scripts/inputs/network_input.gd`, `scripts/heroes/*.gd`, projectile/hurtbox scripts, `scripts/killzone.gd`, and `scripts/game.gd` against the plan (`sync-cleanup-refactor_4d9465ce.plan.md`) and `knowledge.md`.

Phase‑1 host‑auth damage / respawn / tie logic is mostly correctly wired. The issues below are the real remaining desync risks plus one concrete bug in the online crop flow.

Ordered by severity.

---

## 1. HIGH — `send_crop_uproot` broadcasts the wrong thief when the host sims a remote's uproot

`scripts/player.gd` drives uproot off `input.shoot_just` inside `_handle_crops` / `_try_uproot`:

```gdscript
func _try_uproot() -> bool:
    var gm = GameManager.instance
    var farms_list = gm.get_farms() if gm else get_tree().get_nodes_in_group("farms")
    for f in farms_list:
        var tiles = _get_plantable_tiles(f)
        var tile = _tile_at_cursor(tiles)
        if tile == null or tile.planted_crop == null:
            continue
        if tile.global_position.distance_to(global_position) > UPROOT_RANGE:
            continue
        var tile_idx = tiles.find(tile)
        var crop = f.remove_crop(tile.planted_crop)
        if crop:
            var victim = f._owner
            if victim:
                victim.crop_count -= 1
            pickup_world_crop(crop)
            if gm and not gm.is_local() and victim:
                gm.send_crop_uproot(victim.player_id, tile_idx, crop.get_type_id(), crop.stage)
            return true
```

`_handle_crops` has no physics‑owner / local‑player gate, so on the host this runs for **every** player (knowledge.md: "host simulates remote players from streamed inputs"). `send_crop_uproot` then hardcodes `local_player_id` as the thief:

```gdscript
func send_crop_uproot(victim_id: int, tile_idx: int, crop_type: String, stg: int) -> void:
    var victim = get_player(victim_id)
    var cc = victim.crop_count if victim else 0
    if mode == Mode.ONLINE_HOST:
        _host_held_crops[local_player_id] = {"t": crop_type, "s": stg}
        Network.broadcast({
            "type": "crop_removed",
            ...
            "thief": local_player_id,
            ...
```

### Consequences
- When a non‑host client uproots, the client sends `crop_uproot` and host's `_handle_crop_uproot` applies the correct `from_id` thief. But host's **streamed‑input simulation** of the same player also reaches `_try_uproot` in the same/adjacent tick; whichever runs first wins. If the streamed‑input path wins, `crop_removed` is broadcast with `thief = host.pid`, and `_host_held_crops[host.pid]` gets the stolen crop. Every client then shows the host holding it and the real thief holding nothing.
- Even when the direct `crop_uproot` handler wins, the later simulation reaches `tile.planted_crop == null` and no-ops — but this is a pure race that depends on relay delivery order.

### Fix (pick one)
- Gate `_try_uproot` / `_try_plant` / target‑mode shooting at the top of `_handle_crops` / `_handle_actions` with `if not _is_local_player(): return` (mirrors the existing gate in `_on_crop_area_entered`).
- Or pass the actual thief id into `send_crop_uproot(thief_id, victim_id, ...)` and have `_host_held_crops[thief_id]` / `"thief": thief_id`.

---

## 2. HIGH — `_handle_crops` / `_handle_actions` run on all peers with no physics‑owner guard

Same root cause as #1. On the host, `_physics_process` for a remote `Player` skips `_handle_movement` + `move_and_slide()` (good) but still runs `_handle_rotation`, `_update_target_marker`, `_handle_crops`, and `_handle_actions`:

```gdscript
func _physics_process(delta: float) -> void:
    ...
    if physics_owner:
        _handle_movement(delta)
        move_and_slide()
    
    _handle_rotation(delta)
    _update_target_marker()
    var consumed_shoot := _handle_crops(delta)
    _handle_actions(consumed_shoot)
```

On the client it's symmetric — remote players' `_handle_actions` still fires via `NetworkInput` buffered `_just` flags, which is intentional for cosmetic bullet spawning but accidentally runs `_try_plant` / `_try_uproot` / crop‑target‑mode code too. `_try_plant` happens to no‑op (`held_crop == null` on remote), but this is brittle. Any future ability that dispatches off `input.shoot_just` / `input.ability*_just` through Player code will double‑fire (once locally, once on host sim).

The crop‑area pickup gate proves the author already knew that:

```gdscript
func _on_crop_area_entered(area: Area2D) -> void:
    if in_spectate_mode: return
    if input is NetworkInput and not input.is_local: return
    if area is Crop and held_crop == null and drop_cd <= 0 and not area.is_planted:
        pickup_world_crop(area)
```

### Fix
A single guard at the top of `_handle_crops` and the plant/uproot branch of `_handle_actions` — e.g. early‑return when `not _is_local_player()` for anything that sends network traffic or mutates shared state. Remote bullet spawning in `_handle_actions` is already gated inside the hero `_do_*` functions for the abilities that need it (Burple, Elon, Dingus, Loanshark ult etc.), so pushing the guard up one level won't regress visuals if the bullet spawn moves into `_do_shoot` only.

---

## 3. HIGH — per‑peer status effects aren't in `state_sync`

`_broadcast_state` only carries: `hp / ult|ucd / ammo / cc / dash / drug / stun / spec / dead / await_resp / hc,hs / invis`.

But these stateful things are set purely off `_just` edges and stored per‑peer:

- `HeroXylerFergus._xyler_ult_t` / `_fergus_ult_t` (damage bonus, move bonus, Fergus‑mark spawn rate) — `scripts/heroes/xylerfergus.gd:186-191`.
- `Player.is_marked` / `marked_timer` (Loan Shark mark) — `scripts/player.gd:1295-1309`, applied inside `mark_projectile._apply_explosion_aoe` / `feeding_frenzy._apply_marks` on every peer.
- `Player.is_blinded` / `blind_timer` — `scripts/player.gd:1322-1359`, applied inside `boogie_bomb._explode` on every peer.
- `HeroGooblin.retreat_timer` and `move_speed_mult` — `scripts/heroes/gooblin.gd:73-78`.
- `Dealer._apply_drug_to_enemies` drugs the local player on the local peer: `drug` is in `state_sync` but only applied for `not is_local_player` in `_apply_corrections`, so if the dealer's `ult_just` edge is dropped on that peer its local player never gets drug — and host will never correct it.

`_apply_corrections`:

```gdscript
if not is_local_player:
    var hc = state.get("hc", "")
    ...
...
if state.get("drug", false) and not player.is_drugged:
    player.is_drugged = true
elif not state.get("drug", false) and player.is_drugged:
    player._end_drug_effect()
```

Any dropped `*_just` flag = permanent divergence until the effect's own timer expires. Since `NetworkInput` sends every edge immediately, dropped packets are rare, but there is no retry / ACK (`knowledge.md` "Known limitations" acknowledges this).

### Fix
Add a compact `"eff"` byte (or separate fields) in `state_sync` that mirrors the same timers the hero stores (or at least an "is_effect_active" bool), applied symmetrically to local and remote in `_apply_corrections`. Even a simple flag that converges after one state_sync is worth the bytes.

---

## 4. HIGH — `hurtbox._try_hit` treats client‑side flinch as a real hit

`Player.take_damage` returns `true` on a non‑host just to emit a visual flinch:

```gdscript
func take_damage(amount: float, attacker: Player = null) -> bool:
    if is_dead or in_spectate_mode or is_awaiting_respawn or is_invulnerable:
        return false
    if is_dashing:
        on_bullet_dodged()
        return false
    if hero == null:
        return false
    
    var gm = GameManager.instance
    var host_auth = gm == null or gm.is_host()
    
    if not host_auth:
        took_damage.emit(amount)
        return true
```

`HeroHurtbox._try_hit` uses that return as authoritative:

```gdscript
var dealt := p.take_damage(damage, owner_player)
if not dealt:
    return
match _swing_mode:
    SwingMode.DASH:
        if was_marked:
            if owner_player and owner_player.hero:
                owner_player.hero.refresh_ability1_cooldown()
            p.clear_mark_effect()
        _spawn_chomp_visual(body)
```

On a client, Loan Shark's dash hit refreshes `ability1_cd` to 0 locally and clears the victim's mark visually — regardless of whether the host registered the hit. Because none of {`ability1_cd`, `is_marked`} are in `state_sync`, these divergences don't self‑heal. The client sees their dash cooldown refresh + chomp visual + mark cleared; the host may have registered nothing (mark was already off on host, or player wasn't in range on host). Result: the real Loan Shark can dash again locally while host still has `ability1_cd > 0` and silently drops the next dash request.

### Fix
- Return `false` from `take_damage` on a non‑host so hurtbox's downstream side effects don't fire, and move chomp / mark‑clear / `refresh_ability1_cooldown` onto host‑gated code that broadcasts to clients (similar to how Xyler's slash does `xf_slash` broadcast).
- Or add a dedicated `loan_dash_hit` host→clients message and stop using `take_damage`'s return value.

---

## 5. MED — cooldowns in `state_sync` are advertised but not actually carried

`knowledge.md`:
> Cooldowns (shoot/ability1/ability2) | Per peer; host's is truth | `state_sync`

But `_broadcast_state` never writes `shoot_cd / ability1_cd / ability2_cd / reload_cd / dash_cd_timer / LoanShark._ability2_slot_cds`. Heroes tick these entirely locally (`Hero._update_cooldowns`), and `_apply_corrections` never sets them.

- Local player cooldown on host vs. same player's cooldown locally can diverge if any trigger is dropped (or any of the local‑only refresh paths like `refresh_ability1_cooldown` fire).
- Loan Shark `ability2_charges` + `_ability2_slot_cds` are fully per‑peer. `can_ability2` is gated on host; host might refuse a client cast because host thinks `charges == 0` while the client thinks `1`.

### Fix
Either update `knowledge.md` to say "cooldowns are per‑peer, prediction‑style, never synced" or actually pack them into `state_sync` (a packed `[sc, a1, a2, rc, dc]` array would be ~5 floats per player, fine at 10 Hz for ≤4 players).

---

## 6. MED — Dingus ult RNG is still client‑owner‑driven, not host‑driven

Plan marks `fluff_elon_rng` as "fix Elon flame spread RNG TODO (host‑drive)" done, and knowledge.md talks about "host‑only RNG for gameplay", but Dingus ult is rolled on the owner client before host involvement:

```gdscript
func _do_ult(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
    var gm := GameManager.instance
    if gm == null or player == null:
        return
    if not gm.is_local() and player.player_id != gm.local_player_id:
        return
    _play_ult_sfx()
    var area := _get_map_area()
    for i in range(ult_strike_count):
        var x := randf_range(area.position.x, area.end.x)
        var y := randf_range(area.position.y, area.end.y)
        _orbital_seq += 1
        gm.cast_dingus_orbital(player.player_id, Vector2(x, y), "%s:%s" % [player.player_id, _orbital_seq])
```

This works today because only one peer rolls, but:

- `_handle_dingus_orbital_req` doesn't validate `x/y` are inside the map → a malicious / broken client can aim strikes anywhere.
- Mid‑ult host migration (listed as broken in `knowledge.md`) would instantly desync because the new host has no idea which 26 strikes the old owner had intended.

### Fix
Move the RNG into a new `cast_dingus_ult_req` → host rolls 26 coords → host spawns + broadcasts N `dingus_orbital_spawn`s. Elon's `_spread_rng` seeded by `(pid * 1_000_003) ^ _shot_seq` is the right pattern; apply the same thing here (seed by `(pid ^ ult_seq)` on host).

---

## 7. MED — `_handle_teleporter_used` doesn't disable host's own teleporters

```gdscript
func send_teleporter_used(tp_id: int, target_tp_id: int) -> void:
    var msg = {"type": "tp_used", "a": tp_id, "b": target_tp_id}
    if mode == Mode.ONLINE_HOST:
        Network.broadcast(msg)
    else:
        Network.send_to_host(msg)

func _handle_teleporter_used(from_id: int, data: Dictionary) -> void:
    if mode == Mode.ONLINE_HOST:
        Network.broadcast(data)
    var tp_a = int(data.get("a", -1))
    var tp_b = int(data.get("b", -1))
    for tp in get_tree().get_nodes_in_group("teleporters"):
        if tp.id == tp_a or tp.id == tp_b:
            if tp.active:
                tp._set_disabled(tp.cooldown)
```

When the **host** uses a teleporter it goes through `send_teleporter_used` which only broadcasts. Assuming the relay doesn't echo to the sender (the rest of the code is written under that assumption), the host's own teleporter pair never gets `_set_disabled` here — it's only whatever teleporter.gd itself does locally. If teleporter.gd doesn't self‑disable, host's teleporters keep looking active while clients see them on cooldown.

### Fix
Audit `scripts/teleporter.gd`; if it doesn't self‑disable, either have `send_teleporter_used` also call `_set_disabled` locally on the host, or funnel through `_handle_teleporter_used`.

---

## 8. MED — `_send_local_state` keeps broadcasting while dead / respawning / spectating

`NetworkInput._player_uncontrollable()` correctly strips outgoing inputs when the local player is dead/spectating, but `GameManager._send_local_state` has no matching gate:

```gdscript
func _send_local_state() -> void:
    var player = get_local_player()
    if player == null or not is_instance_valid(player):
        return
    
    var state = {
        "type": "client_state",
        "id": player.player_id,
        ...
        "dash": player.is_dashing
    }
    state["cc"] = player.crop_count
    if player.held_crop:
        state["hc"] = player.held_crop.get_type_id()
        state["hs"] = player.held_crop.stage
    
    Network.send_to_host(state)
```

Today it only carries `hc/hs` (because host ignores position/dash), so the worst case is a dead player telling the host they're still holding a crop they're not.

### Fix
`if player.is_dead() or player.is_awaiting_respawn or player.in_spectate_mode: return`.

---

## 9. LOW — HeroRegistry references a scene that may not exist

```gdscript
const SCENES := {
    ...
    "AnimeGirl": "res://scenes/heroes/animegirl/animegirl.tscn",
    ...
}
```

I don't see `scenes/heroes/animegirl/animegirl.tscn` on disk. AnimeGirl / "Alien" selections will fall back at runtime with a `push_warning("Unknown hero:", ...)`. Not a sync bug, but worth either removing the entry or making the fallback explicit.

---

## 10. LOW — `_handle_crop_pickup` race when two players area‑enter the same crop

```gdscript
func _handle_crop_pickup(from_id: int, data: Dictionary) -> void:
    var picker_id = int(data.get("pid", from_id))
    if mode == Mode.ONLINE_HOST:
        _host_held_crops[picker_id] = {"t": data.get("ct", ""), "s": int(data.get("cs", 1))}
        Network.broadcast(data)
    if picker_id == local_player_id:
        return
    ...
```

Host accepts every `crop_pickup` request in arrival order without checking "is this crop still available". Two clients whose crop areas overlap the same spawner crop both pick it up locally, both send `crop_pickup`, host writes `_host_held_crops` for both and broadcasts both. Everyone ends up showing two players holding clones of the same crop.

### Fix
Resolve first‑arrival on host (reject the second `crop_pickup` if the matching spawner/world crop is already gone) and broadcast a single `crop_pickup_result` → drop‑back for the loser.

---

## 11. LOW — debug noise / smell

- `scripts/game.gd` still has gameplay `print("[GAME] ...")` in `_on_player_eliminated`, `_end_game`, `_on_game_over_received`, `_show_winner_screen`. Plan's `fluff_unused_fields` task is marked done but these remain.
- `_warn_missing_anim` prints via `print` rather than `push_warning`.
- `NetworkInput._maybe_send` `_same_continuous` only checks `m/a/sp/sh` — aim is captured but `shoot_just` / edges are handled via `has_edge`, which is fine; just flagging the comment‑vs‑code subtlety for future maintenance.

---

## 12. LOW — `_apply_state_sync_hp` can stomp a dying local player to alive

```gdscript
func _apply_state_sync_hp(player: Player, state: Dictionary) -> void:
    if player.hero == null:
        return
    var hp: float = float(state.get("hp", player.hero.health))
    var hp_diff := hp - player.hero.health
    if abs(hp_diff) <= 1.0:
        return
    if hp_diff > 0.0 and hp_diff < player.hero.max_health * 0.25:
        player.hero.health = lerpf(player.hero.health, hp, 0.4)
    else:
        player.hero.health = hp
    player.hero.health_changed.emit(player.hero.health, player.hero.max_health)
```

If `hero.is_dead == true` on client but host's packet says `hp = max` (for a freshly respawned frame), we'll set hero.health to max without clearing `is_dead`. The respawn path further down handles `is_dead`, so in practice it's fine.

### Fix
`return` early when `player.hero.is_dead and hp > 0` and let the death/respawn branch do its thing.

---

## Quick‑win remediation priorities

1. **Gate `_handle_crops` and the uproot/plant/target branches of `_handle_actions` on `_is_local_player()`.** Single change that kills #1, #2, and several latent duplicate‑action bugs in one go.
2. **Make `take_damage` on non‑host return `false`** and move chomp / mark‑clear / `refresh_ability1_cooldown` onto a host broadcast (fixes #4).
3. **Either sync per‑status‑effect state in `state_sync`** (`mark`, `blind`, `xf_ult`, `retreat_mult`) **or update `knowledge.md` to say they aren't synced** (fix #3 + #5 documentation).
4. **Host‑drive Dingus ult RNG** like Elon (fix #6 and close the "fixed" task).
5. **Add dead/spectate gate to `_send_local_state`** (cheap cleanup for #8).
6. **Add first‑arrival resolution for `_handle_crop_pickup`** (fix #10).

None of these are blocking gameplay today, but #1 / #2 / #4 / #6 together cover the realistic "why did the crop count go weird" / "why is my cooldown desynced" / "why did I see a hit but they didn't" complaints most likely to surface at the next multiplayer test.
