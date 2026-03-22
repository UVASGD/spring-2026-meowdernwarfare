extends Node2D

const CROPS := ["BlastBerry", "SpeedCarrot", "IronRoot"]
const OPTION_W := 400.0
const SLIDE_DURATION := 0.2

@onready var option_sprites: Array = $options.get_children()

var idx := 0
var selected_crop: String = ""
var _tween: Tween = null

signal crop_selected(crop_name: String)

func _ready() -> void:
	var saved = GameData.get_active_starters()
	if not saved.is_empty() and saved[0] in CROPS:
		idx = CROPS.find(saved[0])
	selected_crop = CROPS[idx]
	print("sponsorSelector ready, selected crop=",selected_crop)
	_layout()
	crop_selected.emit(selected_crop)

func _layout() -> void:
	for i in option_sprites.size():
		option_sprites[i].position.x = (i - idx) * OPTION_W

func _on_next_button_pressed() -> void:
	_move(1)

func _on_back_button_pressed() -> void:
	_move(-1)

func _move(dir: int) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		_layout()

	var old_idx = idx
	idx = wrapi(idx + dir, 0, CROPS.size())
	selected_crop = CROPS[idx]
	print("new selected crop =",selected_crop)
	var outgoing = option_sprites[old_idx]
	var incoming = option_sprites[idx]

	# Park everyone else offscreen
	for i in option_sprites.size():
		if i != old_idx and i != idx:
			option_sprites[i].position.x = OPTION_W * 2

	# Place incoming just off the entering side
	incoming.position.x = dir * OPTION_W

	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(outgoing, "position:x", -dir * OPTION_W, SLIDE_DURATION)
	_tween.tween_property(incoming, "position:x", 0.0, SLIDE_DURATION)

	crop_selected.emit(selected_crop)

func set_interactive(enabled: bool) -> void:
	if enabled:
		$nextButton.enable()
		$backButton.enable()
	else:
		$nextButton.disable()
		$backButton.disable()
