# Meowdern Warfare - Engineering Knowledge

Living document. Update as the codebase evolves. Read this first in any new session.

## Project

- Godot 4.4, GDScript, GL Compatibility renderer.
- Autoloads (see `project.godot`):
  - `Network` (`scripts/globals/network.gd`) - WebSocket wrapper.
  - `GameData` (`scripts/globals/game_data.gd`) - menu/lobby transition state.
  - `TestConfig` (`scripts/globals/test_config.gd`) - dev defaults (server URL, default hero/map).
  - `Cursor` (`scenes/ui/cursor.tscn`) - mouse cursor theme.
- Relay server: `server/relay.py` (Python WebSocket). Rooms, host/peer routing.

## Authority model (host-authoritative)

**Rule of thumb:** if it affects HP, crops, kill credit, ult charge, or the outcome of the match, the host owns it. Clients predict only their own player's immediate-feel reactions and rubber-band on the next `state_sync`.

| Concern | Authority | Transport |
|---|---|---|
| Local player input | Client | `input` broadcast, throttled to 30 Hz + edges |
| Local player movement | Client (simulates own body) with **host rubber-band** reconciliation every `state_sync`. | `client_state` 20 Hz (held-crop / dash flag) |
| Remote player movement | **Host** simulates from streamed inputs | `state_sync` 20 Hz |
| HP / damage / death | **Host** (`Player.take_damage` funnel) | `state_sync` |
| Attacker ult points / kill credit | **Host** | `state_sync` (ult/ucd), `stats_sync` when changed |
| Crops (plant/uproot/pickup/drop) | **Host** applies and broadcasts. World crops (spawner + dropped) carry a stable `crop_id`; pickup arbitration is id-based (position is fallback only). | `crop_*` messages |
| Crop spawner state | **Host** assigns `crop_id = "sp:<sid>:<seq>"` per spawn; clients instantiate with the same id so cross-peer identity is exact. | `crop_spawned`, `crop_bring`, `spawner_stage` |
| Game end / sudden death | **Host** | `game_over`, `sudden_death` |
| Tie-break | Deterministic (crops desc, kills desc, pid asc) on every peer | no RNG, no extra message |
| Projectiles (grenade, strike, orbital, cybertruck) | **Host** spawns authoritative, clients spawn visual ghosts | `*_req` -> host, `*_spawn` -> clients |
| Bullets (raw `bullet.gd` etc.) | Spawned on every peer (visual). Damage gated by host `take_damage` | implicit via inputs |
| Cooldowns (shoot/ability1/ability2/reload/dash) | Per peer, prediction-style. Not synced; each peer ticks its own timers off `*_just` input edges. Drifts on dropped edges; converges only via re-cast. | - |
| Ult gauge | `CHARGE` -> points stream in `ult`; `COOLDOWN` -> timer streams in `ucd` | `state_sync` |
| Status effects (mark, blind) | Host broadcasts bit in `state_sync` (`mk`, `bl`) so dropped *_just edges self-heal on the next tick. | `state_sync` |
| Status effects (drug, stun) | Host broadcasts in `state_sync` (`drug`, `stun`). | `state_sync` |
| Status effects (Xyler/Fergus ult, Gooblin retreat) | Per peer, set off `ult_just`. Not currently synced; dropped edge = visual-only divergence for the effect's duration. | - |

### Why bullets are not request/response

Bullets spawn client-side for responsiveness. Each peer runs the same direction/speed deterministically. Only the host's bullet actually applies damage (gated inside `Player.take_damage`). Clients see the visual, rubber-band HP from `state_sync`.

### Host simulates remote players

The host runs `_handle_movement` + `move_and_slide` for every `Player`, not just the host's local body. `NetworkInput` on the host reads the remote peer's buffered inputs (same as local player reads `LocalInput`). That way the host's collision world matches reality when bullets/melee check overlaps.

Clients still lerp remote `Player` bodies towards `state_sync` positions; clients never simulate physics for anyone but themselves.

