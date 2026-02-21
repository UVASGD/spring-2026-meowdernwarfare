extends Node2D

@onready var stage = 1
@export var max_stage = 3
@onready var spawn_timer: Timer = $spawnTimer
@onready var start_timer: Timer = $startTimer
@onready var stage_timer: Timer = $stageTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_crop():
	print("crop spawn")
	pass

func _on_spawn_timer_timeout() -> void:
	spawn_crop()
	pass # Replace with function body.


func _on_stage_timer_timeout() -> void:
	stage = min(stage+1,max_stage)
	print(stage)
	pass # Replace with function body.


func _on_start_timer_timeout() -> void:
	spawn_timer.start()
	stage_timer.start()
	print("crop spawner started")
	pass # Replace with function body.


func _on_end_timer_timeout() -> void:
	#end game
	print("game over")
	pass # Replace with function body.
