extends Node2D

@onready var _owner:Player # starts with underscore because owner is a gdscript keyword
@onready var id:int
@onready var maxCrops:int
var crops:Array[Crop] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
