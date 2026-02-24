extends Sprite2D

var planted_crop: Crop = null

func plant(crop: Crop) -> void:
	planted_crop = crop
	add_child(crop)
	crop.position = Vector2.ZERO

func uproot() -> Crop:
	var crop = planted_crop
	if crop and crop.get_parent() == self:
		remove_child(crop)
	planted_crop = null
	return crop
