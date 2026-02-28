extends Node2D

@export var crop_scenes: Array[PackedScene] = []
@export var max_stage: int = 3

@onready var stage: int = 1
@onready var spawn_timer: Timer = $spawnTimer
@onready var start_timer: Timer = $startTimer
@onready var stage_timer: Timer = $stageTimer
@onready var spawn_point: Marker2D = $cropSpawnPoint

var current_crop: Node = null
var spawner_id: int = -1

func _ready() -> void:
	# Defer so game mode is set before we check host/client
	call_deferred("_setup_network")

func _setup_network() -> void:
	var gm = GameManager.instance
	if gm == null or gm.is_local():
		return
	gm.register_spawner(self)
	if not gm.is_host():
		start_timer.stop()
		spawn_timer.stop()
		stage_timer.stop()

func spawn_crop() -> void:
	if crop_scenes.is_empty():
		return
	if current_crop != null and is_instance_valid(current_crop):
		return
	
	var idx = randi() % crop_scenes.size()
	var scene = crop_scenes[idx]
	var crop = scene.instantiate() as Crop
	crop.stage = stage
	crop._setup()
	spawn_point.add_child(crop)
	crop.position = Vector2.ZERO
	crop.z_index = 1
	current_crop = crop
	crop.picked_up.connect(func(): current_crop = null)
	
	var gm = GameManager.instance
	if gm and not gm.is_local() and gm.is_host():
		gm.send_crop_spawned(spawner_id, idx, stage)

func spawn_crop_remote(crop_idx: int, stg: int) -> void:
	if crop_scenes.is_empty() or crop_idx < 0 or crop_idx >= crop_scenes.size():
		return
	if current_crop != null and is_instance_valid(current_crop):
		current_crop.queue_free()
		current_crop = null
	
	var scene = crop_scenes[crop_idx]
	var crop = scene.instantiate() as Crop
	crop.stage = stg
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
	var gm = GameManager.instance
	if gm and not gm.is_local() and gm.is_host():
		gm.send_spawner_stage(spawner_id, stage)

func _on_start_timer_timeout() -> void:
	spawn_crop()
	spawn_timer.start()
	stage_timer.start()

func _on_end_timer_timeout() -> void:
	pass
