class_name PlayerHud
extends RefCounted

## All per-player UI for one Player: cooldown HUD, world health bar, nametag,
## tooltip, status overlays (drug/blind), death timer, and elimination screen.
## Injected with the owning Player; reads gameplay state, never mutates it.

const _ULT_BANNER_PORTRAIT_SHADER = preload("res://assets/shaders/electric_wrap.gdshader")
const _UI_FONT = preload("res://assets/ui/fonts/BATTLESANSSERIF.OTF")
const DrugShader = preload("res://assets/shaders/drug.gdshader")
const BlindShader = preload("res://assets/shaders/blind.gdshader")

var player: Player

# Cooldown / HUD nodes
var cooldown_ui: CanvasLayer = null
var shoot_cd_bar: ProgressBar = null
var ability1_cd_bar: ProgressBar = null
var ability2_cd_bar: ProgressBar = null
var ability2_charge_bar_1: ProgressBar = null
var ability2_charge_bar_2: ProgressBar = null
var loan_shark_charge_row: Control = null
var reload_cd_bar: ProgressBar = null
var dash_cd_bar: ProgressBar = null
var ammo_label: Label = null
var ult_bar: ProgressBar = null
var ult_label: Label = null

var local_health_bar: Range = null
var local_health_bar_label: Label = null
var target_health_bar_value: float = 0.0
var target_health_bar_color: Color = Color.WHITE

var ability_1_mask: TextureRect = null
var ability_1_bar: Range = null
var ability_1_animation: AnimationPlayer = null
var ability_2_mask: TextureRect = null
var ability_2_bar: Range = null
var ability_2_animation: AnimationPlayer = null

var character_profile: TextureRect = null
var ult_percent_label: Label = null
var _profile_base_pos: Vector2 = Vector2.ZERO
var _ult_ready_mat: ShaderMaterial

# World-space bar widgets (children of player's HealthBar)
var health_bar_fill: ColorRect = null
var mark_indicator: CanvasItem = null
var nametag: Label = null
var reload_bar: Range = null
var reload_bar_animation: AnimationPlayer = null
var reload_bar_finish_animation: AnimationPlayer = null
var reload_prompt: Control = null
var reload_prompt_animation: AnimationPlayer = null
var ammo_left: Label = null
var ammo_left_animation: AnimationPlayer = null

# Tooltip
var tooltip_layer: CanvasLayer = null
var tooltip_label: RichTextLabel = null

# Status overlays / death / elimination
var drug_effect_layer: CanvasLayer = null
var blind_effect_layer: CanvasLayer = null
var _death_ui: CanvasLayer = null
var _death_timer_label: Label = null
var _elim_ui: CanvasLayer = null

# Cached UI labels to skip setting identical strings every frame.
var _last_ammo_text: String = ""
var _last_ult_text: String = ""
var _last_ult_pct_text: String = ""
var _last_ult_full: int = -1
var _last_a1_hint_text: String = ""
var _last_a2_hint_text: String = ""
var _last_a2_count_text: String = ""
var _ui_bound_hero: Hero = null
var _a1_hint_label: Label = null
var _a2_hint_label: Label = null
var _a2_count_label: Label = null

var show_aux_ui: bool = false

func _init(p: Player) -> void:
	player = p
	_cache_nodes()
	_ult_ready_mat = ShaderMaterial.new()
	_ult_ready_mat.shader = _ULT_BANNER_PORTRAIT_SHADER
	_ult_ready_mat.set_shader_parameter("edge_px", 2.2)
	_ult_ready_mat.set_shader_parameter("glow_strength", 1.4)
	_ult_ready_mat.set_shader_parameter("speed", 1.5)
	_ult_ready_mat.set_shader_parameter("noise_scale", 48.0)
	_ult_ready_mat.set_shader_parameter("pulse", 0.35)
	_ult_ready_mat.set_shader_parameter("progress", 1.0)
	_ult_ready_mat.set_shader_parameter("edge_width", 0.05)
	_ult_ready_mat.set_shader_parameter("edge_color", Color(1.0, 0.5, 0.1, 1.0))
	_ult_ready_mat.set_shader_parameter("edge_color_inner", Color(1.0, 0.9, 0.3, 1.0))
	_ult_ready_mat.set_shader_parameter("alpha_cutoff", 0.01)

