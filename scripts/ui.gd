extends Control
class_name NeonRunnerUI

signal start_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal volume_changed(value: float)
signal swipe_action(action: StringName)
signal shop_requested
signal shop_closed
signal booster_buy(booster: StringName)
signal booster_use(booster: StringName)

var _score_label: Label
var _coin_label: Label
var _best_label: Label
var _powerup_label: Label
var _overlay: ColorRect
var _title_label: Label
var _detail_label: Label
var _start_button: Button
var _pause_button: Button
var _roll_button: Button
var _resume_button: Button
var _restart_button: Button
var _shop_button: Button
var _shop_back_button: Button
var _shop_booster_buttons: Dictionary = {}
var _booster_row: HBoxContainer
var _booster_use_buttons: Dictionary = {}
var _touch_controls: Control
var _touch_buttons: Array[Button] = []
var _volume_slider: HSlider
var _volume_row: HBoxContainer
var _hud: GridContainer
var _touch_start := Vector2.ZERO
var _touch_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	_build_overlay()
	_build_touch_hint()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func update_stats(score: int, coins: int, wallet: int, high_score: int) -> void:
	_score_label.text = "DISTANZ  %06d" % score
	_coin_label.text = "MÜNZEN  %03d  |  BANK  %03d" % [coins, wallet]
	_best_label.text = "BEST  %06d" % high_score

func update_boosters(boosters: Dictionary, timers: Dictionary) -> void:
	var titles := {"shield": "SCHILD", "magnet": "MAGNET", "turbo": "TURBO"}
	for booster in titles:
		var count: int = int(boosters.get(booster, 0))
		var timer: float = float(timers.get(booster, 0.0))
		var button: Button = _booster_use_buttons[booster]
		button.text = "%s %.0fs" % [titles[booster], timer] if timer > 0.0 else "%s x%d" % [titles[booster], count]
		button.disabled = count <= 0 or timer > 0.0

func update_powerups(timers: Dictionary) -> void:
	var active := PackedStringArray()
	if float(timers.get("high_jump", 0.0)) > 0.0:
		active.append("HOCHSPRUNG %.0fs" % float(timers["high_jump"]))
	if float(timers.get("double_coins", 0.0)) > 0.0:
		active.append("DOPPELTE MÜNZEN %.0fs" % float(timers["double_coins"]))
	if float(timers.get("hoverboard", 0.0)) > 0.0:
		active.append("HOVERBOARD %.0fs" % float(timers["hoverboard"]))
	_powerup_label.text = "   ·   ".join(active)
	_powerup_label.visible = not active.is_empty()

func show_title(high_score: int, volume: float, wallet: int, boosters: Dictionary) -> void:
	_overlay.visible = true
	_title_label.text = "NEON RUNNER"
	_detail_label.text = "Wechsle die Spur, springe, rutsche oder rolle unter Hindernissen durch.\nSammle Hochsprung, doppelte Münzen und Hoverboards ein.\n\n← / A   links     → / D   rechts\n↑ / W / Leertaste   springen     ↓ / S   rutschen\nR   rollen     1 / 2 / 3   Booster einsetzen"
	_start_button.visible = true
	_resume_button.visible = false
	_restart_button.visible = false
	_shop_button.visible = true
	_shop_back_button.visible = false
	_set_shop_buttons_visible(false)
	_volume_row.visible = true
	_volume_slider.value = volume
	update_stats(0, 0, wallet, high_score)
	update_shop(wallet, boosters)
	_pause_button.visible = false
	_booster_row.visible = false

func show_hud() -> void:
	_overlay.visible = false
	_pause_button.visible = true
	_booster_row.visible = true
	_roll_button.visible = true

func show_pause(high_score: int) -> void:
	_overlay.visible = true
	_title_label.text = "PAUSE"
	_detail_label.text = "Deine Runde wartet auf dich.\nBestleistung: %06d" % high_score
	_start_button.visible = false
	_resume_button.visible = true
	_restart_button.visible = true
	_shop_button.visible = true
	_shop_back_button.visible = false
	_set_shop_buttons_visible(false)
	_volume_row.visible = false
	_pause_button.visible = false
	_booster_row.visible = false
	_roll_button.visible = false

func show_game_over(score: int, high_score: int) -> void:
	_overlay.visible = true
	_title_label.text = "RUNDE BEENDET"
	_detail_label.text = "Strecke: %06d     Bestleistung: %06d" % [score, high_score]
	_start_button.visible = false
	_resume_button.visible = false
	_restart_button.visible = true
	_shop_button.visible = true
	_shop_back_button.visible = false
	_set_shop_buttons_visible(false)
	_volume_row.visible = false
	_pause_button.visible = false
	_booster_row.visible = false
	_roll_button.visible = false

