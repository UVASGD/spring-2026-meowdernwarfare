@tool
class_name TransitionSettings
extends Resource

enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }

@export var direction: Direction = Direction.LEFT_TO_RIGHT
@export_range(0.0, 1) var feather: float = 0.1
@export var duration: float = 0.5
@export var use_texture: bool = false
@export var sheet_texture: Texture2D
@export var frame_size: Vector2i = Vector2i(1920, 1080)
@export_range(1, 512, 1) var frame_count: int = 1
@export_range(1.0, 120.0, 1.0) var fps: float = 30.0
