class_name Player
extends CharacterBody2D

# Use self.input.X to get input

@export var player_id: int = 0

# Movement tuning
@export var max_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1800.0
@export var sprint_mult: float = 1.5

# Dash tuning
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8

# Rotation
@export var rotation_speed: float = 15.0
@export var rotation_offset: float = -PI/2 

var input: InputProvider = null
var hero: Hero = null

# UI
var health_bar: Control = null
var health_bar_fill: ColorRect = null
var camera: Camera2D = null
var cooldown_ui: CanvasLayer = null
var shoot_cd_bar: ProgressBar = null
var ability1_cd_bar: ProgressBar = null
var reload_cd_bar: ProgressBar = null
var dash_cd_bar: ProgressBar = null
var ammo_label: Label = null
var ult_bar: ProgressBar = null
var ult_label: Label = null
var tooltip_layer: CanvasLayer = null
var tooltip_label: RichTextLabel = null

# State
var aim_dir: Vector2 = Vector2.RIGHT
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO

# Drug effect state
var is_drugged: bool = false
var drug_timer: float = 0.0
var drug_effect_layer: CanvasLayer = null
var drug_effect_rect: ColorRect = null

# Crop state
var crop_count: int = 0
var held_crop: Crop = null
var drop_cd: float = 0.0
const DROP_CD_TIME := 0.5
var held_sprite: Sprite2D = null
var farm = null

# Meta states
var in_spectate_mode: bool = false
var is_ai_player: bool = false
var is_awaiting_respawn: bool = false
var respawn_countdown: float = 0.0
var _death_ui: CanvasLayer = null
var _death_timer_label: Label = null
var is_invulnerable: bool = false
const FARM_RADIUS := 600.0

signal took_damage(amount: float)
signal died
signal dashed

#debug 

var reasonable_timer = 0.0
var reasonable_timer_max = 1.0
# Hero name -> Hero scene mapping
const HERO_SCENES = {
	"Dealer": preload("res://scenes/heroes/dealer/dealer.tscn"),
	"Burple": preload("res://scenes/heroes/burple.tscn"),
	"Alien": preload("res://scenes/heroes/alien.tscn"),
	"Xyler": preload("res://scenes/heroes/xyler.tscn"),
	"Fergus": preload("res://scenes/heroes/fergus.tscn"),
	"LoanShark": preload("res://scenes/heroes/loanshark.tscn"),
}

func _ready() -> void:
	add_to_group("players")
	
	# Default input for testing
	if input == null:
		var local = LocalInput.new(player_id, player_id == 0)
		local.set_player_node(self)
		input = local

	health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.top_level = true
		health_bar_fill = health_bar.get_node_or_null("Fill")
	
	# Camera follows only local players
	camera = get_node_or_null("Camera2D")
	
	# Cooldown UI
	cooldown_ui = get_node_or_null("CooldownUI")
	if cooldown_ui:
		var container = cooldown_ui.get_node_or_null("Container")
		if container:
			shoot_cd_bar = container.get_node_or_null("ShootCD/Bar")
			ability1_cd_bar = container.get_node_or_null("Ability1CD/Bar")
			reload_cd_bar = container.get_node_or_null("ReloadCD/Bar")
			dash_cd_bar = container.get_node_or_null("DashCD/Bar")
			ammo_label = container.get_node_or_null("Ammo/Count")
			ult_bar = container.get_node_or_null("UltCD/Bar")
			ult_label = container.get_node_or_null("UltCD/Count")
	
	# Default hero for testing
	if hero == null:
		set_hero("Dealer")
	
	# Enable camera/UI only for local human players
	_setup_local_ui()
	_setup_crop_area()

