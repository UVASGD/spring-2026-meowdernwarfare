extends Crop

const VALUES := { 1: 40.0, 2: 60.0, 3: 80.0 }

func _setup() -> void:
	crop_name = "Speed Sprout"
	desc = "Increases movement speed."
	buff_type = "stat"
	buff_stat = "max_speed"
	buff_value = VALUES.get(stage, 40.0)
