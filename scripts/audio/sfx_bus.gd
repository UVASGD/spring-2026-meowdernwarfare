class_name SfxBus
extends RefCounted

static func play_ui(id: StringName) -> void:
	var s = _singleton()
	if s and s.has_method("play_ui"):
		s.call("play_ui", id)

static func play_world(id: StringName, pos: Vector2) -> void:
	var s = _singleton()
	if s and s.has_method("play_world"):
		s.call("play_world", id, pos)

static func play_world_db(id: StringName, pos: Vector2, db_offset: float) -> void:
	var s = _singleton()
	if s and s.has_method("play_world_db"):
		s.call("play_world_db", id, pos, db_offset)

static func _singleton() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("Sfx")
