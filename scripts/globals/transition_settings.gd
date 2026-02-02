@tool
class_name TransitionSettings
extends Resource

enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }

@export var direction: Direction = Direction.LEFT_TO_RIGHT
@export_range(0.0, 1) var feather: float = 0.1
@export var duration: float = 0.5
@export var custom_texture: Texture2D = null
@export var use_texture: bool = false
