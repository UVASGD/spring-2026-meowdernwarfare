class_name HeroDealer
extends Hero

const BulletScene = preload("res://scenes/heroes/dealer/bullet.tscn")
const InvisShader = preload("res://assets/shaders/new_shader.gdshader")

@export var invis_duration: float = 3.0
@export var drug_duration: float = 10.0

var invis_timer: float = 0.0
var invis_material: ShaderMaterial = null
var normal_material: Material = null

func _ready() -> void:
	super._ready()
	# Create invisibility shader material
	invis_material = ShaderMaterial.new()
	invis_material.shader = InvisShader
	invis_material.set_shader_parameter("u_roundness", 0.0)
	invis_material.set_shader_parameter("u_distortion_intensity", 2)
	invis_material.set_shader_parameter("u_blur_intensity", 2.0)
	
	if sprite:
		normal_material = sprite.material

func _process(delta: float) -> void:
	super._process(delta)
	
	if invis_timer > 0:
		invis_timer -= delta
		if invis_timer <= 0:
			_end_invis()

func get_hero_name() -> String:
	return "Dealer"

func is_invisible() -> bool:
	return invis_timer > 0

@warning_ignore("unused_parameter")
func _do_shoot(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.direction = aim_dir
	bullet.owner_player = player
	bullet.global_position = player.global_position + aim_dir * 30
	bullet.rotation = aim_dir.angle()
	
	get_tree().current_scene.add_child(bullet)

@warning_ignore("unused_parameter")
func _do_ability1(aim_dir: Vector2, aim_pos: Vector2) -> void:
	_start_invis()

func _start_invis() -> void:
	invis_timer = invis_duration
	if sprite and invis_material:
		sprite.material = invis_material
	player.health_bar.visible = false

func _end_invis() -> void:
	invis_timer = 0.0
	if sprite:
		sprite.material = normal_material
	player.health_bar.visible = true

@warning_ignore("unused_parameter")
func _do_ability2(aim_dir: Vector2, aim_pos: Vector2) -> void:
	var all_players = get_tree().get_nodes_in_group("players")
	
	# If no group set up, try to find players via GameManager
	if all_players.is_empty() and GameManager.instance:
		all_players = GameManager.instance.players
	
	for p in all_players:
		if p is Player and p != player:
			p.apply_drug_effect(drug_duration)
