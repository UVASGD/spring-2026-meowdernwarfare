extends Node2D

@export var crop_scenes: Array[PackedScene] = []
@export var max_stage: int = 3

@onready var stage: int = 1
@onready var spawn_timer: Timer = $spawnTimer
@onready var start_timer: Timer = $startTimer
@onready var stage_timer: Timer = $stageTimer
@onready var spawn_point: Marker2D = $cropSpawnPoint

var current_crop: Node = null

func spawn_crop() -> void:
	if crop_scenes.is_empty():
		return
	if current_crop != null and is_instance_valid(current_crop):
		return
	
	var scene = crop_scenes.pick_random()
	var crop = scene.instantiate() as Crop
	crop.stage = stage
	crop._setup()
	spawn_point.add_child(crop)
	crop.position = Vector2.ZERO
	crop.z_index = 1
	current_crop = crop
	
	crop.picked_up.connect(func(): current_crop = null)

func _on_spawn_timer_timeout() -> void:
	spawn_crop()

func _on_stage_timer_timeout() -> void:
	stage = mini(stage + 1, max_stage)

func _on_start_timer_timeout() -> void:
	spawn_timer.start()
	stage_timer.start()

func _on_end_timer_timeout() -> void:
	pass
