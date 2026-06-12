class_name HeroBurple
extends Hero

const BulletScene = preload("res://scenes/heroes/dealer/bullet.tscn")

@export var grenade_range: float = Player.INTERACT_RANGE
@export var strike_range: float = Player.INTERACT_RANGE

var _grenade_id := 0
var _strike_id := 0
var _weapon_drawn := false
var _weapon_drawing := false
var _weapon_token := 0
var _weapon_hold_until := -1
var _ability_draw_mode := ""

func _ready() -> void:
	super._ready()
	_config_anims()

func _process(delta: float) -> void:
	super._process(delta)
	_update_weapon_state()

func get_hero_name() -> String:
	return "Burple"

func target_mode_started(mode: String) -> void:
	if mode == "a1":
		_play_ability_draw()

func target_mode_cancelled(mode: String) -> void:
	if mode != "a1":
		return
	if _ability_draw_mode == "":
		return
	_ability_draw_mode = ""
	if anim_locked and lock_skill == "ability1" and String(sprite.animation).contains("drawback"):
		_clear_anim_lock()

func _play_action_anim(kind: String) -> void:
	if kind == "shoot":
		_play_weapon_anim("shoot")
		return
	if kind == "reload":
		_play_weapon_anim("reload")
		return
	if kind == "ability1":
		_play_ability_launch()
		return
	if kind == "ult":
		_play_moving_anim("ult")
		return
	super._play_action_anim(kind)

func uses_ability1_targeting() -> bool:
	return true

func get_ability1_range() -> float:
	return grenade_range

func uses_ult_targeting() -> bool:
	return true

func get_ult_range() -> float:
	return strike_range

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	bullet.global_position = player.global_position + aim_dir * 30
	bullet.rotation = aim_dir.angle()
	get_tree().current_scene.add_child(bullet)

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var gm := GameManager.instance
	if gm == null or player == null:
		return
	if not gm.is_local() and player.player_id != gm.local_player_id:
		return
	_grenade_id += 1
	gm.cast_burple_grenade(player.player_id, aim_pos, "%s:%s" % [player.player_id, _grenade_id])

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var gm := GameManager.instance
	if gm == null or player == null:
		return
	if not gm.is_local() and player.player_id != gm.local_player_id:
		return
	_strike_id += 1
	gm.cast_burple_strike(player.player_id, aim_pos, "%s:%s" % [player.player_id, _strike_id])

func _config_anims() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	for name in ["shoot_start_idle", "shoot_start_run", "shoot_idle", "shoot_run", "reload_idle", "reload_run", "ability1_idle_drawback", "ability1_run_drawback", "ability1_idle_launch", "ability1_run_launch"]:
		if sprite.sprite_frames.has_animation(name):
			sprite.sprite_frames.set_animation_loop(name, false)

func _play_ability_draw() -> void:
	var anim := _phase_anim("ability1", "drawback")
	_ability_draw_mode = anim
	_begin_skill("ability1")
	_play_anim_candidates(PackedStringArray([anim, "ability1_idle_drawback", "ability1", "idle"]), "ability1_draw")
	_lock_current("ability1")

func _play_ability_launch() -> void:
	_ability_draw_mode = ""
	var anim := _phase_anim("ability1", "launch")
	_play_anim_candidates(PackedStringArray([anim, "ability1_idle_launch", "ability1", "idle"]), "ability1")

func _play_weapon_anim(kind: String) -> void:
	var body := _phase_anim(kind)
	var draw := _phase_anim("shoot_start")
	var hold_ms := int(maxf(1000.0 * maxf(shoot_cooldown * 2.5, reload_time), 300.0))
	_weapon_hold_until = Time.get_ticks_msec() + hold_ms
	if not _weapon_drawn and not _weapon_drawing and _has_anim(draw):
		_weapon_drawing = true
		_weapon_drawn = true
		_weapon_token += 1
		_play_anim_candidates(PackedStringArray([draw, body, kind, "idle"]), kind)
		_queue_after_draw(body, kind, _weapon_token)
		return
	_weapon_drawn = true
	_play_anim_candidates(PackedStringArray([body, "%s_idle" % kind, kind, "idle"]), kind)

func _queue_after_draw(anim: String, skill: String, token: int) -> void:
	var wait := _anim_len(String(sprite.animation))
	if wait <= 0.0:
		wait = 0.08
	await get_tree().create_timer(wait).timeout
	if token != _weapon_token or player == null or not is_instance_valid(player) or is_dead:
		return
	_weapon_drawing = false
	if _has_anim(anim):
		sprite.play(anim)
		current_anim = anim
		_lock_current(skill)

func _update_weapon_state() -> void:
	if _weapon_hold_until < 0:
		return
	if Time.get_ticks_msec() <= _weapon_hold_until:
		return
	_weapon_drawn = false
	_weapon_drawing = false
	_weapon_hold_until = -1
	_weapon_token += 1

func _play_moving_anim(kind: String) -> void:
	var anim := _phase_anim(kind)
	_play_anim_candidates(PackedStringArray([anim, "%s_idle" % kind, kind, "idle"]), kind)

func _phase_anim(kind: String, suffix := "") -> String:
	var phase := "idle"
	if player and "velocity" in player and player.velocity.length() > 10.0:
		phase = "run"
	return "%s_%s%s" % [kind, phase, "_%s" % suffix if suffix != "" else ""]

func _lock_current(skill: String) -> void:
	if sprite == null:
		return
	var anim := String(sprite.animation)
	if anim == "" or anim == "idle" or anim == "run":
		return
	lock_skill = skill
	lock_anim = anim
	current_anim = anim
	anim_locked = true

func _has_anim(name: String) -> bool:
	return sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(name)

func _anim_len(anim: String) -> float:
	if not _has_anim(anim):
		return 0.0
	var fps := maxf(sprite.sprite_frames.get_animation_speed(anim), 0.01)
	var total := 0.0
	for i in range(sprite.sprite_frames.get_frame_count(anim)):
		total += sprite.sprite_frames.get_frame_duration(anim, i) / fps
	return total