func set_hero(hero_name: String) -> void:
	if hero:
		hero.queue_free()
		hero = null
	
	var hero_scene = HERO_SCENES.get(hero_name)
	if hero_scene == null:
		push_warning("Unknown hero: ", hero_name, ", defaulting to Dealer")
		hero_scene = HERO_SCENES["Dealer"]
	
	hero = hero_scene.instantiate()
	hero.player = self
	add_child(hero)
	

	hero.died.connect(_on_hero_died)
	hero.health_changed.connect(_on_hero_health_changed)
	
	# Update hitbox if we have one
	var hitbox = get_node_or_null("CollisionShape2D")
	if hitbox:
		hitbox.shape = hero.get_hitbox_shape()
	
	print("Player ", player_id, " set hero to ", hero.get_hero_name())

func _setup_local_ui() -> void:
	var show_ui = false
	if input is LocalInput:
		show_ui = (player_id == 0)
	elif input is NetworkInput:
		show_ui = input.is_local
	
	if camera:
		camera.enabled = show_ui
	
	if cooldown_ui:
		cooldown_ui.visible = show_ui
	
	if show_ui:
		_create_tooltip()

func _physics_process(delta: float) -> void:
	if input == null:
		return
	
	input.update(delta)
	
	if in_spectate_mode:
		_handle_spectate_movement(delta)
		move_and_slide()
		if input is LocalInput:
			input.end_frame()
		return
	
	if is_awaiting_respawn:
		_update_death_countdown(delta)
		if input is LocalInput:
			input.end_frame()
		return
	
	_update_timers(delta)
	_handle_movement(delta)
	_handle_rotation(delta)
	_handle_actions()
	_handle_crops(delta)
	
	move_and_slide()
	
	if health_bar:
		health_bar.global_position = global_position + Vector2(-25, -60)
	
	_update_cooldown_ui()
	_update_tooltip()
	
	if is_invulnerable:
		_check_farm_invulnerability()
	
	if input is LocalInput:
		input.end_frame()
		


func _update_timers(delta: float) -> void:
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	
	if drop_cd > 0:
		drop_cd -= delta
	
	# Drug effect timer
	if drug_timer > 0:
		drug_timer -= delta
		if drug_timer <= 0:
			_end_drug_effect()

