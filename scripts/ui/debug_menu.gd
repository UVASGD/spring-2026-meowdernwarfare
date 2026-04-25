extends CanvasLayer

const CROP_SCENES := {
	"SpeedCarrot": preload("res://scenes/crops/speed_carrot.tscn"),
	"IronRoot": preload("res://scenes/crops/iron_root.tscn"),
	"BlastBerry": preload("res://scenes/crops/blast_berry.tscn"),
	"Dragonfruit": preload("res://scenes/crops/dragonfruit.tscn"),
	"CoffeeBean": preload("res://scenes/crops/coffee_bean.tscn"),
	"BulletBalloon": preload("res://scenes/crops/bullet_balloon.tscn"),
	"Heartburst": preload("res://scenes/crops/heartburst.tscn"),
	"RushRoom": preload("res://scenes/crops/rush_room.tscn"),
	"Hypnoflower": preload("res://scenes/crops/hypnoflower.tscn"),
	"Cloudberry": preload("res://scenes/crops/cloudberry.tscn"),
	"SweetPatchChild": preload("res://scenes/crops/sweet_patch_child.tscn"),
	"Star": preload("res://scenes/crops/star.tscn"),
}

@onready var panel: PanelContainer = $Panel
@onready var crop_picker: OptionButton = $Panel/VBox/CropPicker
@onready var crop_stage_spin: SpinBox = $Panel/VBox/StageRow/CropStageSpin
var visible_flag := false

func _ready() -> void:
	layer = 90
	$Panel/VBox/KillBtn.pressed.connect(_on_kill)
	$Panel/VBox/ClearFarmBtn.pressed.connect(_on_clear_farm)
	$Panel/VBox/ChargeUltBtn.pressed.connect(_on_charge_ult)
	$Panel/VBox/ResetCdBtn.pressed.connect(_on_reset_cooldowns)
	$Panel/VBox/ClearAllBtn.pressed.connect(_on_clear_all_farms)
	$Panel/VBox/SuddenDeathBtn.pressed.connect(_on_sudden_death)
	$Panel/VBox/SpawnCropBtn.pressed.connect(_on_spawn_crop)
	crop_picker.clear()
	for crop_name in CROP_SCENES.keys():
		crop_picker.add_item(crop_name)
	panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		visible_flag = !visible_flag
		panel.visible = visible_flag
		if not visible_flag:
			get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()

func _get_local_player() -> Player:
	var gm = GameManager.instance
	if gm:
		return gm.get_local_player()
	for p in get_tree().get_nodes_in_group("players"):
		if p is Player and p.input is LocalInput:
			return p
	return null

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
