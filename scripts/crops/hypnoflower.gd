extends Crop

const DPS := {1: 3.0, 2: 5.0, 3: 7.0}
const RADIUS := {1: 80.0, 2: 120.0, 3: 160.0}

func get_type_id() -> String: return "Hypnoflower"

func _setup() -> void:
	crop_name = "Hypnoflower"
	desc = "Nearby enemies take %d DPS in %dpx." % [int(DPS.get(stage, 3.0)), int(RADIUS.get(stage, 80.0))]

func add_buff(player) -> void:
	player.mod_crop_stat("hypno_dps", DPS.get(stage, 3.0))
	player.mod_crop_stat("hypno_radius", RADIUS.get(stage, 80.0))

func remove_buff(player) -> void:
	player.mod_crop_stat("hypno_dps", -DPS.get(stage, 3.0))
	player.mod_crop_stat("hypno_radius", -RADIUS.get(stage, 80.0))