## Top-level architecture

```
                                 relay.py
                                /    |    \
                       (broadcast/to_host/to_player)
                              /      |      \
           +-----------------+       |       +------------------+
           | Host (ONLINE_HOST)      |       | Client (ONLINE_CLIENT)
           |  - simulates all players|       |  - simulates own player
           |  - damage authority     |       |  - applies corrections
           |  - broadcasts state_sync|       |  - lerps remotes
           +-------------------------+       +------------------+
```

## File map

### Globals

- `scripts/globals/network.gd` - `Network` singleton. Connects to relay; exposes `host_room`, `join_room`, `broadcast`, `send_to_host`, `send_to_player`. Emits `message_received(from_id, data)`.
- `scripts/globals/game_manager.gd` - `GameManager` singleton (~1700 lines). Responsibilities:
  - LOCAL and ONLINE player spawning, eliminations, respawn timers, stats.
  - State sync: `_broadcast_state`, `_send_local_state`, `_apply_corrections`, `_interpolate_remotes`.
  - Crop / crop-spawner network messages.
  - Projectile spawn mirroring: Burple grenade + strike, Muskrat cybertruck ult, AnderDingus orbital, Xyler slash.
  - Desync telemetry (`pos_report`).
  - O(1) player lookup via `_players_by_id`; per-frame farm cache via `get_farms()`.
- `scripts/globals/game_data.gd` - lobby/menu transition state, starter crops config, scene transition overlay.
- `scripts/globals/test_config.gd` - dev constants.

### Net helpers (new)

- `scripts/net/projectile_net.gd` - `ProjectileNet`. Shared registry + spawn/despawn helper for one-shot networked objects. Currently a scaffold for a future full migration of `_burple_grenades`, `_burple_strikes`, `_muskrat_ults`, `_ander_orbitals` (and any new projectile). See "How to add a networked ability" below.

### Player / Input

- `scripts/player.gd` - `Player : CharacterBody2D` (~1400 lines). Sections marked by `# --- ... ---` headers: cooldown UI, tooltip, crops, drug/blind/mark/stun, death/respawn, spectate.
- `scripts/inputs/input_provider.gd` - base input interface.
- `scripts/inputs/local_input.gd` - keyboard/mouse/gamepad input.
- `scripts/inputs/network_input.gd` - networked wrapper. Local player samples `LocalInput`, sends over network at 30 Hz (plus immediate edges for `*_just`). Remote instance drains the buffered inputs merging all `_just` flags so none are lost.
- `scripts/inputs/dummy_input.gd` - simple AI input.

### Hero base + subclasses

- `scripts/heroes/hero.gd` - base class. Holds `max_health`, cooldowns, and the ult gauge. `UltMode.CHARGE` = fill by hits/dodges (default); `UltMode.COOLDOWN` = `ult_cd` timer (Dingus).
- `scripts/heroes/ability.gd` - `Ability` resource with `Kind = { COOLDOWN, CHARGES, SLOTS }`. Unified `tick/can_use/try_use/get_percent` interface intended to replace the per-hero cooldown spaghetti over time. Heroes can migrate incrementally.
- `scripts/heroes/hero_registry.gd` - `HeroRegistry`. Single source of truth for hero id -> scene path, plus legacy aliases. Replaces the old `Player.HERO_SCENE_PATHS` and `GameData.TRAIN_HERO_ALIAS`.
- `scripts/heroes/<name>.gd` + `scenes/heroes/<name>/<name>.tscn` - per-hero logic:
  - `dealer.gd` / `bullet.gd` - basic ranged.
  - `burple.gd` / `grenade.gd` / `missile_strike.gd` - grenade ability (host-auth spawn), missile ult.
  - `loanshark.gd` - melee dash hero. Two-charge ability2 (mark projectile), feeding frenzy ult.
  - `gooblin.gd`, `garebare.gd`, `animegirl.gd`, `xylerfergus.gd`, `anderdingus.gd`, `elonmusk.gd`.
