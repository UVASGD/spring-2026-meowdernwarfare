extends Crop

const DMG := { 1: 15.0, 2: 25.0, 3: 40.0 }
const RADIUS := { 1: 80.0, 2: 110.0, 3: 140.0 }

func _setup() -> void:
	crop_name = "Blast Berry"
	desc = "Causes an explosion when you dash."
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

	# Visual feedback
	var fx = _make_explosion_fx(rad)
	player.get_parent().add_child(fx)
	fx.global_position = pos

func _make_explosion_fx(rad: float) -> Node2D:
	var sprite = Sprite2D.new()
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.4, 0.1, 0.5))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2.ONE * (rad / 32.0)

	var tw = sprite.create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tw.tween_callback(sprite.queue_free)
	return sprite
