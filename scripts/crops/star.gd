extends Crop

const SLOW := {1: 0.10, 2: 0.20, 3: 0.30}
const RADIUS := {1: 160.0, 2: 160.0, 3: 160.0}

func get_type_id() -> String: return "Star"

func _setup() -> void:
	crop_name = "SleepyStar"
	desc = "Slow nearby enemies by %d%% in %dpx." % [int(round(SLOW.get(stage, 0.10) * 100.0)), int(RADIUS.get(stage, 160.0))]

func add_buff(player) -> void:
	player.mod_crop_stat("star_slow_pct", SLOW.get(stage, 0.10))
	player.mod_crop_stat("star_radius", RADIUS.get(stage, 160.0))

func remove_buff(player) -> void:
	player.mod_crop_stat("star_slow_pct", -SLOW.get(stage, 0.10))
	player.mod_crop_stat("star_radius", -RADIUS.get(stage, 160.0))
