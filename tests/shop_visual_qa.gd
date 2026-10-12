extends "res://tests/modal_visual_qa.gd"
const DROPS = preload("res://scripts/config/EggDropRateConfig.gd")
const SHOP = preload("res://scripts/config/EggShopConfig.gd")

func _run() -> void:
	game = root.get_node("Game")
	# Shop/odds pointer coverage is independent from onboarding pointer capture.
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	game.animals.clear()
	game.unopened_eggs.clear()
	_test_shop_rules()
	game.animals.clear()
	game.coins = 2000000
	app._switch_planet("earth")
	app._show_screen("shop")
	await create_timer(0.4).timeout
	var popup: Control = app.egg_rate_dialog
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.2).timeout
		for level in range(1, 11):
			app._show_egg_drop_rates(level)
			await process_frame
			check(popup.visible and popup.egg_level == level, "Opens correct egg odds")
			check(popup.egg_image.texture == game.egg_texture(level), "Actual egg artwork")
			check(popup.title.get_theme_font("font") == app.FONT_BALOO_EXTRA_BOLD, "Shared chunky modal title font")
			check(popup.rows.size() == 10, "All ten tier rows visible")
			check(Rect2(Vector2.ZERO, app.size).encloses(popup.panel.get_global_rect()), "Frame inside viewport")
			var total := 0.0
			for index in range(10):
				var row: Dictionary = popup.rows[index]
				var chance: float = DROPS.rates(level).get(index + 1, 0.0)
				total += chance
				check(row.chance.text == "%.0f%%" % chance and row.bar.value == chance, "Tier %d exact probability" % (index + 1))
				check(row.chance.get_rect().end.x <= row.card.size.x and row.chance.get_line_height() <= row.chance.size.y, "Rate text fits card")
			check(is_equal_approx(total, 100.0), "Odds sum to 100%")
			var wallet: int = game.coins
			var roster: Array = game.animals.duplicate(true)
			app._buy_shop_egg(level)
			check(game.coins == wallet and game.animals == roster, "No purchase behind odds modal")
			_blocked_navigation()
			if level in [1, 10]:
				await _capture("shop_odds_lv%d" % level)
				await _pointer_shield()
			await _click(popup.close_button if level % 2 else popup.done_button, level % 2 == 0)
			check(not popup.visible, "Close works with mouse and touch")
			check(game.coins == wallet and game.animals == roster, "Read-only view preserves roster and wallet")
	# Verify map context is refreshed, never carried over from the last panel.
	for planet in app.MAP_ORDER:
		app._switch_planet(planet)
		app._show_egg_drop_rates(5)
		check(popup.planet_label.text == "%s chickens only" % app.PLANETS[planet].name, "Current planet label: " + planet)
		popup.close()
		await create_timer(0.4).timeout
	# Exercise a real shop card's open and buy controls, not just the methods.
	app._show_screen("shop")
	game.animals.clear()
	game.coins = SHOP.price(1)
	app._refresh_all()
	var list: Control = app.shop_view.list
	var card: Control = list.get_node("EggLv1")
	var scroll: ScrollContainer = app.shop_view.scroll
	scroll.ensure_control_visible(card)
	await create_timer(0.3).timeout
	await _click(_button(card, "DROP RATE"), true)
	check(popup.visible and popup.egg_level == 1, "Shop card opens odds by touch")
	await _click(popup.done_button, true)
	var buy: Button
	for child in card.get_children():
		if child is Button and child.has_meta("egg_price"):
			buy = child
	await _click(buy, true)
	check(game.coins == 0 and game.animals.size() == 1, "One touch buys exactly one egg")
	check(game.animals[0].tier == 1 and game.animal_belongs_to_map(game.animals[0]), "Shop hatches Tier 1 on current planet")
	check(buy.disabled, "Unaffordable purchase disabled after refresh")
	var saved: Dictionary = game.SaveStore.read_snapshot(game.SAVE_PATH, game._is_valid_save)
	check(saved.get("coins", -1) == 0 and saved.get("animals", []).size() == 1, "Purchased chicken persisted")
	var file := FileAccess.open("res://qa/shop-visual-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "10 egg levels x 3 sizes, 5 planet purchase rules, mouse/touch"}, "\t"))
	file.close()
	if failures.is_empty():
		print("SHOP_VISUAL_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)

func _test_shop_rules() -> void:
	check(DROPS.is_valid(), "Valid drop table")
	for planet in app.MAP_ORDER:
		game.current_planet = planet
		for level in range(1, 11):
			game.animals.clear()
			game.coins = SHOP.price(level) - 1
			var result: Dictionary = game.hatch_shop_egg(level)
			check(not result.ok and result.reason == "coins" and game.animals.is_empty(), "Insufficient Gold rejects egg")
			check(game.coins == SHOP.price(level) - 1, "Rejected purchase has no charge")
			game.coins = SHOP.price(level)
			result = game.hatch_shop_egg(level)
			check(result.ok and game.coins == 0 and game.animals.size() == 1, "Exact-price purchase")
			check(game.animal_belongs_to_map(result.animal, planet) and DROPS.rates(level).has(result.chicken_tier), "Hatch uses allowed planet and tier")
		# Full farm rejects without spending; other planets' creatures don't count.
		game.animals.clear()
		for index in range(game.MAX_ANIMALS):
			game.create_animal(game.species_ids_for_map()[0], 1)
		game.coins = 1000000
		var rejected: Dictionary = game.hatch_shop_egg(1)
		check(not rejected.ok and rejected.reason == "farm_full", "Full planet rejects purchase")
		check(game.coins == 1000000 and game.animals.size() == game.MAX_ANIMALS, "Full farm preserves resources")
	game.animals.clear()
	game.current_planet = "earth"
	for index in range(game.MAX_ANIMALS):
		game.create_animal("ga_ta_vang", 1)
	game.current_planet = "ice"
	check(game.hatch_shop_egg(1).ok, "Full Earth does not block Ice purchase")
	# Deterministic boundary checks prove rendered bins match the sampler.
	for level in range(1, 11):
		var cursor := 0.0
		for tier in range(1, level + 1):
			var weight: float = DROPS.rates(level)[tier]
			check(DROPS.roll(level, cursor) == tier and DROPS.roll(level, cursor + weight - 0.001) == tier, "Sampler boundaries match displayed bin")
			cursor += weight
