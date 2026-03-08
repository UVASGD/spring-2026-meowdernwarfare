class_name HeroInfo
extends Resource

@export var id: String = ""
@export_multiline var desc: String = ""
@export var portrait: Texture2D = null

@export_group("Shoot")
@export var shoot_name: String = "Shoot"
@export_multiline var shoot_desc: String = ""
@export var shoot_video: VideoStream = null

@export_group("Ability 1")
@export var ability1_name: String = "Ability 1"
@export_multiline var ability1_desc: String = ""
@export var ability1_video: VideoStream = null

@export_group("Ability 2")
@export var ability2_name: String = ""
@export_multiline var ability2_desc: String = ""
@export var ability2_video: VideoStream = null

@export_group("Ultimate")
@export var ult_name: String = "Ultimate"
@export_multiline var ult_desc: String = ""
@export var ult_video: VideoStream = null
