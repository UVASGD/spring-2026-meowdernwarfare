class_name InputProvider
extends RefCounted

# Base class for input

var move_input: Vector2 = Vector2.ZERO # move direction
var aim_input: Vector2 = Vector2.ZERO
var aim_position: Vector2 = Vector2.ZERO  # World position for mouse aim

# Action states (add more as needed for abilities)
var sprint: bool = false
var dash: bool = false
var shoot: bool = false
var reload: bool = false
var ability1: bool = false
var ability2: bool = false
var interact: bool = false
var drop: bool = false

# "Just pressed" states for single-frame actions
var dash_just: bool = false
var shoot_just: bool = false
var reload_just: bool = false
var ability1_just: bool = false
var ability2_just: bool = false
var interact_just: bool = false
var drop_just: bool = false

func update(delta: float) -> void:
	# Override in subclasses
	pass

func clear_just_pressed() -> void:
	dash_just = false
	shoot_just = false
	reload_just = false
	ability1_just = false
	ability2_just = false
	interact_just = false
	drop_just = false