- `scenes/hurtbox.gd` - `HeroHurtbox`. Used by melee/dash swings. Dedupes hits via `hit_map`.

### Game / Maps

- `scripts/game.gd` + `scenes/game.tscn` - main game scene. Loads map, spawns farms, owns timer HUD, pause menu, winner screen, sudden-death killzone. Tie-break resolution is deterministic (crops desc, kills desc, pid asc).
- `scripts/killzone.gd` - shrinking damage ring. Host applies damage only; clients render the visual.
- `scenes/maps/*.tscn` - map scenes.

### UI

- `scenes/ui/main_menu.gd`, `scripts/ui/joinscreen.gd`, `scripts/ui/lobby.gd`, `scenes/ui/pause_menu.gd`, `scripts/ui/debug_menu.gd`.
- `scripts/ui/menu_parallax.gd` - `MenuParallax`. Shared helpers for the mouse-driven 3D tilt / background drift used by main menu, join screen, and lobby.

## Message catalog

Every message goes through `Network.broadcast({...})` (relay fans out), `Network.send_to_host(...)`, or `Network.send_to_player(id, ...)`. Payload dict always has a `"type"` string.

### Lobby / control

| Type | Direction | Payload | Notes |
|---|---|---|---|
| `host` | client -> server | `{username}` | Request room creation. |
| `join` | client -> server | `{room, username}` | Request join. |
| `set_hero` | client -> server | `{hero}` | Lobby selection. |
| `set_settings` | host -> server | `{settings}` | Map, starter crops, etc. |
| `start_game` | host -> server | `{}` | Server broadcasts `game_start`. |
| `hosted` / `joined` / `lobby_state` / `game_start` | server -> client | various | Room lifecycle. |
| `became_host` | server -> client | - | Host migration when previous host leaves. |
| `kicked` | server -> target | - | Host kicked them. |

### Input / state

| Type | Dir | Fields | Handler |
|---|---|---|---|
| `input` | client -> broadcast (30 Hz + edges) | `pid, m[2], a[2], sp, sh, d, shj, r, a1, a2, ul, dr` | `GameManager._on_message` -> `net_inputs[pid].receive_input` |
| `client_state` | client -> host | `id, x, y, r, vx, vy, dash, cc, hc?, hs?` | Host only consumes `hc/hs` (held crop); position is host-authoritative. |
| `state_sync` | host -> broadcast (10 Hz) | `states:[{id,x,y,r,vx,vy,dash,drug,hp,ult OR ucd,ammo,cc,stun,spec,dead,await_resp,hc?,hs?,invis?}]` | Clients apply corrections, interpolate remote targets. |
| `stats_sync` | host -> broadcast | `{s:{str(pid):{k,d}}}` | Kill/death leaderboard. Broadcast on death and just before `game_over`. |
| `pos_report` | all -> server telemetry | snapshot for desync debugging | server-side only. |

### Projectiles / abilities

| Type | Dir | Fields | Notes |
|---|---|---|---|
| `burple_grenade_req` | client -> host | `pid, gid, tx, ty` | Client asks to spawn. |
| `burple_grenade_spawn` | host -> broadcast | `pid, gid, sx, sy, tx, ty` | Host authoritative. |
| `burple_grenade_boom` | host -> broadcast | `gid, x, y` | Forces remote grenade to explode visually. |
| `burple_strike_req` / `_spawn` / `_pulse` / `_end` | like above | Burple ult. |
| `xf_stance_req` / `xf_stance` | client -> host -> broadcast | Xyler/Fergus stance. |
| `xf_mark_hit` / `xf_slash` | client -> host / host -> broadcast | Fergus marks, Xyler slash (host-auth damage). |
| `muskrat_ult_req` / `_spawn` / `_tp_req` / `_tp` / `_end` | grouped | Cybertruck ult. |
| `muskrat_hold_steal_req` / `muskrat_hold_steal` | crop steal (Elon ability1). |
| `dingus_orbital_req` / `_spawn` | AnderDingus ult. |
| `fie_placed` / `fie_destroyed` | Garebare FIE blocks. |
| `ult_used` | host -> broadcast | `pid` - triggers ult banner. |