func _cache_nodes() -> void:
	cooldown_ui = player.get_node_or_null("CooldownUI")
	if cooldown_ui:
		var container = cooldown_ui.get_node_or_null("Container")
		if container:
			shoot_cd_bar = container.get_node_or_null("ShootCD/Bar")
			ability1_cd_bar = container.get_node_or_null("Ability1CD/Bar")
			ability2_cd_bar = container.get_node_or_null("Ability2CD/Bar")
			loan_shark_charge_row = container.get_node_or_null("Ability2CD/LoanSharkCharges")
			ability2_charge_bar_1 = container.get_node_or_null("Ability2CD/LoanSharkCharges/Charge1")
			ability2_charge_bar_2 = container.get_node_or_null("Ability2CD/LoanSharkCharges/Charge2")
			reload_cd_bar = container.get_node_or_null("ReloadCD/Bar")
			dash_cd_bar = container.get_node_or_null("DashCD/Bar")
			ammo_label = container.get_node_or_null("Ammo/Count")
			ult_bar = container.get_node_or_null("UltCD/Bar")
			ult_label = container.get_node_or_null("UltCD/Count")
		local_health_bar = cooldown_ui.get_node_or_null("HealthBar")
		local_health_bar_label = cooldown_ui.get_node_or_null("HealthBar/Label")
		ability_1_mask = cooldown_ui.get_node_or_null("Ability1_mask")
		ability_1_bar = cooldown_ui.get_node_or_null("Ability1_mask/Ability1")
		ability_1_animation = cooldown_ui.get_node_or_null("Ability1_mask/Ability1/AnimationPlayer")
		ability_2_mask = cooldown_ui.get_node_or_null("Ability2_mask")
		ability_2_bar = cooldown_ui.get_node_or_null("Ability2_mask/Ability2")
		ability_2_animation = cooldown_ui.get_node_or_null("Ability2_mask/Ability2/AnimationPlayer")
		character_profile = cooldown_ui.get_node_or_null("Profile")
		ult_percent_label = cooldown_ui.get_node_or_null("Profile/Label")
		if character_profile:
			_profile_base_pos = character_profile.position
	
	var hb = player.health_bar
	if hb:
		health_bar_fill = hb.get_node_or_null("Fill")
		mark_indicator = hb.get_node_or_null("MarkIndicator")
		nametag = hb.get_node_or_null("Nametag")
		reload_bar = hb.get_node_or_null("ReloadBar")
		reload_bar_animation = hb.get_node_or_null("ReloadBar/AnimationPlayer")
		reload_bar_finish_animation = hb.get_node_or_null("ReloadBar/Finish")
		reload_prompt = hb.get_node_or_null("ReloadPrompt")
		reload_prompt_animation = hb.get_node_or_null("ReloadPrompt/AnimationPlayer")
		ammo_left = hb.get_node_or_null("AmmoLeft")
		ammo_left_animation = hb.get_node_or_null("AmmoLeft/AnimationPlayer")

# --- SETUP ---

func setup_local_ui() -> void:
	show_aux_ui = should_show_local_ui()
	var show_ui = show_aux_ui
	
	if player.camera:
		player.camera.enabled = show_ui
	
	if cooldown_ui:
		cooldown_ui.visible = show_ui
	refresh_world_health_bar()
	
	if show_ui:
		_create_tooltip()
		if player.hero:
			bind_hero_ui_signals(player.hero)
			refresh_hero_ui()
		update_ability_icon_text_ui()

func should_show_local_ui() -> bool:
	if player.input is LocalInput:
		return player.player_id == 0
	if player.input is NetworkInput:
		return player.input.is_local
	return false

