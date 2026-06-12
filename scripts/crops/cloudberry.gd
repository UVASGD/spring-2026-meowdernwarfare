extends Crop

const VALUES := {1: 0.05, 2: 0.10, 3: 0.15}

func get_type_id() -> String: return "Cloudberry"

func _setup() -> void:
	crop_name = "Cloudberry"
	buff_type = "stat"
	buff_stat = "ability1_cd_pct"
	buff_value = VALUES.get(stage, 0.05)
	desc = "Reduce ability 1 cooldown by %d%%." % int(round(buff_value * 100.0))