### Crops / spawners

| Type | Notes |
|---|---|
| `crop_planted` | Client asks host to plant; host broadcasts. |
| `crop_uproot` | Client -> host; host rebroadcasts as `crop_removed`. |
| `crop_removed` | Host -> all, applies removal + attributes to thief. |
| `crop_dropped` | Dropper -> broadcast. Carries `cid = "dr:<pid>:<seq>"`. |
| `crop_pickup` | Picker -> broadcast. Carries `cid` (`"sp:<sid>:<seq>"` or `"dr:<pid>:<seq>"`). Host arbitrates first-arrival by id; rejects the loser with `crop_pickup_reject`. |
| `crop_pickup_reject` | Host -> loser. `{cid, x, y}` -> forces the loser to `force_clear_held_crop_local`. |
| `crop_spawned` / `crop_bring` / `spawner_stage` | Host-only broadcast (spawner state). `crop_spawned` includes `cid` so clients instantiate the visual crop with the same stable identity. |
| `farm_spawns` | Host -> clients (player-farm assignments). |

### Lifecycle

| Type | Notes |
|---|---|
| `game_over` | Host authoritative; `{winner}`. |
| `sudden_death` | Host broadcast. |
| `tp_used` | Teleporter used (cooldown sync). |

## Networking gotchas

- **WebSocket is FIFO** per connection; no ordering guarantees across peers. All logic assumes eventual consistency.
- **No application-level ACKs or retries.** A dropped message stays dropped. Critical state (HP, ult, crops) is idempotent via `state_sync` re-broadcasts.
- **Input broadcast is 30 Hz + edges.** `*_just` flags always send immediately; continuous flags piggy-back on the 30 Hz tick. Never rely on 60 Hz granularity.
- **State sync is 20 Hz** (see `SYNC_INTERVAL = 0.05`). Don't add per-frame broadcasts; keep the payload lean.
- **Remote position interpolation** uses `POSITION_LERP_SPEED = 22.0` and snaps if error > `POSITION_SNAP_THRESHOLD = 200 px`.
- **Local-player position reconciliation (strict)**: on each `state_sync`, clients rubber-band their own body toward the host's authoritative position. Small drift (<`LOCAL_POS_IGNORE` = 4 px) is ignored; moderate drift lerps by `LOCAL_POS_LERP_FRAC = 0.5` per tick; a drift > `LOCAL_POS_SNAP` = 160 px hard-snaps. Reconciliation is skipped while `is_dashing / is_dying / in_spectate_mode / is_awaiting_respawn` to avoid fighting those transient states. This is what stops position desync from cascading into crop-pickup / hurtbox / killzone desyncs. See `GameManager._reconcile_local_position`.
- **World crop identity** is tracked in `GameManager._world_crops` (host-only registry; also maintained on clients so `_handle_crop_pickup` can remove the visual crop by id when the host broadcasts). Any pickable crop created in the world (spawner output or player drop) must call `GameManager.register_world_crop(crop)` after attaching to the tree. Pickup arbitration always tries `_find_world_crop_by_id(cid)` first, falling back to `_find_world_crop_at(pos)` only for legacy / id-less crops.
- **RNG is a desync trap.** `randf_range` / `randi` on clients must be seeded from a synced id OR host-only. Precedent: `HeroElongatedMuskrat._do_shoot` seeds a per-player `_spread_rng` by `(pid * 1_000_003) ^ _shot_seq`.
- **Per-peer state that must NOT drift**: `is_marked`, mark duration, stun duration - rely on `state_sync` to converge. Don't branch gameplay on these locally without a server signal.
- **`_host_held_crops` lives on the host only.** Don't read it from clients.
- **Farm group lookups are cached per-frame** in `GameManager.get_farms()`. New farms spawning mid-game would need an explicit invalidation; today farms are static.
- **`ult_mode` matters for state_sync.** If you add a new hero, set `ult_mode = UltMode.COOLDOWN` in `_ready` before calling `super._ready()` if you don't want `ult_points` to be stomped. The sync path writes `ucd` vs `ult` depending on mode.
- **Respawn is host-driven.** `_on_player_died` is host-only and schedules `respawn_at` after `RESPAWN_DELAY`. Clients clear `is_awaiting_respawn` purely via the `dead=false && await_resp=false` transition in `_apply_corrections`. If you add new death/respawn state, it MUST flow through `state_sync` or the client's local player will hang at "Respawning in 0s".
- **Don't stream inputs from a dead/respawning/spectating local player.** `NetworkInput._player_uncontrollable()` strips the payload to idle (same as `menu_pause_local`). Without this, the host keeps simulating the client body from stale inputs because `input.update()` runs before `_physics_process` early-returns.