func setup_nametag() -> void:
	if nametag == null:
		return
	var gm = GameManager.instance
	if gm and gm.player_data.has(player.player_id):
		nametag.text = gm.get_player_username(player.player_id)
	elif player.is_ai_player:
		nametag.text = "bot %d" % player.player_id
	else:
		nametag.text = "player %d" % player.player_id

# --- HERO UI BINDING ---

func bind_hero_ui_signals(h: Hero) -> void:
	if h == null:
		return
	if _ui_bound_hero != null and _ui_bound_hero != h:
		unbind_hero_ui_signals(_ui_bound_hero)
	_ui_bound_hero = h

	var cb_a1_use := Callable(self, "ability_1_use_animation")
	if not h.used_ability_1.is_connected(cb_a1_use):
		h.used_ability_1.connect(cb_a1_use)
	var cb_a2_use := Callable(self, "ability_2_use_animation")
	if not h.used_ability_2.is_connected(cb_a2_use):
		h.used_ability_2.connect(cb_a2_use)
	var cb_a1_ref := Callable(self, "ability_1_refresh_animation")
	if not h.ability_1_refreshed.is_connected(cb_a1_ref):
		h.ability_1_refreshed.connect(cb_a1_ref)
	if h.uses_gun_ammo():
		var cb_out := Callable(self, "prompt_reload")
		if not h.ran_out_of_ammo.is_connected(cb_out):
			h.ran_out_of_ammo.connect(cb_out)
		var cb_start := Callable(self, "show_reload_bar")
		if not h.started_reload.is_connected(cb_start):
			h.started_reload.connect(cb_start)
		var cb_fin := Callable(self, "hide_reload_bar")
		if not h.finished_reload.is_connected(cb_fin):
			h.finished_reload.connect(cb_fin)
		var cb_upd := Callable(self, "update_ammo_left")
		if not h.finished_reload.is_connected(cb_upd):
			h.finished_reload.connect(cb_upd)
		if not h.shot.is_connected(cb_upd):
			h.shot.connect(cb_upd)

func unbind_hero_ui_signals(h: Hero) -> void:
	if h == null:
		return
	var cb_a1_use := Callable(self, "ability_1_use_animation")
	if h.used_ability_1.is_connected(cb_a1_use):
		h.used_ability_1.disconnect(cb_a1_use)
	var cb_a2_use := Callable(self, "ability_2_use_animation")
	if h.used_ability_2.is_connected(cb_a2_use):
		h.used_ability_2.disconnect(cb_a2_use)
	var cb_a1_ref := Callable(self, "ability_1_refresh_animation")
	if h.ability_1_refreshed.is_connected(cb_a1_ref):
		h.ability_1_refreshed.disconnect(cb_a1_ref)
	var cb_out := Callable(self, "prompt_reload")
	if h.ran_out_of_ammo.is_connected(cb_out):
		h.ran_out_of_ammo.disconnect(cb_out)
	var cb_start := Callable(self, "show_reload_bar")
	if h.started_reload.is_connected(cb_start):
		h.started_reload.disconnect(cb_start)
	var cb_fin := Callable(self, "hide_reload_bar")
	if h.finished_reload.is_connected(cb_fin):
		h.finished_reload.disconnect(cb_fin)
	var cb_upd := Callable(self, "update_ammo_left")
	if h.finished_reload.is_connected(cb_upd):
		h.finished_reload.disconnect(cb_upd)
	if h.shot.is_connected(cb_upd):
		h.shot.disconnect(cb_upd)

func notify_hero_changed(prev: Hero) -> void:
	if prev == _ui_bound_hero:
		_ui_bound_hero = null
	if should_show_local_ui():
		bind_hero_ui_signals(player.hero)
		refresh_hero_ui()

