extends Crop

const VALUES := {1: 0.1, 2: 0.15, 3: 0.2}

func get_type_id() -> String: return "CoffeeBean"

func _setup() -> void:
	crop_name = "Coffee Bean"
	buff_type = "stat"
	buff_stat = "shoot_cd_pct"
	buff_value = VALUES.get(stage, 0.03)
	desc = "Reduce shoot cooldown by %d%%." % int(round(buff_value * 100.0))
