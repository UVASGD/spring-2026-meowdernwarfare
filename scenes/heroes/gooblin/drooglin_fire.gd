extends Area2D

@export var dps: float = 15.0
@export var duration: float = 30.0

var owner_player: Player = null
var _tick_timer: float = 0.0
const TICK_INTERVAL := 0.5

func _ready() -> void:
	get_tree().create_timer(duration).timeout.connect(queue_free)
	var rect = ColorRect.new()
	rect.color = Color(1.0, 0.3, 0.0, 0.5)
	rect.size = Vector2(327, 117)
	rect.position = -rect.size / 2
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

func _physics_process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0:
		return
	_tick_timer = TICK_INTERVAL

	for body in get_overlapping_bodies():
		if body is Player and body != owner_player:
			body.take_damage(dps * TICK_INTERVAL, owner_player)
