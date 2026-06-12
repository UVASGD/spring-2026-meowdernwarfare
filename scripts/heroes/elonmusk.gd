class_name HeroElongatedMuskrat
extends Hero

const FlameScene = preload("res://scenes/heroes/elonmusk/muskrat_flame.tscn")

@export_group("Shoot")
@export var flame_damage: float = 5.0
@export var flame_speed: float = 330.0
@export var flame_life: float = 1.25
@export var flame_spread_deg: float = 5.0

@export_group("Crop Magnet")
@export var magnet_range: float = Player.INTERACT_RANGE
@export var magnet_window: float = 5.0

@export_group("Cybertruck Ult")
@export var ult_range: float = 520.0
@export var ult_zone_radius: float = 420.0
@export var ult_duration: float = 10.0
@export var ult_tp_cd: float = 0.5
@export var ult_line_damage: float = 22.0
@export var ult_line_life: float = 1.0
@export var ult_explosion_damage: float = 40.0
@export var anim_debug_logs: bool = true

var _magnet_left := 0.0
var _ult_seq := 0
var _shot_seq: int = 0
var _spread_rng := RandomNumberGenerator.new()
var _shoot_armed := false
var _shoot_starting := false
var _shoot_start_token := 0
var _ability1_start_token := 0
var _ult_hidden := false
var _last_shoot_ms: int = -1
var _shoot_hold_until_ms: int = -1
var _shoot_burst_active := false

@onready var _magnet_ring: Node2D = $MagnetRing

func _ready() -> void:
	_setup_placeholder_frames()
	super._ready()
	_configure_anim_loops()
	_refresh_viz()

func _process(delta: float) -> void:
	super._process(delta)
	if _is_local_owner() and player and player.input:
		if player.input.shoot_just:
			_log_anim("click shoot_just")
		if player.input.ability1_just:
			_log_anim("click ability1_just")
		if player.input.ult_just:
			_log_anim("click ult_just")
	_update_shoot_hold_state()
	if not _is_ult_active_local() and _ult_hidden:
		set_ult_hidden(false)
	if _magnet_left > 0.0:
		_magnet_left = maxf(0.0, _magnet_left - delta)
		if _is_local_owner():
			if _try_steal_held_crop():
				_magnet_left = 0.0
			elif _player_wants_aim_steal():
				if _try_steal_planted_crop():
					_magnet_left = 0.0
	_refresh_viz()

func get_hero_name() -> String:
	return "ElonMusk"

func uses_ability1_targeting() -> bool:
	return false

func uses_ult_targeting() -> bool:
	return false

func get_ult_range() -> float:
	return ult_range

func can_shoot() -> bool:
	if _is_ult_active_local():
		return false
	return super.can_shoot()

func can_ability1() -> bool:
	if _is_ult_active_local():
		return false
	return super.can_ability1()

func can_ability2() -> bool:
	if _is_ult_active_local():
		return false
	return super.can_ability2()

func can_ult() -> bool:
	if _is_ult_active_local():
		return false
	return super.can_ult()

func allows_movement_dash() -> bool:
	return not _is_ult_active_local()

func reload() -> void:
	if _is_ult_active_local():
		return
	super.reload()

func blocks_crop_actions() -> bool:
	return _is_ult_active_local()

func _play_action_anim(kind: String) -> void:
	_log_anim("play_action kind=%s" % kind)
	if kind == "shoot":
		_play_shoot_anim()
		return
	if kind == "ability1":
		_play_ability1_anim()
		return
	super._play_action_anim(kind)

func _update_animation(delta: float) -> void:
	if sprite == null or player == null:
		return
	_try_cancel_tap_startup()
	_update_anim_lock()
	if anim_locked:
		return
	if _shoot_starting:
		return
	if _is_ult_active_local():
		return
	if _is_shoot_loop_active():
		_play_hold_loop("shoot")
		return
	if _magnet_left > 0.0:
		_play_hold_loop("ability1")
		return
	super._update_animation(delta)

