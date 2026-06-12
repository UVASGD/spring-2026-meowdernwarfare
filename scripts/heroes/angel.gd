class_name HeroAnimeGirl
extends Hero

const BulletScene = preload("res://scenes/heroes/dealer/bullet.tscn")
const SonicBurstScene = preload("res://scenes/heroes/garebare/sonic_burst.tscn")

@export_group("Evolution")
@export var stage2_crop_req: int = 4
@export var stage3_crop_req: int = 7

@export_group("Shoot")
@export var shot_damage: float = 14.0
@export var shot_speed: float = 820.0
@export var shot_range: float = 260.0
@export var shot_color: Color = Color(1.0, 0.45, 0.85, 1.0)

@export_group("Light Blast (Ability 1)")
@export var a1_range: float = Player.INTERACT_RANGE
@export var a1_radius: float = 180.0
@export var a1_tick_damage: float = 7.0
@export var a1_tick_interval: float = 0.25
@export var a1_duration: float = 3.5

@export_group("Divine Judgement (Ult)")
@export var ult_range_target: float = 680.0
@export var ult_radius: float = 360.0
@export var ult_tick_damage: float = 7.0
@export var ult_tick_interval: float = 0.12
@export var ult_duration: float = 6.0
@export var ult_cd_seconds: float = 30.0

@export_group("Light Node")
@export var stage2_light_energy: float = 1.2
@export var stage3_light_energy: float = 2.2

var evo_stage := 1
var max_seen_crops := 0
var _zone_seq := 0
var _move_state := ""

@onready var _light: PointLight2D = get_node_or_null("light")

func _ready() -> void:
	ult_mode = UltMode.COOLDOWN
	ult_cooldown = ult_cd_seconds
	super._ready()
	_apply_stage_visuals(true)

func _process(delta: float) -> void:
	super._process(delta)
	_update_stage()

func get_hero_name() -> String:
	return "AnimeGirl"

func uses_gun_ammo() -> bool:
	return false

func can_shoot() -> bool:
	return shoot_cd <= 0.0 and not is_dead and not _is_action_blocked()

func shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	if not can_shoot():
		return
	shoot_cd = shoot_cooldown
	_begin_skill("shoot")
	_play_action_anim("shoot")
	_capture_skill_anim()
	shot.emit()
	SfxBus.play_world(SfxEvent.WEAPON_SHOOT, player.global_position if player else global_position)
	_do_shoot(aim_dir, aim_pos)

func reload() -> void:
	return

func can_ability1() -> bool:
	if evo_stage < 2 or is_dead:
		return false
	return super.can_ability1()

func can_ult() -> bool:
	if evo_stage < 3 or is_dead:
		return false
	return super.can_ult()

func uses_ability1_targeting() -> bool:
	return true

func get_ability1_range() -> float:
	return a1_range

func uses_ult_targeting() -> bool:
	return true

func get_ult_range() -> float:
	return ult_range_target

func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	bullet.damage = int(round(shot_damage))
	bullet.speed = shot_speed
	bullet.lifetime = maxf(0.05, shot_range / maxf(shot_speed, 1.0))
	bullet.global_position = player.global_position + aim_dir * 30.0
	bullet.rotation = aim_dir.angle()
	var spr: Sprite2D = bullet.get_node_or_null("Sprite2D")
	if spr:
		spr.visible = false
	var burst_viz := _make_sonic_burst_viz()
	if burst_viz:
		bullet.add_child(burst_viz)
		if burst_viz is Node2D:
			(burst_viz as Node2D).rotation = PI / 2.0
		if burst_viz is CanvasItem:
			(burst_viz as CanvasItem).modulate = shot_color
	var light: PointLight2D = bullet.get_node_or_null("PointLight2D2")
	if light:
		light.color = shot_color
		light.energy = 1.2
	get_tree().current_scene.add_child(bullet)

func _make_sonic_burst_viz() -> Node2D:
	var burst := SonicBurstScene.instantiate()
	var src: Sprite2D = burst.get_node_or_null("Sprite2D")
	var out: Node2D = null
	if src:
		out = src.duplicate() as Node2D
	burst.queue_free()
	if out == null:
		return null
	if out is Sprite2D:
		var s := out as Sprite2D
		if s.material is ShaderMaterial:
			var m := (s.material as ShaderMaterial).duplicate() as ShaderMaterial
			m.set_shader_parameter("color", shot_color)
			s.material = m
	return out

