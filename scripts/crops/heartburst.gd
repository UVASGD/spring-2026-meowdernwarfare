extends Crop

const VALUES := {1: 1.0, 2: 2.0, 3: 3.0}

func get_type_id() -> String: return "Heartburst"

func _setup() -> void:
	crop_name = "Heartburst"
	buff_type = "stat"
	buff_stat = "heal_on_hit"
	buff_value = VALUES.get(stage, 1.0)
	desc = "Heal %d HP on successful hits." % int(buff_value)
