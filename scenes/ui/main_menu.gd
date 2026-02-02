extends Control

const CardAction = preload("res://scripts/ui/menu_hero_card.gd").CardAction

@export var unhover_delay: float = 0.25

@onready var option_banner = $introgroup1/paintstrip/OptionBanner
@onready var dealer = $introgroup1/cardholder/dealer
@onready var burple = $introgroup1/cardholder/burple
@onready var garebare = $introgroup1/cardholder/garebare
@onready var anim_player = $introgroup1/AnimationPlayer
@onready var burn_overlay = $BurnOverlay

var skippable = true
var _current_hovered: CardAction = CardAction.NONE
var _unhover_timer: SceneTreeTimer = null

func _ready() -> void:
	_connect_card(dealer)
	_connect_card(burple)
	_connect_card(garebare)
	
	# Skip intro if returning from another scene
	if not GameData.is_first_load:
		_skip_intro()
	else:
		GameData.mark_intro_seen()

func _skip_intro() -> void:
	if not skippable:
		return
	if burn_overlay:
		burn_overlay.queue_free()
	
	if anim_player:
		anim_player.stop()
		anim_player.play("idle2")
	if not $introgroup1/AudioStreamPlayer.playing:
		$introgroup1/AudioStreamPlayer.playing = true
	# Ensure hover areas are enabled (animation keyframes at -0.1 won't apply)
	_enable_hover_areas()

func _enable_hover_areas() -> void:
	for card in [dealer, burple, garebare]:
		if card:
			var hover = card.get_node_or_null("HoverArea")
			if hover:
				hover.input_pickable = true

func _connect_card(card: Node) -> void:
	if card and card.has_signal("card_hovered"):
		card.card_hovered.connect(_on_card_hovered)
	if card and card.has_signal("card_unhovered"):
		card.card_unhovered.connect(_on_card_unhovered)

func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_skip_intro()

func _on_card_hovered(action: CardAction) -> void:
	if not option_banner:
		return
	
	# Cancel any pending unhover reset
	_unhover_timer = null
	_current_hovered = action
	
	match action:
		CardAction.JOIN:
			option_banner.set_option(1)
		CardAction.HOST:
			option_banner.set_option(2)
		CardAction.PRACTICE:
			option_banner.set_option(3)

func _on_card_unhovered() -> void:
	if not option_banner:
		return
	
	# Delay the reset to allow switching directly between cards
	_unhover_timer = get_tree().create_timer(unhover_delay)
	_unhover_timer.timeout.connect(_on_unhover_timeout)

func _on_unhover_timeout() -> void:
	# Only reset if no card is currently hovered
	if _unhover_timer != null:
		_unhover_timer = null
		option_banner.set_option(0)

func _on_intro_finish():
	$introgroup1/AnimationPlayer.play("idle2")
	skippable = false
