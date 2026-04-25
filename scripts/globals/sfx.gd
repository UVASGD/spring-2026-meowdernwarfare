extends Node

@export var bank: Resource
@export_range(1, 24, 1) var ui_players: int = 6
@export_range(1, 48, 1) var world_players: int = 16

var _slots: Dictionary = {}
var _ui_pool: Array[AudioStreamPlayer] = []
var _world_pool: Array[AudioStreamPlayer2D] = []
var _ui_idx := 0
var _world_idx := 0

func _ready() -> void:
	_rebuild()
	_build_pools()

func _build_pools() -> void:
	for i in range(ui_players):
		var p := AudioStreamPlayer.new()
		p.name = "Ui%d" % i
		add_child(p)
		_ui_pool.append(p)
	for i in range(world_players):
		var p := AudioStreamPlayer2D.new()
		p.name = "World%d" % i
		add_child(p)
		_world_pool.append(p)

func _rebuild() -> void:
	_slots.clear()
	if bank == null:
		return
	if not ("slots" in bank):
		return
	for slot in bank.slots:
		if slot == null or slot.id == &"":
			continue
		_slots[slot.id] = slot

func refresh() -> void:
	_rebuild()

func has(id: StringName) -> bool:
	return _slots.has(id)

func play(id: StringName, pos := Vector2.INF, db_offset := 0.0) -> void:
	if not _slots.has(id):
		return
	var slot: Resource = _slots[id]
	if slot == null or slot.stream == null:
		return
	var is_world: bool = bool(slot.world) and pos != Vector2.INF
	if is_world:
		_play_world(slot, pos, db_offset)
	else:
		_play_ui(slot, db_offset)

func play_ui(id: StringName) -> void:
	play(id, Vector2.INF)

func play_world(id: StringName, pos: Vector2) -> void:
	play(id, pos)

func play_world_db(id: StringName, pos: Vector2, db_offset: float) -> void:
	play(id, pos, db_offset)

func _play_ui(slot: Resource, db_offset := 0.0) -> void:
	if _ui_pool.is_empty():
		return
	var p := _ui_pool[_ui_idx]
	_ui_idx = (_ui_idx + 1) % _ui_pool.size()
	p.stop()
	p.stream = slot.stream
	p.bus = String(slot.bus)
	p.volume_db = slot.volume_db + db_offset
	p.pitch_scale = _pitch(slot)
	p.play()

func _play_world(slot: Resource, pos: Vector2, db_offset := 0.0) -> void:
	if _world_pool.is_empty():
		return
	var p := _world_pool[_world_idx]
	_world_idx = (_world_idx + 1) % _world_pool.size()
	p.stop()
	p.stream = slot.stream
	p.bus = String(slot.bus)
	p.volume_db = slot.volume_db + db_offset
	p.pitch_scale = _pitch(slot)
	p.global_position = pos
	p.play()

func _pitch(slot: Resource) -> float:
	if slot.pitch_rand <= 0.0:
		return slot.pitch
	return slot.pitch + randf_range(-slot.pitch_rand, slot.pitch_rand)