func refresh_hero_ui() -> void:
	var hero = player.hero
	if hero == null:
		return
	var health_amount: int = int(hero.get_health())
	target_health_bar_value = hero.get_health_percent() * 100
	target_health_bar_color = Color.WHITE
	if local_health_bar_label:
		local_health_bar_label.text = str(health_amount)
	if character_profile:
		character_profile.texture = hero.get_hero_default_profile()
		character_profile.material = null
		character_profile.position = _profile_base_pos + hero.get_hero_portrait_offset()
	_set_ability_mask_tex(ability_1_mask, hero.get_hero_ability1_icon())
	var has_a2: bool = hero.has_hero_ability2()
	if ability_2_mask:
		ability_2_mask.visible = has_a2
	if ability_2_bar:
		ability_2_bar.visible = has_a2
	_set_ability_mask_tex(ability_2_mask, hero.get_hero_ability2_icon() if has_a2 else null)
	if ability_1_bar:
		ability_1_bar.modulate = hero.get_hero_ui_color()
	if ability_2_bar:
		ability_2_bar.modulate = hero.get_hero_ui_color()
	if hero.uses_gun_ammo():
		update_ammo_left()

	refresh_movement_dash_ui_visibility()
	refresh_ability2_charge_ui_visibility()
	refresh_gun_ui_visibility()
	update_ability_icon_text_ui()

# --- VISIBILITY REFRESHERS ---

func refresh_gun_ui_visibility() -> void:
	var hero = player.hero
	if hero == null:
		return
	var gun := hero.uses_gun_ammo()
	if cooldown_ui:
		var c := cooldown_ui.get_node_or_null("Container")
		if c:
			var rc := c.get_node_or_null("ReloadCD")
			if rc:
				rc.visible = gun and show_aux_ui
			var am := c.get_node_or_null("Ammo")
			if am:
				am.visible = gun and show_aux_ui
	if reload_bar:
		reload_bar.visible = gun and show_aux_ui
	if reload_prompt:
		reload_prompt.visible = gun and show_aux_ui
	if ammo_left:
		ammo_left.visible = gun and show_aux_ui
	if not gun:
		if reload_bar_animation and reload_bar_animation.is_playing():
			reload_bar_animation.stop()
		if reload_prompt_animation and reload_prompt_animation.is_playing():
			reload_prompt_animation.stop()
		if ammo_left_animation and ammo_left_animation.is_playing():
			ammo_left_animation.stop()

func refresh_ability2_charge_ui_visibility() -> void:
	if ability2_cd_bar == null:
		return
	var a2_parent := ability2_cd_bar.get_parent()
	if a2_parent == null:
		return
	var hero = player.hero
	if hero and hero.use_ability2_charge_row_ui():
		a2_parent.visible = hero.has_hero_ability2()
		ability2_cd_bar.visible = false
		if loan_shark_charge_row:
			loan_shark_charge_row.visible = true
	elif hero != null:
		a2_parent.visible = hero.ability2_cooldown > 0
		ability2_cd_bar.visible = hero.ability2_cooldown > 0
		if loan_shark_charge_row:
			loan_shark_charge_row.visible = false
	else:
		a2_parent.visible = false
		if loan_shark_charge_row:
			loan_shark_charge_row.visible = false

func refresh_movement_dash_ui_visibility() -> void:
	if dash_cd_bar == null:
		return
	var dash_parent := dash_cd_bar.get_parent()
	if dash_parent == null:
		return
	if player.hero and not player.hero.allows_movement_dash():
		dash_parent.visible = false
	else:
		dash_parent.visible = show_aux_ui

# --- ABILITY ICON HINT TEXT ---

func setup_ability_icon_text_ui() -> void:
	if cooldown_ui == null:
		return
	_a1_hint_label = cooldown_ui.get_node_or_null("Ability1Hint")
	if _a1_hint_label == null:
		_a1_hint_label = Label.new()
		_a1_hint_label.name = "Ability1Hint"
		_a1_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_a1_hint_label.add_theme_font_size_override("font_size", 16)
		cooldown_ui.add_child(_a1_hint_label)
	_a2_hint_label = cooldown_ui.get_node_or_null("Ability2Hint")
	if _a2_hint_label == null:
		_a2_hint_label = Label.new()
		_a2_hint_label.name = "Ability2Hint"
		_a2_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_a2_hint_label.add_theme_font_size_override("font_size", 16)
		cooldown_ui.add_child(_a2_hint_label)
	_a2_count_label = cooldown_ui.get_node_or_null("Ability2Count")
	if _a2_count_label == null:
		_a2_count_label = Label.new()
		_a2_count_label.name = "Ability2Count"
		_a2_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_a2_count_label.add_theme_font_size_override("font_size", 18)
		cooldown_ui.add_child(_a2_count_label)
	for label in [_a1_hint_label, _a2_hint_label, _a2_count_label]:
		if label == null:
			continue
		label.add_theme_font_override("font", _UI_FONT)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 6)
	update_ability_icon_text_ui()