func show_shop(wallet: int, boosters: Dictionary) -> void:
	_overlay.visible = true
	_title_label.text = "BOOSTER-SHOP"
	_detail_label.text = "Schild: 8 s Schutz  ·  Magnet: Münzen in Nähe\nTurbo: 6 s schneller laufen\nGuthaben: %d Münzen" % wallet
	_start_button.visible = false
	_resume_button.visible = false
	_restart_button.visible = false
	_shop_button.visible = false
	_shop_back_button.visible = true
	_set_shop_buttons_visible(true)
	_volume_row.visible = false
	_pause_button.visible = false
	_booster_row.visible = false
	_roll_button.visible = false
	update_shop(wallet, boosters)

func update_shop(wallet: int, boosters: Dictionary) -> void:
	var prices := {"shield": 80, "magnet": 40, "turbo": 60}
	var titles := {"shield": "SCHILD", "magnet": "MAGNET", "turbo": "TURBO"}
	for booster in prices:
		var count: int = int(boosters.get(booster, 0))
		var price: int = prices[booster]
		var button: Button = _shop_booster_buttons[booster]
		button.text = "%s  ·  %d Münzen  ·  x%d" % [titles[booster], price, count]
		button.disabled = wallet < price

func _set_shop_buttons_visible(is_visible: bool) -> void:
	for button in _shop_booster_buttons.values():
		button.visible = is_visible

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_active = true
		elif _touch_active:
			_touch_active = false
			var swipe: Vector2 = event.position - _touch_start
			if swipe.length() >= 55.0:
				var action: StringName
				if absf(swipe.x) > absf(swipe.y):
					action = &"right" if swipe.x > 0.0 else &"left"
				else:
					action = &"duck" if swipe.y > 0.0 else &"jump"
				swipe_action.emit(action)
				accept_event()

func _build_hud() -> void:
	_hud = GridContainer.new()
	_hud.name = "HUD"
	_hud.columns = 4
	_hud.anchor_left = 0.0
	_hud.anchor_right = 1.0
	_hud.offset_left = 24.0
	_hud.offset_right = -24.0
	_hud.offset_top = 18.0
	_hud.offset_bottom = 76.0
	_hud.add_theme_constant_override("h_separation", 18)
	_hud.add_theme_constant_override("v_separation", 8)
	add_child(_hud)

	_score_label = _make_hud_label("DISTANZ  000000")
	_coin_label = _make_hud_label("MÜNZEN  000")
	_best_label = _make_hud_label("BEST  000000")
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud.add_child(_score_label)
	_hud.add_child(_coin_label)
	_hud.add_child(_best_label)

	_pause_button = _make_button("PAUSE")
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_hud.add_child(_pause_button)
	_pause_button.visible = false

	_powerup_label = _make_hud_label("")
	_powerup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_powerup_label.anchor_left = 0.2
	_powerup_label.anchor_right = 0.8
	_powerup_label.anchor_top = 0.0
	_powerup_label.anchor_bottom = 0.0
	_powerup_label.offset_top = 76.0
	_powerup_label.offset_bottom = 108.0
	_powerup_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.3))
	add_child(_powerup_label)
	_powerup_label.visible = false

	_booster_row = HBoxContainer.new()
	_booster_row.name = "BoosterRow"
	_booster_row.anchor_left = 0.12
	_booster_row.anchor_right = 0.88
	_booster_row.anchor_top = 1.0
	_booster_row.anchor_bottom = 1.0
	_booster_row.offset_top = -66.0
	_booster_row.offset_bottom = -10.0
	_booster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_booster_row.add_theme_constant_override("separation", 8)
	add_child(_booster_row)

	_roll_button = _make_button("ROLL  ·  R")
	_roll_button.pressed.connect(func() -> void: swipe_action.emit(&"roll"))
	_booster_row.add_child(_roll_button)

	for booster in ["shield", "magnet", "turbo"]:
		var button := _make_button("")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_request_booster_use.bind(StringName(booster)))
		_booster_use_buttons[booster] = button
		_booster_row.add_child(button)
	_booster_row.visible = false
	_build_touch_controls()

func _build_touch_controls() -> void:
	_touch_controls = Control.new()
	_touch_controls.name = "TouchControls"
	_touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_controls)

	var move_buttons := HBoxContainer.new()
	move_buttons.anchor_left = 0.02
	move_buttons.anchor_top = 1.0
	move_buttons.anchor_bottom = 1.0
	move_buttons.offset_top = -146.0
	move_buttons.offset_bottom = -82.0
	move_buttons.add_theme_constant_override("separation", 8)
	_touch_controls.add_child(move_buttons)
	_add_touch_button(move_buttons, "<", &"left")
	_add_touch_button(move_buttons, ">", &"right")

	var action_buttons := HBoxContainer.new()
	action_buttons.anchor_left = 1.0
	action_buttons.anchor_right = 1.0
	action_buttons.anchor_top = 1.0
	action_buttons.anchor_bottom = 1.0
	action_buttons.offset_left = -182.0
	action_buttons.offset_right = -8.0
	action_buttons.offset_top = -146.0
	action_buttons.offset_bottom = -82.0
	action_buttons.add_theme_constant_override("separation", 8)
	_touch_controls.add_child(action_buttons)
	_add_touch_button(action_buttons, "SPRINGEN", &"jump")
	_add_touch_button(action_buttons, "RUTSCHEN", &"duck")
	_touch_controls.visible = false

