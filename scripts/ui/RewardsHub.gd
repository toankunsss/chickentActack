extends CanvasLayer
## Farm shortcuts and a modal shared by weekly check-in / voluntary ad gifts.
signal wallet_changed
signal closed
const RULES = preload("res://scripts/rewards/RewardProgress.gd")
const ADS = preload("res://scripts/rewards/RewardedAdService.gd")
const SKIN = preload("res://scripts/battle/BattleUI.gd")
const FONT = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf")
const COIN = preload("res://assets/icons/coin_icon_128px.png")
const GEM = preload("res://assets/icons/gem_icon_128px.png")
var ad_service: Node
var daily_button: Button
var ad_button: Button
var overlay: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var heading: Label
var description: Label
var calendar: GridContainer
var day_cards: Array[Dictionary] = []
var ad_details: Label
var status: Label
var claim_button: Button
var watch_button: Button
var close_button: Button
var mode := "daily"
var can_open: Callable
var notice := ""
var notice_until := 0
var refresh_elapsed := 0.0
var title_band: PanelContainer
var mascot_card: PanelContainer
var mascot: TextureRect
var mascot_caption: Label
var confetti: Control
var entrance: Tween
var reward_bounce: Tween
var playful_elapsed := 0.0
var animated_day := -1

func _ready() -> void:
	layer = 105
	ad_service = ADS.new()
	add_child(ad_service)
	ad_service.changed.connect(refresh)
	ad_service.finished.connect(_result)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.10, 0.07, 0.13, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	panel = PanelContainer.new()
	var frame := _box(Color("fff3d6"), Color("ac6030"), 5)
	frame.border_width_bottom = 12
	frame.set_corner_radius_all(30)
	frame.shadow_color = Color(0.15, 0.08, 0.04, 0.35)
	frame.shadow_size = 12
	panel.add_theme_stylebox_override("panel", frame)
	overlay.add_child(panel)
	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margins.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margins)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margins.add_child(content)
	title_band = PanelContainer.new()
	var ribbon := _box(Color("f4b64b"), Color("b57430"), 3)
	ribbon.border_width_bottom = 7
	ribbon.border_width_top = 3
	title_band.add_theme_stylebox_override("panel", ribbon)
	content.add_child(title_band)
	heading = _label(title_band, "DAILY GOODIES!", 46)
	heading.add_theme_font_override("font", FONT)
	heading.add_theme_color_override("font_color", Color("fffce4"))
	heading.add_theme_color_override("font_outline_color", Color("774322"))
	heading.add_theme_constant_override("outline_size", 5)
	heading.add_theme_constant_override("shadow_offset_y", 3)
	heading.add_theme_color_override("font_shadow_color", Color("a76531"))
	description = _label(content, "", 22)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 56
	calendar = GridContainer.new()
	calendar.columns = 4
	calendar.add_theme_constant_override("h_separation", 12)
	calendar.add_theme_constant_override("v_separation", 12)
	content.add_child(calendar)
	for index in 7:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 194)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		calendar.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		card.add_child(stack)
		var day_label := _label(stack, RULES.DAYS[index], 23)
		day_label.add_theme_font_override("font", FONT)
		var icon := TextureRect.new()
		icon.texture = COIN if RULES.WEEK[index].gold > 0 else GEM
		icon.custom_minimum_size = Vector2(0, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)
		var amount := _label(stack, str(RULES.WEEK[index].gold if RULES.WEEK[index].gold > 0 else RULES.WEEK[index].gems), 30)
		amount.add_theme_font_override("font", FONT)
		_label(stack, "GOLD" if RULES.WEEK[index].gold > 0 else "GEMS", 16)
		var badge := _label(stack, "", 18)
		day_cards.append({"panel": card, "badge": badge, "icon": icon})
	# Fill the eighth sticker slot with an existing game chicken, not another
	# reward: the calendar still has exactly seven claimable days.
	mascot_card = PanelContainer.new()
	mascot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mascot_card.add_theme_stylebox_override("panel", _box(Color("ffedb3"), Color("dcbf78"), 1))
	calendar.add_child(mascot_card)
	var mascot_stack := VBoxContainer.new()
	mascot_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	mascot_card.add_child(mascot_stack)
	mascot = TextureRect.new()
	mascot.texture = Game.creature_texture({"species_id": Game.SPECIES[0].id, "tier": 1})
	mascot.custom_minimum_size.y = 92
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascot_stack.add_child(mascot)
	mascot_caption = _label(mascot_stack, "HI, FARMER!", 18)
	_label(mascot_stack, "7 DAYS OF\nLITTLE GIFTS", 16)
	ad_details = _label(content, "", 27)
	ad_details.custom_minimum_size.y = 210
	status = _label(content, "", 22)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 80
	status.add_theme_color_override("font_color", Color("59703a"))
	claim_button = _button(content, "CLAIM", Color("8cd254"))
	claim_button.pressed.connect(func(): _result(Game.claim_daily_reward()))
	watch_button = _button(content, "WATCH AD", Color("ffcb67"))
	watch_button.pressed.connect(_watch)
	close_button = _button(content, "CLOSE", Color("e0c49b"))
	close_button.pressed.connect(func():
		if not ad_service.pending.is_empty() and not ad_service.pending.earned: return
		hide()
		_reset_motion()
		closed.emit())
	confetti = preload("res://scripts/ui/RewardConfetti.gd").new()
	panel.add_child(confetti)
	get_viewport().size_changed.connect(_layout)
	panel.resized.connect(_center)
	hide()
	_layout()

