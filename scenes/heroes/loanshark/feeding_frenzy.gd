extends Node2D

## Pulses marks in a radius around [member owner_player]. Parent should be the caster's [Player].

const RippleFxScene = preload("res://scenes/heroes/loanshark/feeding_frenzy_ripple.tscn")

var owner_player: Player
var effect_radius: float = 600.0
var mark_duration: float = 10.0
var pulse_count: int = 3
var pulse_interval: float = 3.0

func _ready() -> void:
	z_index = 4
	_run_pulses()

func _run_pulses() -> void:
	for i in pulse_count:
		if owner_player == null or not is_instance_valid(owner_player) or owner_player.is_dead():
			break
		_pulse()
		if i < pulse_count - 1:
			await get_tree().create_timer(pulse_interval).timeout
	queue_free()

func _pulse() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	if owner_player.is_dead():
		return
	var center := owner_player.global_position
	_spawn_pulse_visual(center)
	_apply_marks(center)

func _apply_marks(center: Vector2) -> void:
	var r2 := effect_radius * effect_radius
	for node in get_tree().get_nodes_in_group("players"):
		if not node is Player:
			continue
		var pl := node as Player
		if pl == owner_player:
			continue
		if pl.global_position.distance_squared_to(center) > r2:
			continue
		pl.apply_mark_effect(mark_duration)

func _spawn_pulse_visual(center: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fx: Node2D = RippleFxScene.instantiate()
	fx.max_radius = effect_radius
	fx.global_position = center
	get_tree().current_scene.add_child(fx)
