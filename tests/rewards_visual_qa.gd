extends "res://tests/modal_visual_qa.gd"

func _run() -> void:
	game = root.get_node("Game")
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	var hub: CanvasLayer = app.rewards_hub
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		game.reward_progress.restore({})
		app._show_screen("farm")
		await create_timer(0.3).timeout
		hub.refresh()
		check(hub.daily_button.size.y >= 88 and hub.ad_button.size.y >= 88, "Shortcuts have finger-sized targets")
		check(hub.daily_button.text == "" and hub.daily_button.get_node("Caption").text == "DAILY CHECK-IN", "Check-in shortcut uses English caption, no button text")
		check(hub.daily_button.get_node("Caption").get_theme_font_size("font_size") <= 16, "Long English check-in caption is compact enough for its button")
		var caption_color: Color = hub.daily_button.get_node("Caption").get_theme_color("font_color")
		check(caption_color.get_luminance() > 0.8 and hub.daily_button.get_node("Caption").get_theme_constant("outline_size") >= 4, "Shortcut caption uses bright text with strong contrast outline")
		var delivery: Control = app.get_node("UI/FarmScreen/DeliveryStatus")
		var notification_ticker: Control = app.get_node("UI/FarmScreen/NotificationTicker")
		for shortcut in [hub.daily_button, hub.ad_button]:
			check(shortcut.get_theme_stylebox("normal") is StyleBoxEmpty, "Shortcut has no rectangular button background")
			check(shortcut.get_node("Caption").position.y >= shortcut.get_node("Icon").get_rect().end.y, "Caption sits below icon")
			check(shortcut.get_global_rect().position.y >= delivery.get_global_rect().end.y, "Shortcut follows UFO progress bar")
			check(not shortcut.get_global_rect().intersects(notification_ticker.get_global_rect()), "Scrolling notice does not cover shortcut")
		check(hub.daily_button.get_global_rect().position.x < 12.0 and absf(hub.daily_button.position.x - hub.ad_button.position.x) < 1.0, "Reward shortcuts form a left vertical rail")
		check(not hub.daily_button.get_global_rect().intersects(app.map_switch_button.get_global_rect()) and not hub.ad_button.get_global_rect().intersects(app.map_switch_button.get_global_rect()), "Shortcuts do not overlap map button")
		await _capture("rewards_farm_icons")
		await _click(hub.daily_button, true)
		check(hub.visible and hub.calendar.visible and hub.day_cards.size() == 7, "Calendar icon opens seven weekdays")
		check(hub.heading.text == "DAILY GOODIES!" and hub.mascot.texture != null, "Playful banner and real chicken mascot present")
		check(hub.panel.scale.is_equal_approx(Vector2.ONE), "Entrance settles at intended size")
		_check_panel(hub)
		var planet: String = app.current_planet
		app._cycle_farm_map()
		app._show_screen("shop")
		check(app.current_planet == planet and app.current_screen == "farm", "Rewards modal blocks map/tab changes")
		await _capture("daily_rewards")
		var before: Dictionary = {"gold": game.coins, "gems": game.gems}
		var weekday: int = game.reward_progress.view(int(Time.get_unix_time_from_system())).index
		await _click(hub.claim_button, true)
		check(game.coins == before.gold + hub.RULES.WEEK[weekday].gold and game.gems == before.gems + hub.RULES.WEEK[weekday].gems, "Claim button grants exact displayed reward")
		check(hub.claim_button.disabled and hub.status.text.begins_with("RECEIVED"), "Claim gives confirmation and cannot repeat")
		check(hub.day_cards[weekday].badge.text == "GOT IT!" and hub.mascot_caption.text == "NICE HAUL!", "Claimed sticker and mascot celebrate")
		check(hub.confetti.age < 1.4, "Successful claim triggers confetti")
		await _capture("daily_claimed")
		await _click(hub.close_button, true)
		check(hub.confetti.age >= 1.4 and hub.panel.scale == Vector2.ONE, "Close clears animation without stale particles")
		await _click(hub.ad_button, true)
		check(hub.visible and hub.ad_details.visible and not hub.calendar.visible, "Ad icon opens separate gift screen")
		check(hub.watch_button.disabled and hub.status.text.contains("Energy is full"), "Full Energy blocks a wasteful ad view")
		_check_panel(hub)
		await _capture("ad_gifts")
		await _click(hub.close_button, true)
		check(not app._has_blocking_modal(), "Close restores normal interaction after guard")
		app._show_screen("battle")
		check(not hub.daily_button.is_visible_in_tree() and not hub.ad_button.is_visible_in_tree(), "Farm shortcuts do not leak to other screens")
	var file := FileAccess.open("res://qa/rewards-visual-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "3 phone sizes, real GUI input, calendar claim and unavailable-ad modal"}, "\t"))
	file.close()
	if failures.is_empty(): print("REWARDS_VISUAL_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)

func _check_panel(hub: CanvasLayer) -> void:
	check(app.get_viewport_rect().encloses(hub.panel.get_global_rect()), "Reward modal fits screen")
	if hub.calendar.visible:
		for card in hub.day_cards:
			check(hub.panel.get_global_rect().encloses(card.panel.get_global_rect()), "Reward sticker stays inside frame")
			check(card.badge.get_line_count() * card.badge.get_line_height() <= card.badge.size.y + 1, "Sticker status is readable")
		check(hub.panel.get_global_rect().encloses(hub.mascot_card.get_global_rect()), "Mascot sticker fits frame")
	for label in [hub.heading, hub.description, hub.status, hub.ad_details]:
		if label.is_visible_in_tree():
			check(label.get_line_count() * label.get_line_height() <= label.size.y + 1, "Reward text fits " + label.text)
	for button in [hub.claim_button, hub.watch_button, hub.close_button]:
		if button.is_visible_in_tree(): check(hub.panel.get_global_rect().encloses(button.get_global_rect()) and button.size.y >= 88, "Modal action inside frame and touch-sized")
