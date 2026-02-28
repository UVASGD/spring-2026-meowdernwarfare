class_name Crop
extends Area2D

const STAGE_COLORS := {
	1: Color(0.6, 0.9, 0.6),
	2: Color(0.3, 0.7, 1.0),
	3: Color(1.0, 0.55, 0.1),
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

signal picked_up

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	_setup()

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
		"dash_speed":
			player.dash_speed += value
		"shoot_cooldown":
			if player.hero:
				player.hero.shoot_cooldown += value

# Subclasses override for signal-based buffs
func _make_buff_callable(_player) -> Callable:
	return Callable()

func get_type_id() -> String:
	return "Crop"

func get_stage_color() -> Color:
	return STAGE_COLORS.get(stage, Color.WHITE)

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
