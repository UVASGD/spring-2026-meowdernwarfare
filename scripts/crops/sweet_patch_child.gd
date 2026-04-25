extends Crop

const VALUES := {1: 0.30, 2: 0.60, 3: 0.90}

func get_type_id() -> String: return "SweetPatchChild"

func _setup() -> void:
	crop_name = "Sweet Patch Child"
	buff_type = "stat"
	buff_stat = "acid_resist"
	buff_value = VALUES.get(stage, 0.30)
	desc = "Reduce acid pool damage by %d%%." % int(round(buff_value * 100.0))