func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	_cast_zone(aim_pos, {
		"rad": a1_radius,
		"dmg": a1_tick_damage,
		"itv": a1_tick_interval,
		"dur": a1_duration,
		"k": 1
	})

func _do_ult(aim_dir: Vector2, aim_pos: Vector2) -> void:
	_cast_zone(aim_pos, {
		"rad": ult_radius,
		"dmg": ult_tick_damage,
		"itv": ult_tick_interval,
		"dur": ult_duration,
		"k": 2
	})

func _cast_zone(at: Vector2, cfg: Dictionary) -> void:
	var gm := GameManager.instance
	if gm == null or player == null:
		return
	if not gm.is_local() and player.player_id != gm.local_player_id:
		return
	_zone_seq += 1
	var zid := "%s:%s" % [player.player_id, _zone_seq]
	gm.cast_animegirl_zone(player.player_id, at, zid, cfg)

func get_net_stage() -> int:
	return evo_stage

func apply_net_stage(stage: int) -> void:
	var next_stage := clampi(stage, 1, 3)
	if next_stage <= evo_stage:
		return
	evo_stage = next_stage
	_apply_stage_visuals(false)

func _update_stage() -> void:
	if player == null:
		return
	max_seen_crops = maxi(max_seen_crops, maxi(0, player.crop_count))
	var next_stage := _stage_from_crop_count(max_seen_crops)
	if next_stage <= evo_stage:
		return
	evo_stage = next_stage
	_apply_stage_visuals(false)

func _stage_from_crop_count(crops: int) -> int:
	if crops >= stage3_crop_req:
		return 3
	if crops >= stage2_crop_req:
		return 2
	return 1

func _apply_stage_visuals(force: bool) -> void:
	if _light:
		if evo_stage <= 1:
			_light.visible = false
			_light.energy = 0.0
		elif evo_stage == 2:
			_light.visible = true
			_light.energy = stage2_light_energy
		else:
			_light.visible = true
			_light.energy = stage3_light_energy
	if force or (sprite and not anim_locked):
		_move_state = ""
		current_anim = ""
		_play_stage_move_anim("idle")

func _update_animation(delta: float) -> void:
	if sprite == null or player == null:
		return
	_update_anim_lock()
	if anim_locked:
		return
	var state := _get_animation_state()
	if state == _move_state:
		return
	_move_state = state
	_play_stage_move_anim(state)

func _play_stage_move_anim(state: String) -> void:
	if state == "run":
		_play_stage_anim(PackedStringArray(["run", "idle"]), "run")
	elif state == "idle":
		_play_stage_anim(PackedStringArray(["idle", "run"]), "idle")
	elif state == "dash":
		_play_stage_anim(PackedStringArray(["dash", "run", "idle"]), "dash")

func _play_action_anim(kind: String) -> void:
	_move_state = ""
	var moving := false
	if player and "velocity" in player:
		moving = player.velocity.length() > 10
	if kind == "shoot":
		if moving:
			_play_stage_anim(PackedStringArray(["shoot_run", "shoot_idle", "shoot", "attack", "run", "idle"]), "shoot")
		else:
			_play_stage_anim(PackedStringArray(["shoot_idle", "shoot", "attack", "idle"]), "shoot")
		return
	if kind == "ability1":
		if moving:
			_play_stage_anim(PackedStringArray(["ability1_run", "ability1_idle", "ability1", "run", "idle"]), "ability1")
		else:
			_play_stage_anim(PackedStringArray(["ability1_idle", "ability1", "idle"]), "ability1")
		return
	if kind == "ult":
		_play_stage_anim(PackedStringArray(["ult_run", "ult_idle", "ult", "idle"]), "ult")
		return
	if kind == "death":
		_play_stage_anim(PackedStringArray(["death", "idle"]), "death")
		return

func _play_stage_anim(bases: PackedStringArray, req: String) -> void:
	var cands := PackedStringArray()
	for base_name in bases:
		cands.append("%d_%s" % [evo_stage, base_name])
	for base_name in bases:
		cands.append(base_name)
	_play_anim_candidates(cands, req)