func update_ability_icon_text_ui() -> void:
	if cooldown_ui == null or not cooldown_ui.visible:
		return
	if _a1_hint_label == null or _a2_hint_label == null or _a2_count_label == null:
		return
	if ability_1_mask:
		var sz1 := ability_1_mask.size * ability_1_mask.scale
		_a1_hint_label.position = ability_1_mask.position + Vector2(0, sz1.y + 2)
		_a1_hint_label.size = Vector2(sz1.x, 22)
	if ability_2_mask:
		var sz2 := ability_2_mask.size * ability_2_mask.scale
		_a2_hint_label.position = ability_2_mask.position + Vector2(0, sz2.y + 2)
		_a2_hint_label.size = Vector2(sz2.x, 22)
		_a2_count_label.position = ability_2_mask.position + Vector2(0, -22)
		_a2_count_label.size = Vector2(sz2.x, 22)
	var a1_hint := _ability_key_hint("ability1")
	var a2_hint := _ability_key_hint("ability2")
	if a1_hint != _last_a1_hint_text:
		_a1_hint_label.text = a1_hint
		_last_a1_hint_text = a1_hint
	if a2_hint != _last_a2_hint_text:
		_a2_hint_label.text = a2_hint
		_last_a2_hint_text = a2_hint
	_a1_hint_label.visible = ability_1_mask != null and ability_1_mask.visible and not a1_hint.is_empty()
	_a2_hint_label.visible = ability_2_mask != null and ability_2_mask.visible and not a2_hint.is_empty()
	var count_text := ""
	var hero = player.hero
	if hero and hero.get_ability2_charge_count() >= 0:
		count_text = "x%d" % hero.get_ability2_charge_count()
	if count_text != _last_a2_count_text:
		_a2_count_label.text = count_text
		_last_a2_count_text = count_text
	_a2_count_label.visible = ability_2_mask != null and ability_2_mask.visible and not count_text.is_empty()

func _ability_key_hint(action: String) -> String:
	var pid = player.player_id
	if pid < 0 or pid > 3:
		return ""
	if not LocalInput.KB_MAPS.has(pid):
		return ""
	var kb: Dictionary = LocalInput.KB_MAPS[pid]
	if not kb.has(action):
		return ""
	var key_name := OS.get_keycode_string(int(kb[action])).to_lower()
	if action == "ability1" and player.input is LocalInput:
		var li := player.input as LocalInput
		if li.use_mouse and pid == 0:
			return (key_name + "/rmb").to_lower()
	return key_name

func _set_ability_mask_tex(mask: TextureRect, tex: Texture2D) -> void:
	if mask == null:
		return
	mask.texture = tex

# --- WORLD HEALTH BAR / NAMETAG ---

func _show_enemy_health_bar() -> bool:
	return not player._is_local_player() and not player.in_spectate_mode \
		and not player.is_awaiting_respawn and not player.is_dying and not player.is_dead()

func refresh_world_health_bar() -> void:
	var hb = player.health_bar
	if hb == null:
		return
	# Heroes that can go invisible (Dealer) hide the whole bar; without this,
	# any health change would recompute visibility and reveal them mid-invis.
	var hero = player.hero
	var invis: bool = hero != null and hero.has_method("is_invisible") and hero.is_invisible()
	var show_enemy = _show_enemy_health_bar() and not invis
	hb.visible = (show_aux_ui or show_enemy) and not invis
	if health_bar_fill:
		health_bar_fill.visible = show_enemy
	var bg = hb.get_node_or_null("Background")
	if bg:
		bg.visible = show_enemy
	if nametag:
		nametag.visible = show_enemy
	refresh_mark_indicator()

