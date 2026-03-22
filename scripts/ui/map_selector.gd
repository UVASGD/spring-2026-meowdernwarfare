extends Node2D

const MAPS := ["Moon", "TestMap", "City"]
const OPTION_W := 400.0
const SLIDE_DURATION := 0.2

@onready var option_sprites: Array = $options.get_children()
@onready var next_btn = $nextButton
@onready var back_btn = $backButton

var idx := 0
var selected_map: String = ""
var _tween: Tween = null

signal map_selected(map_name: String)

func _ready() -> void:
	selected_map = MAPS[idx]
	_layout()
	map_selected.emit(selected_map)

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
	idx = wrapi(idx + dir, 0, MAPS.size())
	selected_map = MAPS[idx]

	var outgoing = option_sprites[old_idx]
	var incoming = option_sprites[idx]

	for i in option_sprites.size():
		if i != old_idx and i != idx:
			option_sprites[i].position.x = OPTION_W * 2

	incoming.position.x = dir * OPTION_W

	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(outgoing, "position:x", -dir * OPTION_W, SLIDE_DURATION)
	_tween.tween_property(incoming, "position:x", 0.0, SLIDE_DURATION)

	map_selected.emit(selected_map)

func set_interactive(enabled: bool) -> void:
	if enabled:
		next_btn.enable()
		back_btn.enable()
	else:
		next_btn.disable()
		back_btn.disable()

func set_map(map_name: String) -> void:
	var new_idx = MAPS.find(map_name)
	if new_idx < 0:
		return
	idx = new_idx
	selected_map = map_name
	_layout()