func _do_shoot(aim_dir: Vector2, _aim_pos: Vector2) -> void:
	_shot_seq += 1
	var pid = player.player_id if player else 0
	# Deterministic seed: every peer computes the same spread for this shot.
	_spread_rng.seed = (pid * 1_000_003) ^ _shot_seq
	var spread := deg_to_rad(_spread_rng.randf_range(-flame_spread_deg, flame_spread_deg))
	var b = FlameScene.instantiate()
	b.owner_player = player
	b.damage = flame_damage
	b.speed = flame_speed
	b.life = flame_life
	b.dir = aim_dir.rotated(spread).normalized()
	b.global_position = $Marker2D.global_position + aim_dir * 10.0
	b.rotation = b.dir.angle()
	get_tree().current_scene.add_child(b)

func _do_ability1(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
	_magnet_left = magnet_window
	_refresh_viz()

func _do_ult(_aim_dir: Vector2, _aim_pos: Vector2) -> void:
	_start_ult_after_anim()

func _start_ult_after_anim() -> void:
	if not _is_local_owner():
		return
	await get_tree().create_timer(maxf(ult_anim_duration, 0.0)).timeout
	if player == null or not is_instance_valid(player) or is_dead:
		return
	var gm := GameManager.instance
	if gm == null:
		return
	_ult_seq += 1
	var center := player.global_position
	var uid := "%s:%s" % [player.player_id, _ult_seq]
	gm.cast_muskrat_ult(player.player_id, center, uid, _ult_pack())

func _is_local_owner() -> bool:
	var gm := GameManager.instance
	if gm == null or gm.is_local():
		return true
	return player and player.player_id == gm.local_player_id

func _is_ult_active_local() -> bool:
	var gm := GameManager.instance
	if gm == null or player == null:
		return false
	return gm.has_muskrat_ult_for_owner(player.player_id)

func _refresh_viz() -> void:
	if _magnet_ring:
		_magnet_ring.visible = _magnet_left > 0.0
		_magnet_ring.scale = Vector2.ONE * (magnet_range / 64.0)
		_magnet_ring.modulate.a = 0.15 + 0.18 * clamp(_magnet_left / maxf(magnet_window, 0.001), 0.0, 1.0)

func _player_wants_aim_steal() -> bool:
	return player and player.input and player.input.shoot_just

func _try_steal_held_crop() -> bool:
	if player == null or not player.can_receive_held_crop():
		return false
	for node in get_tree().get_nodes_in_group("players"):
		if not (node is Player):
			continue
		var victim := node as Player
		if victim == player:
			continue
		if victim.global_position.distance_to(player.global_position) > magnet_range:
			continue
		var d: Dictionary = victim.get_any_held_crop_data()
		if d.is_empty():
			continue
		var gm := GameManager.instance
		if gm:
			gm.request_muskrat_held_steal(player.player_id, victim.player_id, d.get("type", ""), int(d.get("stage", 1)))
			return true
	return false

func _try_steal_planted_crop() -> bool:
	if player == null or not player.can_receive_held_crop():
		return false
	var aim: Vector2 = player.get_aim_position()
	for f in get_tree().get_nodes_in_group("farms"):
		var tiles := _plantable_tiles(f)
		var tile := _tile_at_pos(tiles, aim)
		if tile == null or tile.planted_crop == null:
			continue
		if tile.global_position.distance_to(player.global_position) > magnet_range:
			continue
		var idx := tiles.find(tile)
		var crop: Crop = f.remove_crop(tile.planted_crop)
		if crop == null:
			continue
		var victim := f.get("_owner") as Player
		if victim:
			victim.crop_count -= 1
		player.pickup_world_crop(crop)
		var gm := GameManager.instance
		if gm and not gm.is_local() and victim:
			gm.send_crop_uproot(victim.player_id, idx, crop.get_type_id(), crop.stage)
		return true
	return false

func _plantable_tiles(farm: Node) -> Array:
	var out: Array = []
	var tm = farm.get_node_or_null("TileMapLayer")
	if tm == null:
		return out
	for c in tm.get_children():
		if c.has_method("plant"):
			out.append(c)
	return out

func _tile_at_pos(tiles: Array, pos: Vector2) -> Node:
	for t in tiles:
		if t.global_position.distance_to(pos) <= Player.TILE_HALF:
			return t
	return null

func _clamp_range(target: Vector2, max_range: float) -> Vector2:
	var off := target - player.global_position
	if off.length() <= max_range:
		return target
	return player.global_position + off.normalized() * max_range

func _ult_pack() -> Dictionary:
	return {
		"radius": ult_zone_radius,
		"dur": ult_duration,
		"tp": ult_tp_cd,
		"ldmg": ult_line_damage,
		"llife": ult_line_life,
		"edmg": ult_explosion_damage
	}

func _setup_placeholder_frames() -> void:
	if sprite == null:
		return
	var tex: Texture2D = load("res://assets/sprites/icon.svg") as Texture2D
	if tex == null:
		return
	var sf := SpriteFrames.new()
	for anim_name in ["idle", "run", "shoot", "ability1", "ult", "reload", "death"]:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, anim_name == "idle" or anim_name == "run")
		sf.add_frame(anim_name, tex, 1.0)
	sprite.sprite_frames = sf
	sprite.modulate = Color(0.66, 0.79, 0.92, 1.0)

