extends Control

signal continue_pressed
signal back_to_menu_pressed

@onready var continue_btn: Button = $MainVBox/ContinueBtn
@onready var settings_btn: Button = $MainVBox/SettingsBtn
@onready var back_btn: Button = $MainVBox/BackBtn
@onready var settings_view: Control = $PauseSettings
@onready var settings_back_btn: Button = $PauseSettings/VBox/BackBtn

func _ready() -> void:
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	back_btn.pressed.connect(func(): back_to_menu_pressed.emit())
	settings_btn.pressed.connect(_open_settings)
	settings_back_btn.pressed.connect(_close_settings)
	_close_settings()
	hide()

func open_menu() -> void:
	show()
	_close_settings()
	continue_btn.grab_focus()

func close_menu() -> void:
	hide()

func _open_settings() -> void:
	_set_main(false)
	settings_view.show()
	settings_back_btn.grab_focus()

func _close_settings() -> void:
	_set_main(true)
	settings_view.hide()

func _set_main(v: bool) -> void:
	$MainVBox.visible = v

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if settings_view.visible:
			_close_settings()
		else:
			continue_pressed.emit()