func attach_shortcuts(parent: Control) -> void:
	daily_button = _shortcut(parent, "DAILY CHECK-IN", preload("res://assets/ui/rewards/calendar.svg"))
	ad_button = _shortcut(parent, "AD REWARD", preload("res://assets/ui/rewards/video-gift.svg"))
	daily_button.pressed.connect(func(): open("daily"))
	ad_button.pressed.connect(func(): open("ads"))
	layout_shortcuts(140.0)
	refresh()

func set_language(language: String) -> void:
	if not is_instance_valid(daily_button) or not is_instance_valid(ad_button): return
	var captions := {
		"en": ["DAILY CHECK-IN", "AD REWARD"],
		"es": ["REGISTRO DIARIO", "PREMIO DE ANUNCIO"],
		"pt": ["CHECK-IN DIÁRIO", "PRÊMIO DE ANÚNCIO"],
		"fr": ["BONUS QUOTIDIEN", "BONUS PUBLICITÉ"],
		"de": ["TÄGLICHER BONUS", "WERBE-BONUS"],
		"ja": ["デイリーボーナス", "広告ボーナス"],
		"ko": ["일일 출석", "광고 보상"],
		"zh": ["每日签到", "广告奖励"],
	}
	var localized: Array = captions.get(language, captions.en)
	var daily_text: String = localized[0]
	var ad_text: String = localized[1]
	daily_button.tooltip_text = daily_text
	ad_button.tooltip_text = ad_text
	var daily_caption := daily_button.get_node("Caption") as Label
	var ad_caption := ad_button.get_node("Caption") as Label
	daily_caption.text = daily_text
	ad_caption.text = ad_text
	# English is wider; keep its outline inside the left-side touch target.
	daily_caption.add_theme_font_size_override("font_size", 15 if daily_text.length() >= 14 else 18)
	ad_caption.add_theme_font_size_override("font_size", 15 if ad_text.length() >= 14 else 18)

func layout_shortcuts(top: float) -> void:
	if not is_instance_valid(daily_button) or not is_instance_valid(ad_button): return
	# Keep the shortcuts in a vertical rail along the left edge. Start below the
	# notification ticker (ends at y=194) so its full-width message remains
	# unchanged and never covers either touch target.
	var rail_top := maxf(top, 198.0)
	daily_button.position = Vector2(8, rail_top)
	ad_button.position = Vector2(8, rail_top + daily_button.size.y)

func _shortcut(parent: Control, caption: String, texture: Texture2D) -> Button:
	var button := Button.new()
	button.size = Vector2(140, 96)
	button.custom_minimum_size = button.size
	button.z_index = 1000
	button.tooltip_text = caption
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, Color("ad7329"), 2))
	parent.add_child(button)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = texture
	icon.position = Vector2(43, 0)
	icon.size = Vector2(54, 54)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := _label(button, caption, 22)
	label.name = "Caption"
	label.position = Vector2(0, 66)
	label.size = Vector2(140, 28)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 19)
	# Bright lettering with a strong dark cartoon outline remains readable over
	# grass, foliage and wooden fences behind the transparent shortcut.
	label.add_theme_color_override("font_color", Color("fff4d4"))
	label.add_theme_color_override("font_outline_color", Color("4b2919"))
	label.add_theme_constant_override("outline_size", 4)
	return button