func refresh_mark_indicator() -> void:
	if mark_indicator == null or player.health_bar == null:
		return
	mark_indicator.visible = player.is_marked and player.health_bar.visible

func update_health_bar() -> void:
	var hero = player.hero
	if health_bar_fill == null or hero == null:
		return
	refresh_world_health_bar()
	
	var pct = hero.get_health_percent()
	health_bar_fill.scale.x = pct
	
	if pct > 0.5:
		health_bar_fill.color = Color(0.2, 0.8, 0.2)
		target_health_bar_color = Color.WHITE
	elif pct > 0.25:
		health_bar_fill.color = Color(0.8, 0.8, 0.2)
		target_health_bar_color = Color.CORAL
	else:
		health_bar_fill.color = Color(0.8, 0.2, 0.2)
		target_health_bar_color = Color.RED
	
	if local_health_bar_label:
		local_health_bar_label.text = str(int(hero.get_health()))
	target_health_bar_value = hero.get_health_percent() * 100

# --- PER-FRAME ---

func physics_update(delta: float) -> void:
	if player.health_bar:
		player.health_bar.global_position = player.global_position + Vector2(-25, -60)
	_update_cooldown_ui()
	_update_tooltip()
	if local_health_bar:
		local_health_bar.value = lerpf(local_health_bar.value, target_health_bar_value, delta * 10)
		local_health_bar.modulate = lerp(local_health_bar.modulate, target_health_bar_color, delta * 10)

func _update_cooldown_ui() -> void:
	var hero = player.hero
	if hero == null or cooldown_ui == null or not cooldown_ui.visible:
		return
	
	if shoot_cd_bar:
		var shoot_pct = 1.0 - (hero.shoot_cd / hero.shoot_cooldown) if hero.shoot_cooldown > 0 else 1.0
		shoot_cd_bar.value = clamp(shoot_pct, 0.0, 1.0)
	
	if ability1_cd_bar:
		var a1_pct = 1.0 - (hero.ability1_cd / hero.ability1_cooldown) if hero.ability1_cooldown > 0 else 1.0
		ability1_cd_bar.value = clamp(a1_pct, 0.0, 1.0)
		ability_1_bar.value = clamp(a1_pct, 0.0, 1.0)
		ability_1_bar.modulate.a = 0.35 if a1_pct < 1.0 else 1.0
	
	if ability2_cd_bar:
		if hero.use_ability2_charge_row_ui():
			ability2_cd_bar.get_parent().visible = hero.has_hero_ability2()
			ability2_cd_bar.visible = false
			if loan_shark_charge_row:
				loan_shark_charge_row.visible = true
			if ability2_charge_bar_1:
				ability2_charge_bar_1.value = clamp(hero.get_ability2_charge_row_progress(0), 0.0, 1.0)
			if ability2_charge_bar_2:
				ability2_charge_bar_2.value = clamp(hero.get_ability2_charge_row_progress(1), 0.0, 1.0)
		elif hero.ability2_cooldown > 0:
			ability2_cd_bar.visible = true
			var a2_pct = hero.get_ability2_ui_progress()
			ability2_cd_bar.value = clamp(a2_pct, 0.0, 1.0)
			ability2_cd_bar.get_parent().visible = true
			if loan_shark_charge_row:
				loan_shark_charge_row.visible = false
		else:
			ability2_cd_bar.get_parent().visible = false
			if loan_shark_charge_row:
				loan_shark_charge_row.visible = false
	
	if ability_2_bar and ability_2_bar.visible:
		var a2_pct2 = hero.get_ability2_ui_progress()
		ability_2_bar.value = clamp(a2_pct2, 0.0, 1.0)
		ability_2_bar.modulate.a = 1.0 if hero.can_ability2() else 0.35
	
	if reload_cd_bar and hero.uses_gun_ammo():
		var reload_pct = 1.0 - (hero.reload_cd / hero.reload_time) if hero.reload_time > 0 else 1.0
		reload_cd_bar.value = clamp(reload_pct, 0.0, 1.0)
		reload_bar.value = clamp(reload_pct, 0.15, 1.0)
	
	if dash_cd_bar and hero.allows_movement_dash():
		var dash_pct = 1.0 - (player.dash_cd_timer / player.dash_cooldown) if player.dash_cooldown > 0 else 1.0
		dash_cd_bar.value = clamp(dash_pct, 0.0, 1.0)
	
	if ammo_label and hero.uses_gun_ammo():
		var ammo_text = "%d/%d" % [hero.ammo, hero.mag_size]
		if ammo_text != _last_ammo_text:
			ammo_label.text = ammo_text
			_last_ammo_text = ammo_text
	
	var ult_pct := hero.get_ult_percent()
	var ult_full := ult_pct >= 1.0
	var pct_text := "c" if ult_full else str(int(ult_pct * 100))
	if pct_text != _last_ult_pct_text:
		ult_percent_label.text = pct_text
		_last_ult_pct_text = pct_text
	var full_flag := 1 if ult_full else 0
	if full_flag != _last_ult_full:
		_last_ult_full = full_flag
		if ult_full:
			character_profile.texture = hero.get_hero_ult_profile()
			var c := hero.get_hero_ui_color()
			_ult_ready_mat.set_shader_parameter("color_a", c.lerp(Color.WHITE, 0.2))
			_ult_ready_mat.set_shader_parameter("color_b", c.lerp(Color.BLACK, 0.35))
			character_profile.material = _ult_ready_mat
		else:
			character_profile.texture = hero.get_hero_default_profile()
			character_profile.material = null
		character_profile.position = _profile_base_pos + hero.get_hero_portrait_offset()
	
	if ult_bar:
		ult_bar.value = ult_pct
	
	if ult_label:
		var ult_text: String
		if hero.ult_mode == Hero.UltMode.COOLDOWN:
			ult_text = "ready" if hero.ult_cd <= 0.0 else "%.1fs" % hero.ult_cd
		else:
			ult_text = "%d/%d" % [hero.ult_points, hero.max_ult_points]
		if ult_text != _last_ult_text:
			ult_label.text = ult_text
			_last_ult_text = ult_text
	update_ability_icon_text_ui()