func _handle_movement(delta: float) -> void:
	if is_dashing:
		velocity = dash_dir * dash_speed
		return

	var hero_mult = hero.move_speed_mult if hero else 1.0
	var speed = max_speed * hero_mult * (sprint_mult if input.sprint else 1.0)
	
	var move = input.move_input
	if is_drugged:
		move = -move  # Invert movement when drugged
	
	if move.length() > 0.1:
		velocity = velocity.move_toward(move * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _handle_rotation(delta: float) -> void:
	if input.aim_input.length() > 0.1:
		var aim = input.aim_input.normalized()
		if is_drugged:
			aim = -aim  # Invert aim when drugged
		aim_dir = aim
	
	var target_rot = aim_dir.angle() + rotation_offset
	rotation = lerp_angle(rotation, target_rot, rotation_speed * delta)
	

func _handle_actions() -> void:
	# Dash
	if input.dash_just and dash_cd_timer <= 0 and not is_dashing and not is_dead():
		_start_dash()
	
	if hero == null:
		return
	
	# Delegate to hero
	if input.shoot:
		hero.shoot(aim_dir, get_aim_position())
	if input.ability1_just:
		hero.ability1(aim_dir, get_aim_position())
	if input.ability2_just:
		hero.ability2(aim_dir, get_aim_position())
	if input.reload_just:
		hero.reload()

func _start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cd_timer = dash_cooldown
	dash_dir = aim_dir if input.move_input.length() < 0.1 else input.move_input.normalized()
	dashed.emit()

func _on_hero_died() -> void:
	died.emit()
	if crop_count <= 0:
		enter_spectate_mode()
	else:
		_enter_death_state()

func _on_hero_health_changed(current: float, max_hp: float) -> void:
	_update_health_bar()

# --- PUBLIC API ---

func get_aim_direction() -> Vector2:
	return aim_dir

func get_aim_position() -> Vector2:
	if input:
		return input.aim_position
	return global_position + aim_dir * 100

func is_moving() -> bool:
	return input != null and input.move_input.length() > 0.1

func take_damage(amount: float, attacker: Player = null) -> void:
	if is_dead() or in_spectate_mode or is_awaiting_respawn or is_invulnerable: return
	if is_dashing:
		on_bullet_dodged()
		return
	
	if hero:
		hero.take_damage(amount)
		took_damage.emit(amount)
		# Award ult points to attacker for hitting
		if attacker and attacker.hero:
			attacker.hero.add_ult_points(attacker.hero.ult_points_on_hit)

func on_bullet_dodged() -> void:
	if hero:
		hero.add_ult_points(hero.ult_points_on_dodge)

func heal(amount: float) -> void:
	if hero:
		hero.heal(amount)

func get_health() -> float:
	return hero.health if hero else 0.0

func get_max_health() -> float:
	return hero.max_health if hero else 100.0

func get_health_percent() -> float:
	return hero.get_health_percent() if hero else 0.0

func is_dead() -> bool:
	return hero.is_dead if hero else true

func _update_health_bar() -> void:
	if health_bar_fill == null or hero == null:
		return
	
	var pct = hero.get_health_percent()
	health_bar_fill.scale.x = pct
	
	if pct > 0.5:
		health_bar_fill.color = Color(0.2, 0.8, 0.2)
	elif pct > 0.25:
		health_bar_fill.color = Color(0.8, 0.8, 0.2)
	else:
		health_bar_fill.color = Color(0.8, 0.2, 0.2)

func _update_cooldown_ui() -> void:
	if hero == null or cooldown_ui == null or not cooldown_ui.visible:
		return
	
	if shoot_cd_bar:
		var shoot_pct = 1.0 - (hero.shoot_cd / hero.shoot_cooldown) if hero.shoot_cooldown > 0 else 1.0
		shoot_cd_bar.value = clamp(shoot_pct, 0.0, 1.0)
	
	if ability1_cd_bar:
		var a1_pct = 1.0 - (hero.ability1_cd / hero.ability1_cooldown) if hero.ability1_cooldown > 0 else 1.0
		ability1_cd_bar.value = clamp(a1_pct, 0.0, 1.0)
	
	
	if reload_cd_bar:
		var reload_pct = 1.0 - (hero.reload_cd / hero.reload_time) if hero.reload_time > 0 else 1.0
		reload_cd_bar.value = clamp(reload_pct, 0.0, 1.0)
		
	if dash_cd_bar:
		var dash_pct = 1.0 - (dash_cd_timer / dash_cooldown) if dash_cooldown > 0 else 1.0
		dash_cd_bar.value = clamp(dash_pct, 0.0, 1.0)
	
	if ammo_label:
		ammo_label.text = "%d/%d" % [hero.ammo, hero.mag_size]
	
	if ult_bar:
		ult_bar.value = hero.get_ult_percent()
	if ult_label:
		ult_label.text = "%d/%d" % [hero.ult_points, hero.max_ult_points]

# --- TOOLTIP ---

func _create_tooltip() -> void:
	tooltip_layer = CanvasLayer.new()
	tooltip_layer.layer = 50
	add_child(tooltip_layer)
	
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_label.size = Vector2(200, 60)
	
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.add_child(tooltip_label)
	tooltip_layer.add_child(panel)

func _update_tooltip() -> void:
	if tooltip_label == null:
		return
	
	var panel = tooltip_label.get_parent()
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Query crops under mouse in world space
	var world_mouse = get_global_mouse_position()
	var crop = _find_crop_at(world_mouse)
	
	if crop:
		tooltip_label.text = crop.get_tooltip_bbcode()
		panel.visible = true
		panel.position = mouse_pos + Vector2(16, 16)
	else:
		panel.visible = false

func _find_crop_at(world_pos: Vector2) -> Crop:
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var results = space.intersect_point(params, 8)
	for result in results:
		if result.collider is Crop:
			return result.collider
	
	# Also check planted crops by proximity
	for f in get_tree().get_nodes_in_group("farms"):
		for c in f.crops:
			if is_instance_valid(c) and c.global_position.distance_to(world_pos) < 30.0:
				return c
	return null

# --- CROP SYSTEM ---

var _crop_area: Area2D = null

func _setup_crop_area() -> void:
	_crop_area = Area2D.new()
	_crop_area.collision_layer = 0
	_crop_area.collision_mask = 16
	_crop_area.monitoring = true
	_crop_area.monitorable = false
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	_crop_area.add_child(shape)
	add_child(_crop_area)
	_crop_area.area_entered.connect(_on_crop_area_entered)
	#print("[PLAYER] _setup_crop_area: player_", player_id, " crop pickup area ready (radius=40, mask=0, layer=0)")

func _on_crop_area_entered(area: Area2D) -> void:
	if in_spectate_mode: return
	if area is Crop and held_crop == null and drop_cd <= 0 and not area.is_planted:
		pickup_world_crop(area)

func _handle_crops(_delta: float) -> void:
	if input == null:
		return
	
	# Drop held crop
	if input.drop_just and held_crop != null:
		drop_held_crop()
		return
	
	# Plant held crop (LMB click while holding)
	if input.shoot_just and held_crop != null:
		_try_plant()
		return
	
	# Pick up planted crop (LMB click on planted crop, not holding anything)
	if input.shoot_just and held_crop == null:
		_try_uproot()
	
	if held_sprite and held_crop:
		var behind = -aim_dir.normalized() * 40.0
		held_sprite.global_position = global_position + behind

func pickup_world_crop(crop: Crop) -> void:
	#print("[PLAYER] pickup_world_crop: player_", player_id, " picking up '", crop.crop_name, "' stage=", crop.stage)
	held_crop = crop
	crop.picked_up.emit()
	if crop.get_parent():
		crop.get_parent().remove_child(crop)
	
	held_sprite = Sprite2D.new()
	held_sprite.texture = crop.icon if crop.icon else _make_placeholder_tex(crop)
	held_sprite.scale = Vector2(0.5, 0.5)
	held_sprite.z_index = 10
	get_parent().add_child(held_sprite)
	held_sprite.global_position = global_position + (-aim_dir.normalized() * 40.0)

func drop_held_crop() -> void:
	if held_crop == null:
		return
	#print("[PLAYER] drop_held_crop: player_", player_id, " dropping '", held_crop.crop_name, "'")
	held_crop.global_position = global_position
	get_parent().add_child(held_crop)
	held_crop = null
	drop_cd = DROP_CD_TIME
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null

const INTERACT_RANGE := 400.0
const TILE_HALF := 80.0

func _tile_at_cursor(tiles: Array) -> Node:
	var aim_pos = get_aim_position()
	for tile in tiles:
		if tile.global_position.distance_to(aim_pos) <= TILE_HALF:
			return tile
	return null

func _try_plant() -> void:
	if farm == null or held_crop == null:
		return
	if not farm.has_space():
		return
	
	var tiles = _get_plantable_tiles(farm)
	var aim_pos = get_aim_position()
	var closest_d := INF
	var closest_t: Node = null
	for t in tiles:
		var d = t.global_position.distance_to(aim_pos)
		if d < closest_d:
			closest_d = d
			closest_t = t
	print("[PLANT] aim=", aim_pos, " closest_tile=", closest_t.global_position if closest_t else "NONE", " dist=", snapped(closest_d, 0.1), " TILE_HALF=", TILE_HALF)
	var tile = _tile_at_cursor(tiles)
	if tile == null or tile.planted_crop != null:
		return
	if tile.global_position.distance_to(global_position) > INTERACT_RANGE:
		print("[PLANT] tile out of INTERACT_RANGE: ", tile.global_position.distance_to(global_position))
		return
	
	var crop = held_crop
	held_crop = null
	if held_sprite:
		held_sprite.queue_free()
		held_sprite = null
	
	farm.plant_crop(crop, tile)
	crop_count += 1

func _try_uproot() -> void:
	var farms_list = get_tree().get_nodes_in_group("farms")
	for f in farms_list:
		var tile = _tile_at_cursor(_get_plantable_tiles(f))
		if tile == null or tile.planted_crop == null:
			continue
		if tile.global_position.distance_to(global_position) > INTERACT_RANGE:
			continue
		var crop = f.remove_crop(tile.planted_crop)
		if crop:
			f._owner.crop_count -= 1 if f._owner else 0
			pickup_world_crop(crop)
		return

func _get_plantable_tiles(f) -> Array:
	var tiles: Array = []
	var tilemap = f.get_node_or_null("TileMapLayer")
	if tilemap == null:
		return tiles
	for child in tilemap.get_children():
		if child.has_method("plant"):
			tiles.append(child)
	return tiles

func _make_placeholder_tex(crop: Crop) -> Texture2D:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(crop.get_stage_color())
	return ImageTexture.create_from_image(img)

# --- DRUG EFFECT ---

const DrugShader = preload("res://assets/shaders/drug.gdshader")

func apply_drug_effect(duration: float) -> void:
	# Only show effect for local player
	var is_local = (input is LocalInput and player_id == 0) or (input is NetworkInput and input.is_local)
	
	is_drugged = true
	drug_timer = duration
	
	if is_local:
		_create_drug_effect_layer()

func _create_drug_effect_layer() -> void:
	if drug_effect_layer:
		return
	
	# Create fullscreen shader layer
	drug_effect_layer = CanvasLayer.new()
	drug_effect_layer.layer = 100
	add_child(drug_effect_layer)
	
	drug_effect_rect = ColorRect.new()
	drug_effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	drug_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	mat.shader = DrugShader
	mat.set_shader_parameter("wobble_intensity", 0.025)
	mat.set_shader_parameter("color_intensity", 0.35)
	mat.set_shader_parameter("color_speed", 2.0)
	drug_effect_rect.material = mat
	
	drug_effect_layer.add_child(drug_effect_rect)

func _end_drug_effect() -> void:
	is_drugged = false
	drug_timer = 0.0
	
	if drug_effect_layer:
		drug_effect_layer.queue_free()
		drug_effect_layer = null
		drug_effect_rect = null
		

# ---------- Death / Respawn ----------

func _enter_death_state() -> void:
	is_awaiting_respawn = true
	respawn_countdown = 10.0
	
	if cooldown_ui:
		cooldown_ui.visible = false
	if health_bar:
		health_bar.visible = false
	if tooltip_layer:
		tooltip_layer.visible = false
	if held_crop:
		drop_held_crop()
	if _crop_area:
		_crop_area.monitoring = false
	_disable_collision()
	if hero:
		hero.enter_spectate_mode()
	
	if _is_local_player():
		_show_death_timer_ui()

func _update_death_countdown(delta: float) -> void:
	respawn_countdown -= delta
	if _death_timer_label:
		var secs = ceili(max(respawn_countdown, 0.0))
		_death_timer_label.text = "Respawning in %ds" % secs

func _show_death_timer_ui() -> void:
	_death_ui = CanvasLayer.new()
	_death_ui.layer = 90
	add_child(_death_ui)
	
	_death_timer_label = Label.new()
	_death_timer_label.text = "Respawning in 10s"
	_death_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_timer_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_timer_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_timer_label.add_theme_font_size_override("font_size", 36)
	_death_timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_death_ui.add_child(_death_timer_label)

func respawn_at(pos: Vector2) -> void:
	is_awaiting_respawn = false
	respawn_countdown = 0.0
	
	if _death_ui:
		_death_ui.queue_free()
		_death_ui = null
		_death_timer_label = null
	
	global_position = pos
	
	if hero:
		hero.health = hero.max_health
		hero.is_dead = false
		hero.health_changed.emit(hero.health, hero.max_health)
		var hero_sprite = hero.get_node_or_null("Sprite")
		if hero_sprite:
			hero_sprite.visible = true
	
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", false)
	
	if _crop_area:
		_crop_area.monitoring = true
	
	if _is_local_player():
		if cooldown_ui:
			cooldown_ui.visible = true
	if health_bar:
		health_bar.visible = true
	
	is_invulnerable = true
	_update_health_bar()

func _check_farm_invulnerability() -> void:
	if farm == null:
		is_invulnerable = false
		return
	if global_position.distance_to(farm.global_position) > FARM_RADIUS:
		is_invulnerable = false

# ---------- Spectate Mode ----------

const SPECTATE_SPEED := 500.0
var _elim_ui: CanvasLayer = null

func _handle_spectate_movement(delta: float) -> void:
	var move = input.move_input
	if move.length() > 0.1:
		velocity = move * SPECTATE_SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func enter_spectate_mode() -> void:
	if in_spectate_mode:
		return
	in_spectate_mode = true
	
	if cooldown_ui:
		cooldown_ui.visible = false
	if health_bar:
		health_bar.visible = false
	if tooltip_layer:
		tooltip_layer.visible = false
	
	# Drop any held crop back into the world
	if held_crop:
		drop_held_crop()
	
	# Disable crop pickup area
	if _crop_area:
		_crop_area.monitoring = false
	
	_disable_collision()
	
	if hero:
		hero.enter_spectate_mode()
	
	if _is_local_player():
		_show_elimination_ui()

func _disable_collision() -> void:
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

func _is_local_player() -> bool:
	if input is LocalInput:
		return player_id == 0
	elif input is NetworkInput:
		return input.is_local
	return false

# --- Elimination UI ---

func _show_elimination_ui() -> void:
	_elim_ui = CanvasLayer.new()
	_elim_ui.layer = 90
	add_child(_elim_ui)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_elim_ui.add_child(bg)
	
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(360, 0)
	center.add_theme_constant_override("separation", 16)
	bg.add_child(center)
	
	# Title
	var title = Label.new()
	title.text = "ELIMINATED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	center.add_child(title)
	
	# Leaderboard
	var lb_panel = PanelContainer.new()
	center.add_child(lb_panel)
	var lb_box = VBoxContainer.new()
	lb_box.add_theme_constant_override("separation", 6)
	lb_panel.add_child(lb_box)
	
	var lb_title = Label.new()
	lb_title.text = "Leaderboard"
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_title.add_theme_font_size_override("font_size", 22)
	lb_box.add_child(lb_title)
	
	var standings = _get_standings()
	for i in standings.size():
		var entry = Label.new()
		entry.text = "%d. %s  -  %d crops" % [i + 1, standings[i]["name"], standings[i]["crops"]]
		entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb_box.add_child(entry)
	
	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	center.add_child(btn_row)
	
	var spectate_btn = Button.new()
	spectate_btn.text = "Spectate"
	spectate_btn.custom_minimum_size = Vector2(140, 44)
	spectate_btn.pressed.connect(_on_spectate_pressed)
	btn_row.add_child(spectate_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(140, 44)
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_row.add_child(quit_btn)

func _get_standings() -> Array:
	var gm = GameManager.instance
	if gm == null:
		return []
	var list: Array = []
	for p in gm.players:
		if not is_instance_valid(p):
			continue
		var pname = "Player %d" % p.player_id
		if gm.player_data.has(p.player_id):
			pname = gm.player_data[p.player_id].get("username", pname)
		list.append({"name": pname, "crops": p.crop_count, "alive": not p.in_spectate_mode})
	list.sort_custom(func(a, b):
		if a["alive"] != b["alive"]:
			return a["alive"]
		return a["crops"] > b["crops"]
	)
	return list

func _on_spectate_pressed() -> void:
	if _elim_ui:
		_elim_ui.queue_free()
		_elim_ui = null

func _on_quit_pressed() -> void:
	GameData.change_scene("res://scenes/ui/main_menu.tscn")
