extends CanvasLayer

const CROP_SCENES := {
	"SpeedSprout": preload("res://scenes/crops/speed_sprout.tscn"),
	"IronRoot": preload("res://scenes/crops/iron_root.tscn"),
	"BlastBerry": preload("res://scenes/crops/blast_berry.tscn"),
}

var panel: PanelContainer
var vbox: VBoxContainer
var crop_stage_spin: SpinBox
var crop_picker: OptionButton
var visible_flag := false

func _ready() -> void:
	layer = 90
	_build_ui()
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		visible_flag = !visible_flag
		panel.visible = visible_flag
		get_viewport().set_input_as_handled()

func _get_local_player() -> Player:
	var gm = GameManager.instance
	if gm:
		return gm.get_local_player()
	for p in get_tree().get_nodes_in_group("players"):
		if p is Player and p.input is LocalInput:
			return p
	return null

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(10, 200)
	panel.custom_minimum_size = Vector2(240, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Debug (TAB)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	vbox.add_child(title)

	_add_separator()
	_add_button("Kill Player", _on_kill)
	_add_button("Clear Farm", _on_clear_farm)
	_add_button("Charge Ult", _on_charge_ult)
	_add_button("Reset Cooldowns", _on_reset_cooldowns)
	_add_button("clear All Farms", _on_clear_all_farms)
	_add_button("Trigger Sudden Death", _on_sudden_death)

	_add_separator()
	var crop_label = Label.new()
	crop_label.text = "Add Crop to World"
	crop_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	vbox.add_child(crop_label)

	crop_picker = OptionButton.new()
	for crop_name in CROP_SCENES.keys():
		crop_picker.add_item(crop_name)
	vbox.add_child(crop_picker)

	var stage_row = HBoxContainer.new()
	var stage_label = Label.new()
	stage_label.text = "Stage:"
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_row.add_child(stage_label)
	crop_stage_spin = SpinBox.new()
	crop_stage_spin.min_value = 1
	crop_stage_spin.max_value = 3
	crop_stage_spin.value = 1
	crop_stage_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_row.add_child(crop_stage_spin)
	vbox.add_child(stage_row)

	_add_button("Spawn Crop", _on_spawn_crop)

	add_child(panel)

func _add_button(text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	vbox.add_child(btn)

func _add_separator() -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

func _on_kill() -> void:
	var p = _get_local_player()
	if p and p.hero:
		p.hero.take_damage(p.hero.health + 1)

func _on_clear_farm() -> void:
	var p = _get_local_player()
	if p == null or p.farm == null:
		return
	var farm = p.farm
	for crop in farm.crops.duplicate():
		farm.remove_crop(crop)
		crop.queue_free()
	p.crop_count = 0

func _on_clear_all_farms() -> void:
	for p in GameManager.instance.players:
		
		if p == null or p.farm == null:
			continue
		var farm = p.farm
		for crop in farm.crops.duplicate():
			farm.remove_crop(crop)
			crop.queue_free()
		p.crop_count = 0


func _on_charge_ult() -> void:
	var p = _get_local_player()
	if p and p.hero:
		p.hero.ult_points = p.hero.max_ult_points

func _on_reset_cooldowns() -> void:
	var p = _get_local_player()
	if p and p.hero:
		p.hero.shoot_cd = 0.0
		p.hero.ability1_cd = 0.0
		p.hero.reload_cd = 0.0
	if p:
		p.dash_cd_timer = 0.0

func _on_sudden_death() -> void:
	var gm = GameManager.instance
	if gm == null or gm.sudden_death:
		return
	gm.broadcast_sudden_death()
	var game = get_tree().current_scene
	if game and game.has_method("_activate_sudden_death"):
		game._activate_sudden_death()

func _on_spawn_crop() -> void:
	var p = _get_local_player()
	if p == null:
		return
	var crop_name = crop_picker.get_item_text(crop_picker.selected)
	var scene = CROP_SCENES.get(crop_name)
	if scene == null:
		return
	var crop = scene.instantiate() as Crop
	crop.stage = int(crop_stage_spin.value)
	crop._setup()
	var spawn_pos = p.global_position + p.aim_dir * 80.0
	crop.global_position = spawn_pos
	p.get_parent().add_child(crop)
