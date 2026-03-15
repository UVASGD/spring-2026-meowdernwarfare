extends Node2D

@onready var _owner: Player
@onready var id: int
@export var max_crops: int = 9
var crops: Array[Crop] = []

func _ready() -> void:
	add_to_group("farms")

func assign_owner(player: Player) -> void:
	_owner = player
	player.farm = self

func has_space() -> bool:
	return crops.size() < max_crops

func plant_crop(crop: Crop, tile) -> void:
	if not has_space():
		return
	crops.append(crop)
	crop.is_planted = true
	crop.set_planted_visual(true)
	crop.owner_farm = self
	tile.plant(crop)
	crop.add_buff(_owner)

func remove_crop(crop: Crop) -> Crop:
	if crop not in crops:
		return null
	crops.erase(crop)
	crop.remove_buff(_owner)
	crop.is_planted = false
	crop.set_planted_visual(false)
	crop.owner_farm = null
	if crop.get_parent() and crop.get_parent().has_method("uproot"):
		crop.get_parent().uproot()
	elif crop.get_parent():
		crop.get_parent().remove_child(crop)
	return crop
