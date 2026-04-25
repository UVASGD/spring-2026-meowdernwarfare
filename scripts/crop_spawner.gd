extends Node2D

@export var crop_scenes: Array[PackedScene] = []
@export var max_stage: int = 3

@onready var stage: int = 1
@onready var spawn_timer: Timer = $spawnTimer
@onready var start_timer: Timer = $startTimer
@onready var stage_timer: Timer = $stageTimer
@onready var spawn_point: Marker2D = $cropSpawnPoint
@onready var anim: AnimationPlayer = $AnimationPlayer

var current_crop: Node = null
var spawner_id: int = -1
var is_bringing: bool = false
var remote_bring_visual_only: bool = false
var _spawn_seq: int = 0

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
	if is_bringing:
		return
	is_bringing = true
	if anim:
		anim.play("bring") # bring animation has a method track calling bring()
	var gm = GameManager.instance
	if gm and not gm.is_local() and gm.is_host():
		gm.send_crop_bring(spawner_id)

func bring() -> void:
	is_bringing = false
	if remote_bring_visual_only:
		remote_bring_visual_only = false
		return
	_spawn_seq += 1
	var idx = randi() % crop_scenes.size()
	var cid := "sp:%d:%d" % [spawner_id, _spawn_seq]
	var crop := _build_crop(idx, stage, cid)
	if crop == null:
		return
	current_crop = crop
	
	var gm = GameManager.instance
	if gm:
		gm.register_world_crop(crop)
		if not gm.is_local() and gm.is_host():
			gm.send_crop_spawned(spawner_id, idx, stage, cid)
	return

func play_bring_remote() -> void:
	if crop_scenes.is_empty():
		return
	if current_crop != null and is_instance_valid(current_crop):
		return
	if is_bringing:
		return
	remote_bring_visual_only = true
	is_bringing = true
	if anim:
		anim.play("bring")

func spawn_crop_remote(crop_idx: int, stg: int, cid: String = "") -> void:
	is_bringing = false
	if crop_scenes.is_empty() or crop_idx < 0 or crop_idx >= crop_scenes.size():
		return
	if current_crop != null and is_instance_valid(current_crop):
		return
	
	var crop := _build_crop(crop_idx, stg, cid)
	if crop == null:
		return
	current_crop = crop
	
	var gm = GameManager.instance
	if gm:
		gm.register_world_crop(crop)

func _build_crop(crop_idx: int, stg: int, cid: String) -> Crop:
	if crop_scenes.is_empty() or crop_idx < 0 or crop_idx >= crop_scenes.size():
		return null
	var scene = crop_scenes[crop_idx]
	var crop := scene.instantiate() as Crop
	if crop == null:
		return null
	crop.stage = stg
	crop.crop_id = cid
	crop._setup()
	spawn_point.add_child(crop)
	crop.position = Vector2.ZERO
	crop.z_index = 1
	crop.picked_up.connect(func(): current_crop = null)
	return crop

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