func set_ult_hidden(hide: bool) -> void:
	_ult_hidden = hide
	if sprite:
		sprite.visible = not hide
	_log_anim("set_ult_hidden hide=%s" % hide)

func _configure_anim_loops() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	for name in ["shoot_start_idle", "shoot_start_run", "ability1_start_idle", "ability1_start_run"]:
		if sprite.sprite_frames.has_animation(name):
			sprite.sprite_frames.set_animation_loop(name, false)
	for name in ["shoot_idle", "shoot_run", "ability1_idle", "ability1_run"]:
		if sprite.sprite_frames.has_animation(name):
			sprite.sprite_frames.set_animation_loop(name, true)

func _play_shoot_anim() -> void:
	var now := Time.get_ticks_msec()
	_last_shoot_ms = now
	_shoot_hold_until_ms = now + int(maxf(shoot_cooldown * 2.5 * 1000.0, 220.0))
	_shoot_burst_active = true
	var moving := false
	if player and "velocity" in player:
		moving = player.velocity.length() > 10.0
	var phase := "run" if moving else "idle"
	var start_anim := "shoot_start_%s" % phase
	var loop_anim := "shoot_%s" % phase
	if not _shoot_armed and not _shoot_starting and _has_anim(start_anim):
		_shoot_armed = true
		_shoot_starting = true
		_play_anim_candidates(PackedStringArray([start_anim, loop_anim, "shoot", "idle"]), "shoot")
		_log_anim("shoot start=%s loop=%s" % [start_anim, loop_anim])
		_shoot_start_token += 1
		_queue_followup(loop_anim, _shoot_start_token, true)
		return
	_shoot_armed = true
	_log_anim("shoot loop direct=%s" % loop_anim)
	_play_anim_candidates(PackedStringArray([loop_anim, "shoot", "idle"]), "shoot")

func _play_ability1_anim() -> void:
	var moving := false
	if player and "velocity" in player:
		moving = player.velocity.length() > 10.0
	var phase := "run" if moving else "idle"
	var start_anim := "ability1_start_%s" % phase
	var loop_anim := "ability1_%s" % phase
	if _has_anim(start_anim):
		_play_anim_candidates(PackedStringArray([start_anim, loop_anim, "ability1", "idle"]), "ability1")
		_log_anim("ability1 start=%s loop=%s" % [start_anim, loop_anim])
		_ability1_start_token += 1
		_queue_followup(loop_anim, _ability1_start_token, false)
		return
	_log_anim("ability1 loop direct=%s" % loop_anim)
	_play_anim_candidates(PackedStringArray([loop_anim, "ability1", "idle"]), "ability1")

func _queue_followup(next_anim: String, token: int, needs_shoot_held: bool) -> void:
	var wait_t := _anim_length(String(sprite.animation))
	if wait_t <= 0.0:
		wait_t = 0.08
	_followup_after_delay(next_anim, token, wait_t, needs_shoot_held)

