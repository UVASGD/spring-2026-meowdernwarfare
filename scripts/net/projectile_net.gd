class_name ProjectileNet
extends RefCounted

## Shared bookkeeping + spawn/despawn helpers for one-shot networked objects
## (Burple grenade, Burple missile strike, Muskrat ult, Dingus orbital).
##
## GameManager owns one ProjectileNet per kind. Each instance tracks live
## objects by string id, reuses them if a duplicate spawn message arrives,
## and auto-prunes on tree_exited. Spawning is synchronous on host; clients
## send a request (req_type) to the host and wait for the authoritative
## broadcast (spawn_type).

signal spawned(id: String, obj: Node)

var scene: PackedScene
var id_field: String
var req_type: String
var spawn_type: String
var _objects: Dictionary = {}

func _init(scene_: PackedScene, id_field_: String, req_type_: String, spawn_type_: String) -> void:
	scene = scene_
	id_field = id_field_
	req_type = req_type_
	spawn_type = spawn_type_

func get_obj(id: String) -> Node:
	var obj = _objects.get(id)
	if obj != null and is_instance_valid(obj):
		return obj
	if _objects.has(id):
		_objects.erase(id)
	return null

func size() -> int:
	return _objects.size()

func values() -> Array:
	return _objects.values()

func clear() -> void:
	for obj in _objects.values():
		if is_instance_valid(obj):
			obj.queue_free()
	_objects.clear()

## Client path: forward a request to the host.
func request(extra: Dictionary) -> void:
	var msg := extra.duplicate()
	msg["type"] = req_type
	Network.send_to_host(msg)

## Host path: spawn locally and broadcast the authoritative message.
## `data` must include id_field.
func host_spawn(data: Dictionary, parent: Node, configure: Callable) -> Node:
	var obj := _spawn(data, parent, true, configure)
	if obj != null and Network.is_online():
		var out := data.duplicate(true)
		out["type"] = spawn_type
		Network.broadcast(out)
	return obj

## Client path: spawn from an authoritative broadcast.
func client_spawn(data: Dictionary, parent: Node, configure: Callable) -> Node:
	return _spawn(data, parent, false, configure)

func _spawn(data: Dictionary, parent: Node, authoritative: bool, configure: Callable) -> Node:
	var id := str(data.get(id_field, ""))
	if id.is_empty():
		return null
	var prev := get_obj(id)
	if prev != null:
		return null
	var obj := scene.instantiate()
	if obj.has_method("_set_authoritative"):
		obj.call("_set_authoritative", authoritative)
	else:
		if "authoritative" in obj:
			obj.set("authoritative", authoritative)
	if configure.is_valid():
		configure.call(obj, data)
	parent.add_child(obj)
	_objects[id] = obj
	obj.tree_exited.connect(func():
		if _objects.get(id) == obj:
			_objects.erase(id)
	)
	spawned.emit(id, obj)
	return obj