# --- TOOLTIP ---

func _create_tooltip() -> void:
	tooltip_layer = CanvasLayer.new()
	tooltip_layer.layer = 50
	player.add_child(tooltip_layer)
	
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_label.size = Vector2(200, 60)
	
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.add_child(tooltip_label)
	tooltip_layer.add_child(panel)

func _update_tooltip() -> void:
	if tooltip_label == null:
		return
	
	var panel = tooltip_label.get_parent()
	var mouse_pos = player.get_viewport().get_mouse_position()
	var world_mouse = player.get_global_mouse_position()
	var crop = _find_crop_at(world_mouse)
	
	if crop:
		tooltip_label.text = crop.get_tooltip_bbcode()
		panel.visible = true
		panel.position = mouse_pos + Vector2(16, 16)
	else:
		panel.visible = false

func _find_crop_at(world_pos: Vector2) -> Crop:
	var space = player.get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var results = space.intersect_point(params, 8)
	for result in results:
		if result.collider is Crop:
			return result.collider
	
	var gm = GameManager.instance
	var farms = gm.get_farms() if gm else player.get_tree().get_nodes_in_group("farms")
	for f in farms:
		for c in f.crops:
			if is_instance_valid(c) and c.global_position.distance_to(world_pos) < 30.0:
				return c
	return null

# --- RELOAD / AMMO / ABILITY ANIMATIONS (hero signal targets) ---

func prompt_reload() -> void:
	if reload_prompt_animation:
		reload_prompt_animation.play("appear")

func show_reload_bar() -> void:
	if player.hero and player.hero.ammo == 0 and reload_prompt_animation:
		reload_prompt_animation.play("disappear")
	if reload_bar_animation:
		reload_bar_animation.play("appear")