## How to add a networked ability (pattern)

1. **Client-local trigger in hero.gd subclass.** Build a unique id `"%d:%d" % [pid, seq]` (prevents reconstruction-order collisions during host migration).
2. **Route through `GameManager`** with a `cast_<name>` helper:
   - If `mode == ONLINE_CLIENT`: `Network.send_to_host({"type":"<name>_req", ...})` and return.
   - Else (`LOCAL` or `ONLINE_HOST`): call `_spawn_<name>(..., authoritative=true)` locally. If host, `Network.broadcast({"type":"<name>_spawn", ...})`.
3. **Host handler** `_handle_<name>_req(from_id, data)`: validate `pid == from_id`, then call `cast_<name>`.
4. **Client handler** `_handle_<name>_spawn(data)`: call `_spawn_<name>(data, authoritative=false)`.
5. **`_spawn_<name>`**: dedupe on id (reject if already exists), instantiate scene, set `authoritative` flag, register in dict, connect `tree_exited` cleanup. Or use `ProjectileNet` (`scripts/net/projectile_net.gd`), which handles dedupe/cleanup/tree_exited bookkeeping for you.
6. **In the spawned scene**: gate `_apply_damage` with `if not authoritative: return`. Same for FX timings that must match across peers (let host broadcast `*_pulse` / `*_end` messages instead of relying on local timers).
7. **Also clear the new registry** in `GameManager.clear_players()` (and any dict you add - disconnects reset state).

Template reference: `GameManager.cast_burple_grenade` + `scenes/heroes/burple/grenade.gd`.

## Known limitations

- No reconciliation for actions lost to packet loss (dropped `shoot_just`, etc.). We rely on edges-always-send + input buffer merging in `NetworkInput._apply_buffered_input` to minimise the damage.
- No rollback. Host sim authoritative but client-side visuals for bullets may hit where host never registers a hit (and vice versa).
- Host migration (`became_host`) exists but is incomplete: projectile registries are not rebuilt for the new host; crops/stats may desync at migration. If you touch this, also rebuild `_host_held_crops` from connected clients and the remaining projectiles.
- Per-peer RNG anywhere = desync. Always audit new `randf`/`randi` additions. Prefer `RandomNumberGenerator` seeded from `(pid, event_seq)`.

## Deferred refactors (not done in current cleanup pass)

- Full split of `GameManager` into `net_sync.gd` / `projectile_net.gd` / `crop_net.gd` modules. `ProjectileNet` scaffold exists; state migration from `GameManager` still pending. Current state works correctly; split is organizational.
- Full split of `Player` into `movement / crops / hud` modules. File is already section-delimited with `# --- ... ---`; incremental extraction is safer than a big-bang refactor.
- Porting every hero to the `Ability` resource. Base class is in place (`scripts/heroes/ability.gd`); heroes can migrate one at a time.

## Plan (historical reference)

See `.cursor/plans/sync-cleanup-refactor_4d9465ce.plan.md` for the full phased plan that this document tracked. All listed todos have been executed except for the architectural splits noted above.
