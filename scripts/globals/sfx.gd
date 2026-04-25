extends Node

const SfxEvent = preload("res://scripts/audio/sfx_event.gd")

@export var bank: Resource
@export_range(1, 24, 1) var ui_players: int = 6
@export_range(1, 48, 1) var world_players: int = 16

var _slots: Dictionary = {}
var _ui_pool: Array[AudioStreamPlayer] = []
var _world_pool: Array[AudioStreamPlayer2D] = []
var _ui_idx := 0
var _world_idx := 0
var _hooked_btns: Dictionary = {}

func _ready() -> void:
	_rebuild()
	_build_pools()
	_hook_ui_buttons()

func _hook_ui_buttons() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	_hook_node(tree.root)

func _on_node_added(node: Node) -> void:
	_hook_node(node)

func _hook_node(node: Node) -> void:
	if node == null:
		return
	if node is BaseButton:
		_hook_btn(node as BaseButton)
	for c in node.get_children():
		_hook_node(c)

func _hook_btn(btn: BaseButton) -> void:
	if btn == null:
		return
	var id := btn.get_instance_id()
	if _hooked_btns.has(id):
		return
	var hover_cb := Callable(self, "_on_btn_hover").bind(btn)
	var press_cb := Callable(self, "_on_btn_press").bind(btn)
	if not btn.mouse_entered.is_connected(hover_cb):
		btn.mouse_entered.connect(hover_cb)
	if not btn.pressed.is_connected(press_cb):
		btn.pressed.connect(press_cb)
	_hooked_btns[id] = true
	if not btn.tree_exited.is_connected(_on_btn_tree_exited.bind(id)):
		btn.tree_exited.connect(_on_btn_tree_exited.bind(id))

func _on_btn_tree_exited(id: int) -> void:
	_hooked_btns.erase(id)

func _on_btn_hover(btn: BaseButton) -> void:
	if btn == null or btn.disabled:
		return
	play_ui(SfxEvent.UI_HOVER)

func _on_btn_press(btn: BaseButton) -> void:
	if btn == null or btn.disabled:
		return
	play_ui(SfxEvent.UI_CLICK)

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