func open(category: String) -> void:
	if visible or (can_open.is_valid() and not can_open.call()): return
	Audio.play_sfx("open")
	mode = category
	notice = ""
	notice_until = 0
	show()
	refresh()
	_layout()
	close_button.grab_focus()
	_reset_motion()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	entrance = create_tween()
	entrance.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(panel, "scale", Vector2.ONE, 0.32)

func _layout() -> void:
	if not panel: return
	var viewport := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(660, viewport.x - 32), 0)
	_center()

func _center() -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5

func refresh() -> void:
	if not is_node_ready(): return
	var today: Dictionary = Game.reward_progress.view(int(Time.get_unix_time_from_system()))
	if not visible: return
	var daily := mode == "daily"
	heading.text = "DAILY GOODIES!" if daily else "AD GIFTS"
	description.text = "A little gift for your flock, every day!\nFree check-in · New day at 00:00 UTC+7" if daily else "Optional Energy refill. No forced ads.\nEnergy does not recover automatically."
	calendar.visible = daily
	ad_details.visible = not daily
	claim_button.visible = daily
	animated_day = int(today.index) if daily and not today.claimed else -1
	mascot_caption.text = "NICE HAUL!" if today.claimed else "HI, FARMER!"
	for index in 7:
		var claimed: bool = (int(today.mask) & (1 << index)) != 0
		var is_today: bool = index == today.index
		var fill := Color("d4ecae") if claimed else (Color("ffe39a") if is_today else (Color("e8f3e2") if index % 2 == 0 else Color("e7f1f5")))
		if index < today.index and not claimed: fill = Color("ede5d4")
		var sticker := _box(fill, Color("ce852d") if is_today else Color("adbe9e"), 4 if is_today else 2)
		sticker.border_width_bottom = 7 if is_today else 5
		day_cards[index].panel.add_theme_stylebox_override("panel", sticker)
		day_cards[index].badge.text = "GOT IT!" if claimed else ("TODAY!" if is_today else ("MISSED" if index < today.index else "SOON"))
		day_cards[index].badge.add_theme_stylebox_override("normal", _box(Color("9bcc63") if claimed else (Color("ffc14f") if is_today else fill.darkened(0.04)), Color.TRANSPARENT, 0))
	ad_details.text = "ENERGY AD\n+%d ENERGY\n\nAd #%d of the day: +%d GEMS\nCompleted today: %d / %d" % [RULES.AD_ENERGY, RULES.AD_LIMIT, RULES.AD_MILESTONE_GEMS, today.ads, RULES.AD_LIMIT]
	claim_button.text = "YAY! COLLECTED TODAY" if today.claimed else "GRAB " + RULES.reward_text(RULES.WEEK[today.index])
	claim_button.disabled = today.claimed or not today.clock_ok or not ad_service.pending.is_empty()
	var offer: Dictionary = Game.reward_progress.ad_offer("daily_double" if daily else "gift", int(Time.get_unix_time_from_system()))
	var energy_full := not daily and Game.energy_balance() >= Game.PlayProgress.ENERGY_CAP
	watch_button.text = "ENERGY FULL" if energy_full else ("AD: +" + RULES.reward_text(offer.reward) if offer.ok else ("DOUBLE TODAY'S REWARD" if daily else "WATCH AD · +%d ENERGY" % RULES.AD_ENERGY))
	var pending: bool = not ad_service.pending.is_empty()
	var retry: bool = pending and ad_service.pending.earned
	if retry: watch_button.text = "RETRY SAVING REWARD"
	watch_button.disabled = not retry and (energy_full or not offer.ok or not ad_service.available())
	close_button.disabled = pending and not retry
	var info := "Come back tomorrow. Missed days do not reset your week."
	if not today.clock_ok: info = "Device time moved backwards. Check your clock."
	elif pending: info = "Reward not saved yet. Tap RETRY." if retry else "Waiting for the ad to finish..."
	elif energy_full: info = "Energy is full. Spend Energy in Battle before watching another Energy ad."
	elif today.ads >= RULES.AD_LIMIT: info = "All %d Energy ads collected. More tomorrow!" % RULES.AD_LIMIT
	elif today.cooldown > 0: info = "Next ad gift in %d:%02d · %d / %d completed today" % [int(today.cooldown) / 60, int(today.cooldown) % 60, today.ads, RULES.AD_LIMIT]
	elif today.reset_in < 180: info = "A new day starts soon. Ad gifts return after 00:00 UTC+7."
	elif daily and not today.claimed: info = "Today's treat is ready!\nGold & Gems are shared across all your farms."
	elif daily and today.claimed and not ad_service.available(): info = "All yours! See you tomorrow, farmer.\nOptional ad bonus is unavailable right now."
	elif not ad_service.available(): info = "Ads are not available right now.\nDaily check-in is always free."
	elif offer.ok: info = "Watch to completion to earn the shown reward.\nUp to %d ads/day · %d-second break between ads." % [RULES.AD_LIMIT, RULES.AD_COOLDOWN]
	if notice_until > Time.get_ticks_msec(): info = notice
	status.text = info
	call_deferred("_layout")

