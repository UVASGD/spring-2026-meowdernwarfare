extends Crop

const VALUES := { 1: 20.0, 2: 35.0, 3: 50.0 }

func _setup() -> void:
	crop_name = "Iron Root"
	buff_type = "stat"
	buff_stat = "max_health"
	buff_value = VALUES.get(stage, 20.0)
	desc = "Increases max health by %d." % buff_value
