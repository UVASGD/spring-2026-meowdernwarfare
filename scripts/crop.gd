class_name Crop
extends Area2D

const STAGE_COLORS := {
	1: Color(0.0, 1, 0.0),
	2: Color(0.0, 0.0, 1.0),
	3: Color(1.0, 0.5, 0),
}

@export var crop_name: String = "Crop"
@export var desc: String = ""
@export var stage: int = 1
@export var icon: Texture2D

# Buff config -- subclasses override in _ready or via exports
var buff_type: String = "stat"  # "stat" or "signal"
var buff_stat: String = ""
var buff_value: float = 0.0
var buff_signal: String = ""
var _buff_callable: Callable

# State
var is_planted: bool = false
var owner_farm = null  # Farm ref when planted

# Stable ID used by host arbitration for pickup/drop. Empty for planted/starter crops that
# never need cross-peer identity (they're keyed by farm + tile_idx instead).
var crop_id: String = ""

@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 3.0
var _bob_time: float = 0.0
var _base_y_sprite: float = 0.0

@onready var light:Light2D = $light
@onready var sprite:Sprite2D = $Sprite
@onready var plantedSprite:Sprite2D = $plantedSprite
signal picked_up

func _ready() -> void:
	if sprite:
		_base_y_sprite = sprite.position.y
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	_make_unique_mats()
	set_planted_visual(is_planted)
	_apply_stage_visuals()
	_setup()

func _process(delta: float) -> void:
	_bob_time += delta
	var off = sin(_bob_time * bob_speed) * bob_amplitude
	if sprite:
		sprite.position.y = _base_y_sprite + off

# Subclasses override to configure buff values per stage
func _setup() -> void:
	pass

func add_buff(player) -> void:
	if buff_type == "stat":
		_apply_stat(player, buff_value)
	elif buff_type == "signal" and buff_signal != "":
		_buff_callable = _make_buff_callable(player)
		if player.has_signal(buff_signal) and not player.is_connected(buff_signal, _buff_callable):
			player.connect(buff_signal, _buff_callable)

func remove_buff(player) -> void:
	if buff_type == "stat":
		_apply_stat(player, -buff_value)
	elif buff_type == "signal" and _buff_callable.is_valid():
		if player.has_signal(buff_signal) and player.is_connected(buff_signal, _buff_callable):
			player.disconnect(buff_signal, _buff_callable)

func _apply_stat(player, value: float) -> void:
	match buff_stat:
		"max_speed":
			player.max_speed += value
		"max_health":
			if player.hero:
				player.hero.max_health += value
				if value > 0:
					player.hero.heal(value)
				else:
					player.hero.health = min(player.hero.health, player.hero.max_health)
					player.hero.health_changed.emit(player.hero.health, player.hero.max_health)
		"dash_speed":
			player.dash_speed += value
		"shoot_cooldown":
			if player.hero:
				player.hero.shoot_cooldown += value
		"shoot_cd_pct", "ability1_cd_pct", "ult_req_pct", "mag_pct", "heal_on_hit", "rush_pts_per_300", "rush_px_per_point", "hypno_dps", "hypno_radius", "acid_resist", "star_slow_pct", "star_radius":
			if player.has_method("mod_crop_stat"):
				player.mod_crop_stat(buff_stat, value)

# Subclasses override for signal-based buffs
func _make_buff_callable(_player) -> Callable:
	return Callable()

func get_type_id() -> String:
	return "Crop"

func get_stage_color() -> Color:
	return STAGE_COLORS.get(stage, Color.WHITE)

func set_planted_visual(planted: bool) -> void:
	if sprite:
		sprite.visible = not planted
	if plantedSprite:
		plantedSprite.visible = planted

func _make_unique_mats() -> void:
	if sprite and sprite.material and sprite.material is ShaderMaterial:
		var base = sprite.material
		var sm: ShaderMaterial = base.duplicate()
		sprite.material = sm
		if plantedSprite and plantedSprite.material == base:
			plantedSprite.material = sm
	if plantedSprite and plantedSprite.material and plantedSprite.material is ShaderMaterial:
		if not sprite or plantedSprite.material != sprite.material:
			plantedSprite.material = plantedSprite.material.duplicate()

func _set_stage_on_sprite(s: Sprite2D, c: Color) -> void:
	if not s:
		return
	var mat := s.material
	if mat == null or not (mat is ShaderMaterial):
		return
	var sm: ShaderMaterial = mat
	sm.set_shader_parameter("edge_color_a", c)
	sm.set_shader_parameter("edge_color_b", c)
	sm.set_shader_parameter("inner_color_a", c)
	sm.set_shader_parameter("inner_color_b", c)

func _apply_stage_visuals() -> void:
	var c := get_stage_color()
	if light:
		light.color = c
	_set_stage_on_sprite(sprite, c)
	_set_stage_on_sprite(plantedSprite, c)

func get_tooltip_bbcode() -> String:
	var c = get_stage_color()
	var hex = c.to_html(false)
	var text = "[b]%s[/b] [color=#%s](Stage %d)[/color]\n" % [crop_name, hex, stage]
	text += _color_numbers(desc, hex)
	return text

func _color_numbers(s: String, hex: String) -> String:
	var re = RegEx.new()
	re.compile("\\d+\\.?\\d*")
	var result = ""
	var last = 0
	for m in re.search_all(s):
		result += s.substr(last, m.get_start() - last)
		result += "[color=#%s]%s[/color]" % [hex, m.get_string()]
		last = m.get_end()
	result += s.substr(last)
	return result
