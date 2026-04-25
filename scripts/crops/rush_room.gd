extends Crop

const VALUES := {1: 500, 2: 400, 3: 300}

func get_type_id() -> String: return "RushRoom"

func _setup() -> void:
	crop_name = "RushRoom"
	buff_type = "stat"
	buff_stat = "rush_px_per_point"
	buff_value = VALUES.get(stage, 500)
	desc = "Gain 1 ult point every %dpx moved." % int(buff_value)
