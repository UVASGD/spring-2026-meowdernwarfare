class_name LocalInput
extends InputProvider

# P0=WASD, P1=IJKL, P2=Arrows, P3=Numpad

var player_id: int = 0
var use_mouse: bool = false
var player_node: Node2D = null  # ref for mouse aim calc

const KB_MAPS = {
	0: { # WASD + QE + Space/Shift
		"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		"sprint": KEY_SHIFT, "dash": KEY_SPACE,
		"shoot": KEY_Q, "reload": KEY_R, "ability1": KEY_E, "ability2": KEY_F, "ult": KEY_C,
		"drop": KEY_X
	},
	1: { # IJKL + UO + H/Y
		"up": KEY_I, "down": KEY_K, "left": KEY_J, "right": KEY_L,
		"sprint": KEY_H, "dash": KEY_Y,
		"shoot": KEY_U, "reload": KEY_P, "ability1": KEY_O, "ability2": KEY_SEMICOLON, "ult": KEY_APOSTROPHE,
		"drop": KEY_N
	},
	2: { # Arrows + ,. + /RShift
		"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"sprint": KEY_CTRL, "dash": KEY_SLASH,
		"shoot": KEY_COMMA, "reload": KEY_BRACKETRIGHT, "ability1": KEY_PERIOD, "ability2": KEY_BACKSLASH, "ult": KEY_BRACKETLEFT,
		"drop": KEY_M
	},
	3: { # Numpad
		"up": KEY_KP_8, "down": KEY_KP_5, "left": KEY_KP_4, "right": KEY_KP_6,
		"sprint": KEY_KP_0, "dash": KEY_KP_ENTER,
		"shoot": KEY_KP_7, "reload": KEY_KP_MULTIPLY, "ability1": KEY_KP_9, "ability2": KEY_KP_ADD, "ult": KEY_KP_PERIOD,
		"drop": KEY_KP_SUBTRACT
	}
}

func _init(id: int = 0, mouse: bool = false) -> void:
	player_id = id
	use_mouse = mouse

func set_player_node(node: Node2D) -> void:
	player_node = node

func update(delta: float) -> void:
	clear_just_pressed()
	_read_keyboard()
	_read_gamepad()
	_read_mouse()

func _read_keyboard() -> void:
	if player_id < 0 or player_id > 3:
		return
	
	var kb = KB_MAPS[player_id]

	var kb_move = Vector2.ZERO
	if Input.is_key_pressed(kb["left"]): kb_move.x -= 1
	if Input.is_key_pressed(kb["right"]): kb_move.x += 1
	if Input.is_key_pressed(kb["up"]): kb_move.y -= 1
	if Input.is_key_pressed(kb["down"]): kb_move.y += 1
	
	if kb_move.length() > 0:
		move_input = kb_move.normalized()
		if not use_mouse:
			aim_input = move_input

	sprint = sprint or Input.is_key_pressed(kb["sprint"])
	dash = dash or Input.is_key_pressed(kb["dash"])
	shoot = shoot or Input.is_key_pressed(kb["shoot"])
	reload = reload or Input.is_key_pressed(kb["reload"])
	ability1 = ability1 or Input.is_key_pressed(kb["ability1"])
	ability2 = ability2 or Input.is_key_pressed(kb["ability2"])
	ult = ult or Input.is_key_pressed(kb["ult"])
	drop = drop or Input.is_key_pressed(kb["drop"])
	
	dash_just = dash_just or Input.is_key_pressed(kb["dash"]) and not _was_pressed("dash")
	shoot_just = shoot_just or Input.is_key_pressed(kb["shoot"]) and not _was_pressed("shoot")
	reload_just = reload_just or Input.is_key_pressed(kb["reload"]) and not _was_pressed("reload")
	ability1_just = ability1_just or Input.is_key_pressed(kb["ability1"]) and not _was_pressed("ability1")
	ability2_just = ability2_just or Input.is_key_pressed(kb["ability2"]) and not _was_pressed("ability2")
	ult_just = ult_just or Input.is_key_pressed(kb["ult"]) and not _was_pressed("ult")
	drop_just = drop_just or Input.is_key_pressed(kb["drop"]) and not _was_pressed("drop")

var _prev_states: Dictionary = {}

func _was_pressed(action: String) -> bool:
	return _prev_states.get(action, false)

func _store_states() -> void:
	if player_id < 0 or player_id > 3:
		return
	var kb = KB_MAPS[player_id]
	_prev_states["dash"] = Input.is_key_pressed(kb["dash"])
	_prev_states["shoot"] = Input.is_key_pressed(kb["shoot"])
	_prev_states["reload"] = Input.is_key_pressed(kb["reload"])
	_prev_states["ability1"] = Input.is_key_pressed(kb["ability1"])
	_prev_states["ability2"] = Input.is_key_pressed(kb["ability2"])
	_prev_states["ult"] = Input.is_key_pressed(kb["ult"])
	_prev_states["drop"] = Input.is_key_pressed(kb["drop"])

func _read_gamepad() -> void:
	var gp = player_id  # Gamepad index matches player ID
	if not Input.get_connected_joypads().has(gp):
		return
	
	# Left stick - movement
	var stick_move = Vector2(
		Input.get_joy_axis(gp, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(gp, JOY_AXIS_LEFT_Y)
	)
	if stick_move.length() > 0.2:
		move_input = stick_move.normalized() * min(stick_move.length(), 1.0)
	
	# Right stick - aim
	var stick_aim = Vector2(
		Input.get_joy_axis(gp, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(gp, JOY_AXIS_RIGHT_Y)
	)
	if stick_aim.length() > 0.3:
		aim_input = stick_aim.normalized()
	elif move_input.length() > 0.1:
		aim_input = move_input.normalized()
	
	# Triggers and buttons
	sprint = sprint or Input.get_joy_axis(gp, JOY_AXIS_TRIGGER_LEFT) > 0.5
	dash = dash or Input.is_joy_button_pressed(gp, JOY_BUTTON_LEFT_SHOULDER)
	shoot = shoot or Input.get_joy_axis(gp, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	reload = reload or Input.is_joy_button_pressed(gp, JOY_BUTTON_X)
	ability1 = ability1 or Input.is_joy_button_pressed(gp, JOY_BUTTON_RIGHT_SHOULDER)
	ability2 = ability2 or Input.is_joy_button_pressed(gp, JOY_BUTTON_Y)
	ult = ult or Input.is_joy_button_pressed(gp, JOY_BUTTON_B)
	interact = interact or Input.is_joy_button_pressed(gp, JOY_BUTTON_A)

func _read_mouse() -> void:
	if not use_mouse or player_id != 0:
		return
	if player_node == null:
		return
	
	aim_position = player_node.get_global_mouse_position()
	var to_mouse = aim_position - player_node.global_position
	if to_mouse.length() > 10:
		aim_input = to_mouse.normalized()
	
	# Mouse buttons
	shoot = shoot or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	ability1 = ability1 or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	shoot_just = shoot_just or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _prev_states.get("mouse_shoot", false)
	_prev_states["mouse_shoot"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func end_frame() -> void:
	_store_states()
	# Reset continuous states for next frame
	move_input = Vector2.ZERO
	sprint = false
	dash = false
	shoot = false
	reload = false
	ability1 = false
	ability2 = false
	ult = false
	interact = false
	drop = false
