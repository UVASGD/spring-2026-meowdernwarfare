extends TextureRect

@onready var stars: Node2D = $stars

@export var fade_time := 2.0
@export var hold_time := 3.0
@export var min_delay := 0.5
@export var max_delay := 2.0
@export var max_visible := 3

var layers: Array[TextureRect] = []
var active: Array[TextureRect] = []

func _ready() -> void:
	for child in stars.get_children():
		if child is TextureRect:
			child.visible = true
			child.modulate.a = 0.0
			layers.append(child)
	_cycle()

func _process(delta: float) -> void:
	self.rotation_degrees += 1 * delta
func _cycle() -> void:
	while true:
		if active.size() < max_visible and layers.size() > active.size():
			var pool = layers.filter(func(l): return l not in active)
			var layer = pool.pick_random()
			active.append(layer)
			_show_layer(layer)
		await get_tree().create_timer(randf_range(min_delay, max_delay)).timeout

func _show_layer(layer: TextureRect) -> void:
	var tw = create_tween()
	tw.tween_property(layer, "modulate:a", 1.0, fade_time)
	tw.tween_interval(randf_range(hold_time * 0.5, hold_time * 1.5))
	tw.tween_property(layer, "modulate:a", 0.0, fade_time)
	tw.finished.connect(func(): active.erase(layer))
