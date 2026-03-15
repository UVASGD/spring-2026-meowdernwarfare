extends Crop

const DMG := { 1: 15.0, 2: 25.0, 3: 40.0 }
const RADIUS := { 1: 80.0, 2: 110.0, 3: 140.0 }
const EXPLOSION_VISUAL_SCENE := preload("res://scenes/explosion_visual.tscn")

func get_type_id() -> String: return "BlastBerry"

func _setup() -> void:
	crop_name = "Blast Berry"
	desc = "Explodes on dash for %d damage in a %d radius." % [DMG.get(stage, 15.0), RADIUS.get(stage, 80.0)]
	buff_type = "signal"
	buff_signal = "dashed"

func _make_buff_callable(player) -> Callable:
	return func():
		_explode(player)

func _explode(player) -> void:
	var dmg = DMG.get(stage, 15.0)
	var rad = RADIUS.get(stage, 80.0)
	var pos = player.global_position

	for p in player.get_tree().get_nodes_in_group("players"):
		if p == player or not is_instance_valid(p) or p.is_dead():
			continue
		if p.global_position.distance_to(pos) <= rad:
			p.take_damage(dmg, player)

	var fx = EXPLOSION_VISUAL_SCENE.instantiate()
	player.get_parent().add_child(fx)
	fx.global_position = pos
	fx.scale = Vector2.ONE * (rad / 250.0)
