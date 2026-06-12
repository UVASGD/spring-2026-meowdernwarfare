class_name SfxSlot
extends Resource

@export var id: StringName
@export var stream: AudioStream
@export var bus: StringName = &"Master"
@export_range(-40.0, 12.0, 0.1) var volume_db: float = 0.0
@export_range(0.5, 2.0, 0.01) var pitch: float = 1.0
@export_range(0.0, 1.0, 0.01) var pitch_rand: float = 0.0
@export var world: bool = true