func _followup_after_delay(next_anim: String, token: int, wait_t: float, needs_shoot_held: bool) -> void:
	await get_tree().create_timer(wait_t).timeout
	if player == null or not is_instance_valid(player) or is_dead:
		return
	if needs_shoot_held:
		if token != _shoot_start_token:
			return
		_shoot_starting = false
		if player.input == null or not player.input.shoot:
			return
	else:
		if token != _ability1_start_token:
			return
	if _has_anim(next_anim):
		sprite.play(next_anim)
		current_anim = next_anim
		_log_anim("followup -> %s" % next_anim)

func _has_anim(name: String) -> bool:
	return sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(name)

func _anim_length(anim_name: String) -> float:
	if sprite == null or sprite.sprite_frames == null:
		return 0.0
	if not sprite.sprite_frames.has_animation(anim_name):
		return 0.0
	var fps := maxf(sprite.sprite_frames.get_animation_speed(anim_name), 0.01)
	var frames := sprite.sprite_frames.get_frame_count(anim_name)
	var total := 0.0
	for i in range(frames):
		total += sprite.sprite_frames.get_frame_duration(anim_name, i) / fps
	return total

func _play_hold_loop(kind: String) -> void:
	var moving := false
	if player and "velocity" in player:
		moving = player.velocity.length() > 10.0
	var phase := "run" if moving else "idle"
	var loop_anim := "%s_%s" % [kind, phase]
	var cands := PackedStringArray([loop_anim, "%s_idle" % kind, kind, "run", "idle"])
	for name in cands:
		if _has_anim(name):
			if String(sprite.animation) != name:
				sprite.play(name)
				current_anim = name
				_log_anim("hold_loop %s -> %s" % [kind, name])
			return

func _log_anim(msg: String) -> void:
	if not anim_debug_logs:
		return
	var pid = player.player_id if player else -1
	print("[elon_anim pid=%d] %s | anim=%s locked=%s skill=%s shoot_armed=%s shoot_starting=%s magnet=%.2f" % [
		pid,
		msg,
		String(sprite.animation) if sprite else "none",
		str(anim_locked),
		lock_skill,
		str(_shoot_armed),
		str(_shoot_starting),
		_magnet_left
	])

func _update_shoot_hold_state() -> void:
	if _is_ult_active_local():
		if _shoot_armed or _shoot_starting:
			_log_anim("reset shoot state: ult active")
		_shoot_armed = false
		_shoot_starting = false
		_shoot_burst_active = false
		_shoot_hold_until_ms = -1
		return
	if _shoot_hold_until_ms < 0:
		return
	var now := Time.get_ticks_msec()
	if now > _shoot_hold_until_ms:
		if _shoot_armed or _shoot_starting or _shoot_burst_active:
			_log_anim("reset shoot state: burst ended")
		_shoot_armed = false
		_shoot_starting = false
		_shoot_burst_active = false
		_shoot_hold_until_ms = -1

func _try_cancel_tap_startup() -> void:
	if not _shoot_starting:
		return
	var now := Time.get_ticks_msec()
	if _last_shoot_ms < 0:
		return
	if _shoot_hold_until_ms >= 0 and now <= _shoot_hold_until_ms:
		return
	var cut_ms := int(maxf(shoot_cooldown * 1.6 * 1000.0, 120.0))
	if now - _last_shoot_ms <= cut_ms:
		return
	_shoot_starting = false
	_shoot_armed = false
	_shoot_burst_active = false
	_shoot_start_token += 1
	if anim_locked and lock_skill == "shoot":
		_clear_anim_lock()
	_play_anim_candidates(PackedStringArray(["run", "idle"]), "shoot_cancel")
	_log_anim("cut startup (tap release)")

func _is_shoot_loop_active() -> bool:
	if _is_ult_active_local():
		return false
	if not _shoot_burst_active:
		return false
	if _shoot_hold_until_ms < 0:
		return false
	return Time.get_ticks_msec() <= _shoot_hold_until_ms