func _add_touch_button(parent: Container, text: String, action: StringName) -> void:
	var button := _make_button(text)
	button.custom_minimum_size = Vector2(76.0, 60.0)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_request_movement.bind(action))
	parent.add_child(button)
	_touch_buttons.append(button)

func _request_movement(action: StringName) -> void:
	swipe_action.emit(action)

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "MenuOverlay"
	_overlay.color = Color(0.012, 0.018, 0.07, 0.9)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360.0, 0.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.035, 0.055, 0.15, 0.98)
	card_style.border_color = Color(0.08, 0.76, 0.95, 0.9)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.2, 0.93, 1.0))
	content.add_child(_title_label)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 15)
	content.add_child(_detail_label)

	_volume_row = HBoxContainer.new()
	var volume_label := Label.new()
	volume_label.text = "Lautstärke"
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_row.add_child(volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.custom_minimum_size.x = 115.0
	_volume_slider.value_changed.connect(func(value: float) -> void: volume_changed.emit(value))
	_volume_row.add_child(_volume_slider)
	content.add_child(_volume_row)

	_start_button = _make_button("LOS GEHT'S")
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	content.add_child(_start_button)

	_resume_button = _make_button("WEITERSPIELEN")
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	content.add_child(_resume_button)

	_restart_button = _make_button("NEU STARTEN")
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	content.add_child(_restart_button)

	_shop_button = _make_button("BOOSTER-SHOP")
	_shop_button.pressed.connect(func() -> void: shop_requested.emit())
	content.add_child(_shop_button)

	for booster in ["shield", "magnet", "turbo"]:
		var button := _make_button("")
		button.pressed.connect(_request_booster_buy.bind(StringName(booster)))
		_shop_booster_buttons[booster] = button
		content.add_child(button)
		button.visible = false

	_shop_back_button = _make_button("ZURÜCK")
	_shop_back_button.pressed.connect(func() -> void: shop_closed.emit())
	content.add_child(_shop_back_button)
	_shop_back_button.visible = false

func _request_booster_use(booster: StringName) -> void:
	booster_use.emit(booster)

func _request_booster_buy(booster: StringName) -> void:
	booster_buy.emit(booster)

func _build_touch_hint() -> void:
	var hint := Label.new()
	hint.text = "Tasten oder wischen: Spur · springen · rutschen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.04
	hint.anchor_right = 0.96
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -184.0
	hint.offset_bottom = -154.0
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.76, 0.9, 0.8))
	hint.visible = OS.has_feature("mobile")
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

func _apply_responsive_layout() -> void:
	var window_size := get_window().size
	var narrow := window_size.x < 760 or float(window_size.x) < float(window_size.y) * 0.75
	_hud.columns = 2 if narrow else 4
	_hud.offset_left = 12.0 if narrow else 24.0
	_hud.offset_right = -12.0 if narrow else -24.0
	_hud.offset_bottom = 116.0 if narrow else 76.0
	var label_size := 16 if narrow else 20
	for label in [_score_label, _coin_label, _best_label]:
		label.add_theme_font_size_override("font_size", label_size)
	_powerup_label.anchor_left = 0.04 if narrow else 0.2
	_powerup_label.anchor_right = 0.96 if narrow else 0.8
	_powerup_label.add_theme_font_size_override("font_size", 13 if narrow else 20)
	_pause_button.custom_minimum_size = Vector2(78.0 if narrow else 96.0, 44.0)
	_booster_row.anchor_left = 0.02 if narrow else 0.16
	_booster_row.anchor_right = 0.98 if narrow else 0.84
	_booster_row.add_theme_constant_override("separation", 4 if narrow else 8)
	_roll_button.custom_minimum_size.x = 66.0 if narrow else 100.0
	for button in _booster_use_buttons.values():
		button.custom_minimum_size.x = 72.0 if narrow else 120.0
	_touch_controls.visible = narrow or OS.has_feature("mobile")
	for button in _touch_buttons:
		button.custom_minimum_size = Vector2(58.0 if narrow else 76.0, 54.0 if narrow else 60.0)

func _make_hud_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.46, 0.91, 1.0))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.add_theme_font_size_override("font_size", 18)
	return button
