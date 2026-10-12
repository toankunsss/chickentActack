extends "res://tests/modal_visual_qa.gd"
const RULES = preload("res://scripts/config/PlayProgress.gd")
const OFFLINE = preload("res://scripts/battle/OfflineOpponent.gd")

func _run() -> void:
	var progress := RULES.new()
	var now := 1791000000
	progress.restore({})
	check(progress.refresh_energy(now) == 240, "Initial energy full")
	check(progress.spend(now) and progress.state.energy == 235, "Battle costs five")
	check(progress.refresh_energy(now + 299) == 235, "Elapsed time gives no Energy")
	check(progress.refresh_energy(now + 999999) == 235, "Offline time gives no Energy")
	check(progress.grant_energy(20) == 5 and progress.state.energy == 240, "Verified refill respects Energy cap")
	check(progress.grant_energy(20) == 0 and progress.state.energy == 240, "Full Energy cannot overfill")
	check(progress.advance_shop(now), "First daily roll")
	var offers: Dictionary = progress.offers("earth", ["ga_ta_vang", "ga_ac_den"])
	check(not progress.advance_shop(now + 1) and progress.offers("earth", ["ga_ta_vang", "ga_ac_den"]) == offers, "Same day stable")
	var clone := RULES.new()
	clone.restore(JSON.parse_string(JSON.stringify(progress.state)))
	check(clone.offers("earth", ["ga_ta_vang", "ga_ac_den"]) == offers, "Persisted daily offers survive JSON restart")
	check(not clone.advance_shop(now - 86400), "Backward clock cannot reroll shop")
	check(clone.advance_shop(now + 86400) and clone.state.shop_day > progress.state.shop_day, "Next day advances once")
	check(offers.eggs.size() == 4 and offers.eggs.has(1) and offers.chickens.size() == 4, "Daily stock has four eggs and four chickens including basics")
	game = root.get_node("Game")
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	game.coins = 1000000
	game.animals.clear()
	game.battle_team.clear()
	var daily: Dictionary = game.daily_shop()
	var before_coins: float = game.coins
	check(not game.purchase_daily_chicken("bad:10", daily.day).ok and game.coins == before_coins, "Forged stock cannot buy")
	check(not game.purchase_daily_egg(1, daily.day - 1).ok and game.coins == before_coins, "Stale day cannot charge")
	var offer: Dictionary = daily.chickens[1]
	var purchase: Dictionary = game.purchase_daily_chicken(offer.id, daily.day)
	check(purchase.ok and purchase.animal.tier == offer.tier and game.coins == before_coins - offer.price, "Daily chicken gives shown tier at shown price")
	check(game.map_for_animal(purchase.animal) == game.current_planet if game.has_method("map_for_animal") else game.species_ids_for_map().has(purchase.animal.species_id), "Bought chicken belongs to current planet")
	game._save_blocked = true
	var old_roster: Array = game.animals.duplicate(true)
	before_coins = game.coins
	check(not game.purchase_daily_chicken(offer.id, daily.day).ok and game.coins == before_coins and game.animals == old_roster, "Failed save rolls purchase back")
	var energy_before: int = game.energy_balance()
	check(not game.spend_battle_energy().ok and game.energy_balance() == energy_before, "Failed energy save rolls debit back")
	game._save_blocked = false
	var saved_progress: Dictionary = game.play_progress.state.duplicate(true)
	check(game.save_game(), "Save includes play progression")
	game.play_progress.restore({})
	var loaded: bool = game.load_game()
	check(loaded and game.play_progress.state == saved_progress, "Energy and daily seed reload from game save")
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		app._show_screen("farm")
		await create_timer(0.3).timeout
		var gear: Control = app.settings_button.get_node("GearIcon")
		check(gear.get_global_rect().get_center().distance_to(app.settings_button.get_global_rect().get_center()) < 0.5, "Gear geometrically centered")
		var delivery: Control = app.get_node("UI/FarmScreen/DeliveryStatus")
		var delivery_panel: Control = delivery.get_node("Backgound")
		var delivery_bar: ProgressBar = delivery.get_node("DeliveryProgressBar")
		var delivery_icon: Control = delivery.get_node("DeliveryIcon")
		var delivery_label: Control = delivery.get_node("DeliveryStatusLabel")
		var viewport_rect := app.get_viewport_rect()
		var upgrade_button: Control = app.get_node("UI/FarmScreen/OpenUpgradeShop")
		var map_switch: Control = app.map_switch_button
		var notification_ticker: Control = app.get_node("UI/FarmScreen/NotificationTicker")
		check(viewport_rect.encloses(app.settings_button.get_global_rect()), "Settings button stays inside viewport")
		check(viewport_rect.encloses(delivery_panel.get_global_rect()), "UFO panel stays inside viewport")
		check(not app.settings_button.get_global_rect().intersects(delivery_panel.get_global_rect()), "Settings button does not overlap UFO panel")
		check(delivery_panel.get_global_rect().encloses(delivery_icon.get_global_rect()), "UFO icon stays inside its panel")
		check(delivery_panel.get_global_rect().encloses(delivery_label.get_global_rect()), "UFO timer stays inside its panel")
		check(delivery_panel.get_global_rect().encloses(delivery_bar.get_global_rect()), "UFO progress track stays inside its panel")
		check(viewport_rect.encloses(map_switch.get_global_rect()), "Map switch stays inside viewport")
		check(viewport_rect.encloses(upgrade_button.get_global_rect()), "Upgrade button stays inside viewport")
		check(absf(upgrade_button.get_global_rect().get_center().x - viewport_rect.get_center().x) < 1.0, "Upgrade button is horizontally centered")
		for shortcut in [app.rewards_hub.daily_button, app.rewards_hub.ad_button]:
			check(shortcut.get_global_rect().position.y >= delivery.get_global_rect().end.y, "Reward shortcut sits below UFO meter")
			check(not shortcut.get_global_rect().intersects(upgrade_button.get_global_rect()), "Reward shortcut separate from upgrade")
			check(not shortcut.get_global_rect().intersects(map_switch.get_global_rect()), "Reward shortcut separate from map switch")
			check(not shortcut.get_global_rect().intersects(notification_ticker.get_global_rect()), "Notification ticker does not cover reward shortcut")
			check(viewport_rect.encloses(shortcut.get_global_rect()), "Shortcut inside viewport")
		check(app.rewards_hub.daily_button.get_global_rect().position.x < 12.0, "Reward shortcuts use the left rail")
		check(absf(app.rewards_hub.daily_button.position.x - app.rewards_hub.ad_button.position.x) < 1.0, "Reward shortcuts align vertically")
		check(absf(app.rewards_hub.daily_button.get_rect().end.y - app.rewards_hub.ad_button.position.y) < 1.0, "Reward shortcuts form one vertical stack")
		check(delivery_bar.size.x > delivery.size.x * 0.6 and delivery_bar.size.y >= 28.0, "UFO meter has a balanced readable track")
		await _capture("farm_footer_shortcuts")
		await _click(app.rewards_hub.daily_button, true)
		check(app.rewards_hub.visible, "Relocated daily shortcut opens modal")
		await _click(app.rewards_hub.close_button, true)
		app._show_screen("shop")
		await create_timer(0.3).timeout
		var shop: Control = app.shop_view
		shop.select_tab("eggs")
		check(shop.cards.filter(func(c): return c.panel.visible).size() == 4, "Four daily eggs visible")
		await _capture("daily_shop_eggs")
		shop.select_tab("chickens")
		await create_timer(0.1).timeout
		check(shop.cards.filter(func(c): return c.panel.visible).size() == 4, "Four daily chicken offers visible")
		await _capture("daily_shop_chickens")
		app._show_screen("battle")
		await create_timer(0.2).timeout
		await _capture("battle_polished_lobby")
	game.animals.clear()
	for i in 3:
		var animal: Dictionary = game.create_animal(game.species_ids_for_map()[i % 2], 2, {"force_normal": true}).animal
		game.battle_team.append(animal.id)
	app._show_screen("battle_match")
	var arena: Control = app.battle_arena_screen
	arena.set_process(false)
	var fixture := OFFLINE.build(game, 1, 990)
	arena.start_snapshot(fixture)
	energy_before = game.energy_balance()
	while arena.preparing:
		arena._process(0.016)
		await process_frame
	check(game.energy_balance() == energy_before, "Loading is free")
	arena._process(4.0)
	check(game.energy_balance() == energy_before, "Countdown is free")
	arena._process(0.016)
	check(game.energy_balance() == energy_before - 5, "Combat starts with one debit")
	arena.start_snapshot(fixture)
	check(game.energy_balance() == energy_before - 5, "Duplicate start cannot debit twice")
	var unit: Dictionary = arena.simulation.units[0]
	var view: Dictionary = arena.views[unit.uid]
	var origin: Vector2 = view.root.position
	unit.column = 1 if unit.column == 0 else 0
	arena.render_delta = 1.0 / 60.0
	arena._refresh()
	var destination: Vector2 = arena._cell_center(Vector2(unit.column, unit.row)) - Vector2(65, view.root.size.y * 0.5)
	check(view.root.position.distance_to(origin) > 0 and view.root.position.distance_to(destination) > 1, "Visual movement interpolates, does not snap")
	for i in 90: arena._refresh()
	check(view.root.position.distance_to(destination) < 1, "Visual movement settles on logical cell")
	var hp_before: float = view.hp.value
	unit.hp -= 10
	arena._refresh()
	check(view.hp.value < hp_before and view.hp.value > unit.hp and view.damage.visible, "HP eases with damage feedback")
	var frozen: Vector2 = view.root.position
	arena.paused = true
	arena._process(0.5)
	check(view.root.position == frozen, "Presentation pauses with combat")
	arena.paused = false
	for i in 150:
		arena._process(1.0 / 60.0)
		await process_frame
	await _capture("battle_polished_combat")
	arena.abandon_match()
	game.play_progress.state.energy = 0
	game.play_progress.state.energy_at = int(Time.get_unix_time_from_system())
	arena.start_snapshot(fixture)
	check(not arena.running and arena.message_label.text.contains("Energy"), "Empty energy blocks rematch")
	var file := FileAccess.open("res://qa/daily-battle-polish-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	if failures.is_empty(): print("DAILY_BATTLE_POLISH_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)
