extends Area2D
@export var id: int
@export var target_id: int
@export var color_cycle_speed := 0.3
@export var cooldown := 15.0

@onready var light: PointLight2D = $light

var hue := 0.0
var active := true
var _base_energy: float

func _ready() -> void:
	add_to_group("teleporters")
	body_entered.connect(_on_body_entered)
	if light:
		hue = randf()
		_base_energy = light.energy
	print("id: " + str(id) + "at " + str(self.global_position))

func _process(delta: float) -> void:
	if light:
		hue = fmod(hue + delta * color_cycle_speed, 1.0)
		light.color = Color.from_hsv(hue, 1.0, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if not active or body is not Player:
		return

	var target = _find_target()
	if target == null:
		return
	print("teleporting to:" + str(target_id) + "at " + str(target.global_position))
	body.global_position = target.global_position
	print("final pos: " + str(body.global_position))
	_set_disabled(cooldown)
	target._set_disabled(cooldown)

func _find_target() -> Area2D:
	for tp in get_tree().get_nodes_in_group("teleporters"):
		if tp.id == target_id:
			return tp
	return null

func _set_disabled(duration: float) -> void:
	active = false
	monitoring = false
	if light:
		light.energy = _base_energy * 0.15

	await get_tree().create_timer(duration).timeout

	active = true
	monitoring = true
	if light:
		light.energy = _base_energy
