extends "res://tests/modal_visual_qa.gd"

func _run() -> void:
	game = root.get_node("Game")
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	game.animals.clear()
	game.coins = 12000
	app._show_screen("shop")
	await create_timer(0.4).timeout
	var shop: Control = app.shop_view
	check(shop.cards.size() == 16, "Ten egg definitions, four daily chickens, two items")
	for texture in [shop.HEADER, shop.CARD, shop.FEED]:
		var art: Image = texture.get_image()
		check(art.get_pixel(0, 0).a == 0.0 and art.get_used_rect().has_area(), "Real transparent asset with visible content")
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.3).timeout
		for category in ["eggs", "chickens", "items"]:
			await _click(shop.get_node("Tabs/" + category.capitalize()), true)
			check(shop.selected_tab == category, "Tab selects " + category)
			check(shop.scroll.get_global_rect().end.y < app.get_node("UI/BottomMenu/BottomNav").get_global_rect().position.y, "Products stop above bottom navigation")
			check(shop.list.size.x <= shop.scroll.size.x, "No horizontal overflow")
			for card in shop.cards:
				check(card.panel.visible == (card.kind == category and card.get("daily_active", true)), "Filter shows only daily stock in category")
				if not card.panel.visible: continue
				check(card.buy.size.y >= 88 and card.buy.size.x >= 180, "Finger-sized buy target")
				check(card.panel.size.x >= 280 and card.panel.size.x < shop.list.size.x * 0.6, "Two equally readable columns")
				for label in [card.name, card.description, card.price_label, card.destination]:
					var font: Font = label.get_theme_font("font")
					var text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
					check((text_size.x <= label.size.x or (label == card.name and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS)) and label.get_line_height() <= label.size.y, "Text fits: " + label.text)
				check(Rect2(Vector2.ZERO, card.panel.size).encloses(card.buy.get_rect()), "Buy inside frame")
				check(card.name.position.y >= 44, "Title inset clears the painted wooden rim")
			await _capture("shop_redesign_" + category)
		shop.select_tab("eggs")
		await process_frame
		var last_level: int = shop.daily_offers.eggs.back()
		var last: Control = shop.list.get_node("EggLv%d" % last_level)
		var saved_gold: float = game.coins
		game.coins = 0
		app._refresh_all()
		shop.scroll.ensure_control_visible(last)
		await create_timer(0.2).timeout
		check(shop.scroll.get_global_rect().encloses(last.get_global_rect()), "Last egg reachable by scrolling")
		check(last.get_node("Buy").disabled and last.get_node("Buy").text == "NEED GOLD", "Insufficient Gold state is explicit")
		await _capture("shop_redesign_last_egg")
		await _click(last.get_node("DropRate"), true)
		check(app.egg_rate_dialog.visible and app.egg_rate_dialog.egg_level == last_level, "Last daily egg opens correct odds")
		shop.select_tab("items")
		check(shop.selected_tab == "eggs", "Modal prevents category changes")
		await _click(app.egg_rate_dialog.done_button, true)
		game.coins = saved_gold
		app._refresh_all()
		shop.select_tab("eggs")
		await process_frame
		await _swipe_products(shop)
	# Map-specific starter purchase must match the illustrated creature, not a random fallback.
	for planet in app.MAP_ORDER:
		app._switch_planet(planet)
		game.animals.clear()
		game.coins = 2000
		app._refresh_all()
		check(shop.get_node("Context").text.contains("BUYING FOR: " + planet.to_upper()), "Persistent shop banner names purchase planet " + planet)
		check(shop.get_node("Header/Title").text == planet.to_upper() + " SHOP", "Shop heading uses active planet")
		for card in shop.cards:
			check(card.destination.text == ("SHARED REWARDS" if card.kind == "items" else "TO %s FARM" % planet.to_upper()), "Every product states correct destination or shared reward")
		shop.select_tab("chickens")
		await create_timer(0.2).timeout
		for species in game.species_ids_for_map():
			var card: Control = shop.list.get_node("Daily_" + species + "_1")
			shop.scroll.ensure_control_visible(card)
			await create_timer(0.2).timeout
			await _click(card.get_node("Buy"), true)
			check(not game.animals.is_empty() and game.animals.back().species_id == species and game.animals.back().tier == 1, "Starter purchase matches art on " + planet)
		check(game.animals.size() == 2 and game.coins == 1000, "Two starter taps charged once each")
		check(game.animals.all(func(animal): return game.animal_belongs_to_map(animal, planet)), "Starters delivered to named planet")
		check(shop.feedback.text.contains(app.PLANETS[planet].name), "Chicken confirmation names destination")
		shop.select_tab("eggs")
		await create_timer(0.2).timeout
		await _click(shop.list.get_node("EggLv1/Buy"), true)
		check(game.animal_belongs_to_map(game.animals.back(), planet), "Egg hatches on named planet")
		check(shop.feedback.text.contains(planet.to_upper() + " FARM"), "Egg confirmation names destination")
		await _capture("shop_destination_" + planet)
	# A stale rendered destination cannot silently charge for a different planet.
	var shown_planet: String = game.current_planet
	var before_stale_coins: float = game.coins
	var before_stale_count: int = game.animals.size()
	game.current_planet = "earth" if shown_planet != "earth" else "ice"
	shop.list.get_node("EggLv1/Buy").pressed.emit()
	check(game.coins == before_stale_coins and game.animals.size() == before_stale_count, "Stale map purchase rejected without charge")
	check(shop.feedback.text.contains("Planet changed"), "Stale map asks player to review new destination")
	game.current_planet = shown_planet
	app._refresh_all()
	# Real items; values and prices must remain unchanged by a UI redesign.
	shop.select_tab("items")
	game.coins = 1000
	app._refresh_all()
	var gems_before: int = game.gems
	await _click(shop.list.get_node("Gems/Buy"), true)
	check(game.coins == 200 and game.gems == gems_before + game.GEM_POUCH_AMOUNT, "Gem pouch transaction unchanged")
	await _click(shop.list.get_node("Food/Buy"), true)
	check(game.coins == 160, "Food net Gold change remains -40")
	check(shop.feedback.text.contains("Feed used!"), "Purchase has visible feedback in Shop")
	# Capacity disables only creature purchases, not ordinary items.
	game.animals.clear()
	for index in range(game.MAX_ANIMALS):
		game.create_animal(game.species_ids_for_map()[0], 1)
	game.coins = 2000000
	app._refresh_all()
	for card in shop.cards:
		check(card.buy.disabled == (card.kind != "items"), "Capacity disables eggs and starters only")
	shop.select_tab("eggs")
	await create_timer(0.2).timeout
	await _capture("shop_redesign_full")
	var file := FileAccess.open("res://qa/shop-redesign-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "3 screen sizes, 3 categories, 5 planets, purchases, generated assets"}, "\t"))
	file.close()
	if failures.is_empty(): print("SHOP_REDESIGN_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)

func _swipe_products(shop: Control) -> void:
	# ScrollContainer applies scroll offsets in its deferred layout pass.
	await process_frame
	await process_frame
	var before: int = game.coins
	var count: int = game.animals.size()
	var first_buy: Button = shop.list.get_node("EggLv1/Buy")
	var point := first_buy.get_global_rect().get_center()
	check(shop.scroll.get_global_rect().has_point(point), "Swipe starts on a visible product at %s" % point)
	# Use the mouse events produced by touch emulation on this desktop build.
	# ScrollContainer's desktop touch-emulation path consumes these events.
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = point
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	for step in range(8):
		point.y -= 24
		var drag := InputEventMouseMotion.new()
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		drag.position = point
		drag.relative = Vector2(0, -24)
		root.push_input(drag, true)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = point
	up.pressed = false
	root.push_input(up, true)
	await create_timer(0.25).timeout
	check(shop.scroll.scroll_vertical > 50, "Touch swipe scrolls the product grid")
	check(game.coins == before and game.animals.size() == count, "Dragging across BUY does not purchase")
