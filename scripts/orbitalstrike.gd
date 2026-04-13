extends Node2D

var owner_player: Player = null
var orbital_id := ""
var authoritative := true

@onready var hurtbox: HeroHurtbox = $hurtbox
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	hurtbox.owner_player = owner_player
	hurtbox.visible = false
	await get_tree().create_timer(1).timeout
	if authoritative:
		hurtbox.show()
		hurtbox.start_swing()
	await animated_sprite_2d.animation_finished
	if authoritative:
		hurtbox.end_swing()
	queue_free()