func _watch() -> void:
	if not ad_service.pending.is_empty() and ad_service.pending.earned:
		ad_service.retry_save()
		return
	var result: Dictionary = ad_service.begin("daily_double" if mode == "daily" else "gift")
	if not result.ok: _result(result)

func _result(result: Dictionary) -> void:
	if result.ok:
		Audio.play_sfx("reward")
		notice = "RECEIVED: " + RULES.reward_text(result.reward)
		wallet_changed.emit()
		if mode == "daily": call_deferred("_celebrate")
	else:
		notice = {"claimed": "Already claimed. Come back tomorrow!", "save_failed": "Could not save. Nothing was added. Please retry.", "clock": "Check your device clock before claiming.", "cancelled": "Ad not completed. No reward or daily slot used.", "expired": "This offer expired. Please try again.", "unavailable": "No ad available. Please try again later.", "energy_full": "Energy is already full."}.get(result.get("reason", ""), "Reward is not available yet.")
	notice_until = Time.get_ticks_msec() + 5000
	refresh()

func _process(delta: float) -> void:
	if visible and mode == "daily":
		playful_elapsed += delta
		mascot.pivot_offset = mascot.size * 0.5
		mascot.rotation = sin(playful_elapsed * 2.8) * 0.065
		mascot.scale = Vector2(1.0 + sin(playful_elapsed * 3.2) * 0.025, 1.0 - sin(playful_elapsed * 3.2) * 0.025)
		if animated_day >= 0:
			var icon: Control = day_cards[animated_day].icon
			icon.pivot_offset = icon.size * 0.5
			icon.rotation = sin(playful_elapsed * 3.0) * 0.09
	refresh_elapsed += delta
	if refresh_elapsed >= 1.0:
		refresh_elapsed = 0.0
		refresh()

func _celebrate() -> void:
	if not visible or mode != "daily": return
	var index: int = Game.reward_progress.view(int(Time.get_unix_time_from_system())).index
	var icon: Control = day_cards[index].icon
	icon.pivot_offset = icon.size * 0.5
	icon.rotation = 0.0
	if reward_bounce and reward_bounce.is_valid(): reward_bounce.kill()
	reward_bounce = create_tween()
	reward_bounce.tween_property(icon, "scale", Vector2(1.18, 0.88), 0.12)
	reward_bounce.tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	confetti.burst(confetti.get_global_transform().affine_inverse() * icon.get_global_rect().get_center())

func _reset_motion() -> void:
	if entrance and entrance.is_valid(): entrance.kill()
	if reward_bounce and reward_bounce.is_valid(): reward_bounce.kill()
	panel.scale = Vector2.ONE
	playful_elapsed = 0.0
	for card in day_cards:
		card.icon.rotation = 0.0
		card.icon.scale = Vector2.ONE
	if confetti: confetti.clear()

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", SKIN.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("51321e"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 88
	SKIN.button(button, color)
	parent.add_child(button)
	return button

func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(18)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
