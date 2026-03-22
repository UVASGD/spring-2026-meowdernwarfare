class_name AnimatedSpriteButton extends SpriteButton

@onready var on_anim: AnimatedSprite2D = $on_animation
@onready var off_anim: AnimatedSprite2D = $off_animation

func _ready() -> void:
	super._ready()
	if on_anim and on_anim.sprite_frames:
		if not on_anim.sprite_frames.has_animation("on"):
			printerr("AnimatedSpriteButton: on_animation needs an 'on' animation")
	if off_anim and off_anim.sprite_frames:
		if not off_anim.sprite_frames.has_animation("off"):
			printerr("AnimatedSpriteButton: off_animation needs an 'off' animation")

func _get_visuals() -> Array:
	var arr = super._get_visuals()
	arr.append(on_anim)
	arr.append(off_anim)
	return arr

func _show_on_state() -> void:
	_hide_all()
	if on_anim:
		on_anim.visible = true
		on_anim.play("on")

func _show_off_state() -> void:
	_hide_all()
	if off_anim:
		off_anim.visible = true
		off_anim.play("off")
