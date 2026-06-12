class_name KillzoneEffect
extends Node2D

var duration: float = 120.0
var start_radius: float = 3000.0
var end_radius: float = 100.0
var dps_base: float = 5.0
var dps_max: float = 30.0

var elapsed: float = 0.0
var current_radius: float = 3000.0
var active: bool = true

func _ready() -> void:
	current_radius = start_radius
	z_index = -1

func _physics_process(delta: float) -> void:
	if not active:
		return
	
	elapsed += delta
	var t = clampf(elapsed / duration, 0.0, 1.0)
	current_radius = lerpf(start_radius, end_radius, t)
	
	var center = global_position
	var gm = GameManager.instance
	if gm and gm.is_host():
		var dps = lerpf(dps_base, dps_max, t)
		for p in gm.players:
			if not is_instance_valid(p) or p.is_dead() or p.in_spectate_mode or p.is_awaiting_respawn:
				continue
			if p.global_position.distance_to(center) > current_radius:
				p.take_damage(dps * delta)
	
	queue_redraw()

func _draw() -> void:
	# Safe zone border ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 128, Color(1, 0.2, 0.2, 0.6), 4.0)
	# Faint fill outside safe zone (draw a large rect with the circle cut feels complex, 
	# so we draw a second larger ring to hint at danger)
	draw_arc(Vector2.ZERO, current_radius + 20, 0, TAU, 128, Color(1, 0.1, 0.1, 0.2), 40.0)