func hide_reload_bar() -> void:
	if reload_bar_animation:
		reload_bar_animation.play("finish")
	if reload_bar_finish_animation:
		reload_bar_finish_animation.play("finish")

func update_ammo_left() -> void:
	if ammo_left == null or player.hero == null:
		return
	ammo_left.text = str(player.hero.ammo)
	ammo_left_animation.stop()
	ammo_left_animation.play("shoot")

func ability_1_use_animation() -> void:
	if ability_1_animation:
		ability_1_animation.play("use")

func ability_1_refresh_animation() -> void:
	if ability_1_animation:
		ability_1_animation.play("refreshed")

func ability_2_use_animation() -> void:
	if ability_2_animation:
		ability_2_animation.play("use")

# --- STATUS OVERLAYS ---

func show_drug_overlay() -> void:
	if drug_effect_layer:
		return
	drug_effect_layer = CanvasLayer.new()
	drug_effect_layer.layer = 100
	player.add_child(drug_effect_layer)
	
	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	mat.shader = DrugShader
	mat.set_shader_parameter("wobble_intensity", 0.025)
	mat.set_shader_parameter("color_intensity", 0.35)
	mat.set_shader_parameter("color_speed", 2.0)
	rect.material = mat
	
	drug_effect_layer.add_child(rect)

func hide_drug_overlay() -> void:
	if drug_effect_layer:
		drug_effect_layer.queue_free()
		drug_effect_layer = null

func show_blind_overlay() -> void:
	if blind_effect_layer:
		return
	blind_effect_layer = CanvasLayer.new()
	blind_effect_layer.layer = 100
	player.add_child(blind_effect_layer)
	
	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	mat.shader = BlindShader
	mat.set_shader_parameter("flash_speed", 3.0)
	mat.set_shader_parameter("intensity", 1)
	mat.set_shader_parameter("fade", 1.0)
	rect.material = mat
	
	blind_effect_layer.add_child(rect)

func hide_blind_overlay() -> void:
	if blind_effect_layer:
		blind_effect_layer.queue_free()
		blind_effect_layer = null

# --- DEATH / RESPAWN UI ---

## Hides HUD elements when the player dies or starts spectating.
func hide_world_ui() -> void:
	if cooldown_ui:
		cooldown_ui.visible = false
	if player.health_bar:
		player.health_bar.visible = false
	if tooltip_layer:
		tooltip_layer.visible = false

func show_death_timer() -> void:
	_death_ui = CanvasLayer.new()
	_death_ui.layer = 90
	player.add_child(_death_ui)
	
	_death_timer_label = Label.new()
	_death_timer_label.text = "respawning in 10s"
	_death_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_timer_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_timer_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_timer_label.add_theme_font_size_override("font_size", 36)
	_death_timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_death_ui.add_child(_death_timer_label)

func update_death_timer(countdown: float) -> void:
	if _death_timer_label:
		_death_timer_label.text = "respawning in %ds" % ceili(max(countdown, 0.0))

func clear_death_ui() -> void:
	if _death_ui:
		_death_ui.queue_free()
		_death_ui = null
		_death_timer_label = null

func on_respawn() -> void:
	clear_death_ui()
	if player._is_local_player() and cooldown_ui:
		cooldown_ui.visible = true
	refresh_world_health_bar()

# --- ELIMINATION UI ---

func show_elimination_ui() -> void:
	_elim_ui = CanvasLayer.new()
	_elim_ui.layer = 90
	player.add_child(_elim_ui)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_elim_ui.add_child(bg)
	
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(360, 0)
	center.add_theme_constant_override("separation", 24)
	bg.add_child(center)
	
	var title = Label.new()
	title.text = "eliminated"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	center.add_child(title)
	
	var spectate_btn = Button.new()
	spectate_btn.text = "spectate"
	spectate_btn.custom_minimum_size = Vector2(160, 48)
	spectate_btn.pressed.connect(player._on_spectate_pressed)
	center.add_child(spectate_btn)

func clear_elimination_ui() -> void:
	if _elim_ui:
		_elim_ui.queue_free()
		_elim_ui = null
