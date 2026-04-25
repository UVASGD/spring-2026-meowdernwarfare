extends Crop

const VALUES := {1: 0.05, 2: 0.10, 3: 0.15}

func get_type_id() -> String: return "BulletBalloon"

func _setup() -> void:
	crop_name = "Bullet Balloon"
	buff_type = "stat"
	buff_stat = "mag_pct"
	buff_value = VALUES.get(stage, 0.05)
	desc = "Increase magazine size by %d%%." % int(round(buff_value * 100.0))
