extends "res://tests/modal_visual_qa.gd"
const OFFLINE = preload("res://scripts/battle/OfflineOpponent.gd")
const SKILLS = preload("res://scripts/battle/BattleSkillCatalog.gd")

func _run() -> void:
	game = root.get_node("Game")
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	game.animals.clear()
	game.battle_team.clear()
	game.coins = 1000
	game.xp = 0
	for id in range(1, 101):
		var animal: Dictionary = game.create_animal(game.SPECIES[(id - 1) % 10].id, (id - 1) / 10 + 1, {"force_normal": true}).animal
		if id >= 41 and id <= 49: game.battle_team.append(animal.id)
	var roster_before: Array = game.animals.duplicate(true)
	var battle: Control = app.battle_screen
	var arena: Control = app.battle_arena_screen
	arena.set_process(false)
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		app._show_screen("battle")
		await create_timer(0.4).timeout
		check(battle.match_snapshot.mode == "offline" and battle.opponent_name.text.begins_with("AI"), "AI labelled honestly")
		check(battle.match_snapshot.players.size() == game.battle_team.size(), "Preview includes selected roster")
		for button in [battle.difficulty_button, battle.ready_button, battle.find_button, battle.picker_close, arena.speed_button, arena.leave_button, arena.rematch_button]:
			check(button.size.y >= 88, "Mobile button target >= 44px at 360 wide")
		check(battle.slots.get_global_rect().end.y <= battle.get_node("TeamBoard").get_global_rect().end.y, "Team grid stays inside panel")
		await _capture("battle_lobby")
		await _click(battle.difficulty_button)
		check(battle.difficulty_button.text == OFFLINE.MODES[battle.difficulty], "Difficulty cycles")
		# Keep combat captures/assertions reproducible after checking the real button.
		battle.difficulty = 1
		battle.difficulty_button.text = "NORMAL"
		battle.match_seed = 222
		battle._rebuild_opponent()
		battle._open_picker()
		await create_timer(0.2).timeout
		check(battle.picker_list.get_child_count() == 100, "All 100 skill cards available")
		for card in battle.picker_list.get_children():
			var animal: Dictionary = game.find_animal(card.animal_id)
			check(card.get_node("SkillName").text == SKILLS.for_id(game.creature_asset_id(animal)).name, "Skill matches real character")
			for path in ["Name", "SkillName", "SkillDescription"]:
				var label: Label = card.get_node(path)
				check(label.get_line_count() * label.get_line_height() <= label.size.y + 1, "Picker text fits %s / %s" % [card.animal_id, path])
		app._show_screen("shop")
		check(app.current_screen == "battle", "Picker blocks bottom navigation")
		await _capture("battle_skills")
		var scroll: ScrollContainer = battle.picker_list.get_parent()
		var before_team: Array = game.battle_team.duplicate()
		var point := scroll.get_global_rect().position + Vector2(70, 180)
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.button_mask = MOUSE_BUTTON_MASK_LEFT
		down.pressed = true
		down.position = point
		root.push_input(down, true)
		for step in 8:
			var drag := InputEventMouseMotion.new()
			drag.relative = Vector2(0, -18)
			point += drag.relative
			drag.position = point
			drag.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(drag, true)
			await process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.position = point
		root.push_input(up, true)
		await process_frame
		check(scroll.scroll_vertical > 0 and game.battle_team == before_team, "Swiping skill cards scrolls without selecting a chicken")
		await _click(battle.picker_close, true)
		await _click(battle.ready_button, true)
		check(app.current_screen == "battle_match" and arena.running and arena.countdown > 0.0, "Start enters countdown")
		_check_fullscreen_arena(arena)
		arena._process(0.5)
		check(arena.simulation.elapsed == 0.0, "No damage during countdown")
		await _prepare_arena(arena)
		var opening_hp: Array = arena.simulation.units.map(func(unit): return unit.hp)
		for phase in 4:
			arena._process(0.18 if phase == 0 else 0.8)
			check(arena.intro.headline.text == ["1", "2", "3", "BATTLE!"][phase], "Playful countdown phase in order")
			check(arena.simulation.elapsed == 0.0 and arena.simulation.units.map(func(unit): return unit.hp) == opening_hp, "Countdown cannot damage or advance combat")
			check(arena.intro.headline.get_minimum_size().x <= arena.intro.size.x, "Countdown title fits phone")
			await _capture("battle_countdown_%d" % phase)
		var paused_countdown: float = arena.countdown
		arena._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		arena._process(5.0)
		check(arena.simulation.elapsed == 0.0, "Background pause stops offline clock")
		check(arena.countdown == paused_countdown, "Background pause freezes countdown")
		arena._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		arena._process(1.0)
		check(not arena.intro.visible and not arena.speed_button.disabled, "Intro releases controls before battle")
		await _click(arena.speed_button)
		check(arena.speed == 2.0, "Speed x2")
		await _click(arena.speed_button)
		check(arena.speed == 4.0, "Speed x4")
		await _click(arena.speed_button)
		check(arena.speed == 1.0, "Speed returns x1")
		for frame in 36:
			arena._process(0.1)
			await process_frame
		check(arena.simulation.units.any(func(unit): return unit.casts > 0), "Live units cast skills")
		check(arena.effects.active.size() > 0, "Skill VFX rendered")
		for view in arena.views.values():
			check(arena.get_node("Board").get_rect().size.y > view.root.position.y + view.root.size.y - 1, "Unit within board height")
			check(view.hp.value <= view.hp.max_value and view.cooldown.value <= view.cooldown.max_value, "HP/cooldown bounded")
		await _capture("battle_combat")
		# Freeze real VFX at a deterministic point for element-shape inspection.
		arena.effects.set_process(false)
		arena.effects.clear()
		for element in [41, 42, 43, 44]:
			var column := float(element - 41)
			var targets: Array[Vector2] = [Vector2(60 + column * 125, 140)]
			arena.effects.play({"type": "cast", "skill": SKILLS.for_id(element)}, Vector2(60 + column * 125, 310), targets)
		arena.effects._process(0.24)
		check(arena.effects.active[2].event.skill.visual == "ice", "Ice Chicken renders crystals, not generic slow circles")
		await _capture("battle_elemental_projectiles")
		arena.effects._process(0.30)
		await _capture("battle_elemental_impacts")
		arena.effects.clear()
		arena.effects.set_process(true)
		app._show_screen("shop")
		check(app.current_screen == "battle_match", "Cannot leave running battle via bottom tabs")
		var coins_before: float = game.coins
		await _click(arena.leave_button)
		check(arena.running, "First leave tap only asks confirmation")
		await _click(arena.leave_button, true)
		check(app.current_screen == "battle" and not arena.running and game.coins == coins_before, "Abandon returns to team without reward")
		check(app.get_node("UI/TopHUD").visible and app.get_node("UI/BottomMenu").visible and app.dev_toggle_button.visible, "Leaving match restores HUD, tabs and DEV")
		check(app.get_node("UI/ContentViewport").offset_top == 112.0 and app.get_node("UI/ContentViewport").offset_bottom == -136.0, "Lobby restores normal content bounds")
		# Finish a real, deliberately easy match; verify payout idempotence and rematch.
		var fixture := OFFLINE.build(game, 0, 333)
		for enemy in fixture.enemies: enemy.hp = 1.0; enemy.atk = 0.0
		app._show_screen("battle_match")
		arena.start_snapshot(fixture)
		await _prepare_arena(arena)
		arena._process(4.0)
		arena._process(30.0)
		await create_timer(0.4).timeout
		check(arena.simulation.result == "victory" and not arena.running and game.coins > coins_before, "Victory pays reward")
		var paid: float = game.coins
		arena._finish_match()
		arena._process(1.0)
		check(game.coins == paid, "Result cannot pay twice")
		check(arena.rematch_button.visible, "Rematch offered")
		check(arena.result_popup.visible and arena.result_popup.title.text == "VICTORY!", "Victory opens result popup")
		check(arena.result_popup.reward.text.contains("+300 GOLD"), "Popup shows the actual awarded Gold")
		_check_result_popup(arena)
		var background_point: Vector2 = arena.rematch_button.get_global_rect().get_center()
		for pressed in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.position = background_point
			touch.pressed = pressed
			root.push_input(touch, true)
		check(arena.result_popup.visible and not arena.running, "Full-screen result overlay blocks taps on underlying REMATCH")
		app._show_screen("shop")
		check(app.current_screen == "battle_match", "Result popup blocks background navigation")
		_check_fullscreen_arena(arena)
		await _capture("battle_result")
		await _click(arena.result_popup.rematch_button, true)
		check(arena.running and arena.countdown > 0.0 and arena.simulation.elapsed == 0.0, "Rematch resets state")
		check(game.coins == paid, "Starting rematch does not pay")
		arena.abandon_match()
		app._show_screen("battle")
		for outcome in ["defeat", "draw"]:
			app._show_screen("battle_match")
			arena.start_snapshot(fixture)
			await _prepare_arena(arena)
			arena._process(4.0)
			arena.simulation.running = false
			arena.simulation.result = outcome
			arena._finish_match()
			arena.result_popup._request_exit(false)
			check(arena.result_popup.visible, "Opening tap cannot instantly dismiss result")
			await create_timer(0.4).timeout
			check(arena.result_popup.visible and arena.result_popup.title.text == outcome.to_upper(), "Result popup handles " + outcome)
			check(game.coins == paid and arena.result_popup.reward.text == "NO REWARD THIS ROUND", "No invented rewards for " + outcome)
			_check_result_popup(arena)
			await _capture("battle_result_" + outcome)
			await _click(arena.result_popup.leave_button, true)
			check(app.current_screen == "battle" and not arena.result_popup.visible, "Popup leave returns to team and closes overlay")
		var original_team: Array = game.battle_team.duplicate()
		game.battle_team = game.animals.slice(0, 15).map(func(animal): return animal.id)
		app._show_screen("battle_match")
		arena.start_snapshot(OFFLINE.build(game, 1, 456))
		await _prepare_arena(arena)
		arena._process(4.0)
		arena._refresh()
		check(arena.simulation.units.size() == 30 and arena.views.size() == 30 and arena.simulation.board_rows == 11, "Full 15 vs 15 rendered")
		for view in arena.views.values():
			check(view.root.position.y >= 0 and view.root.position.y + view.root.size.y <= arena.get_node("Board").size.y, "Full roster stays within board")
		await _capture("battle_full_team")
		arena.abandon_match()
		check(not arena.intro.visible and not arena.preparing, "Abandon removes intro and pending preparation")
		game.battle_team = original_team
		app._show_screen("battle")
	check(game.animals == roster_before, "Battle never damages or consumes farm animals")
	# Leaving while loading then restarting must not revive the old simulation or
	# submit duplicate threaded requests that fail with ERR_BUSY.
	game.battle_team = game.animals.slice(80, 95).map(func(animal): return animal.id)
	app._show_screen("battle_match")
	var restart_fixture := OFFLINE.build(game, 1, 987)
	arena.start_snapshot(restart_fixture)
	check(arena.preparing, "New roster begins async preparation")
	arena.abandon_match()
	arena._process(2.0)
	check(not arena.running and not arena.intro.visible and arena.simulation.elapsed == 0.0, "Abandoned preparation cannot start combat")
	arena.start_snapshot(restart_fixture)
	await _prepare_arena(arena)
	check(arena.countdown == arena.INTRO.DURATION and arena.intro.visible, "Restart after aborted loading gets complete countdown")
	root.size = Vector2i(390, 844)
	await create_timer(0.2).timeout
	_check_fullscreen_arena(arena)
	check(arena.simulation.elapsed == 0.0, "Resizing fullscreen intro does not start combat")
	arena.abandon_match()
	var file := FileAccess.open("res://qa/battle-visual-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Offline lobby, 100 skill cards, 3 sizes, real GUI input, countdown, speed, leave, payout, rematch"}, "\t"))
	file.close()
	if failures.is_empty(): print("BATTLE_VISUAL_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)

func _prepare_arena(arena: Control) -> void:
	var frames := 0
	while arena.preparing and frames < 1200:
		arena._process(0.016)
		await process_frame
		frames += 1
	check(not arena.preparing and arena.running, "Threaded assets prepare successfully")
	check(arena.simulation.elapsed == 0.0, "Loading never advances battle clock")

func _check_fullscreen_arena(arena: Control) -> void:
	var viewport := app.get_viewport_rect()
	check(arena.get_global_rect().position.is_equal_approx(viewport.position) and arena.size.is_equal_approx(viewport.size), "Battle covers entire viewport without shell gutters")
	check(not app.get_node("UI/TopHUD").is_visible_in_tree() and not app.get_node("UI/BottomMenu").is_visible_in_tree(), "Resource HUD and bottom tabs hidden during intro/combat/results")
	check(not app.dev_toggle_button.visible and not app.dev_panel.visible, "DEV does not overlap fullscreen battle")
	for control in [arena.get_node("Header"), arena.get_node("Board"), arena.message_label, arena.leave_button, arena.speed_button, arena.rematch_button]:
		check(viewport.encloses(control.get_global_rect()), "Battle controls remain inside viewport: %s" % control.name)
	check(is_equal_approx(arena.get_node("Board").size.x, viewport.size.x - 16.0), "Battle board uses full width minus small inset")
	check(arena.grid.size.x >= arena.get_node("Board").size.x - 73.0, "Cell grid expands inside the ornamental forest border")

func _check_result_popup(arena: Control) -> void:
	var popup: CanvasLayer = arena.result_popup
	check(app.get_viewport_rect().encloses(popup.panel.get_global_rect()), "Result panel fits viewport")
	for label in [popup.title, popup.subtitle, popup.reward, popup.stats]:
		check(label.get_line_count() * label.get_line_height() <= label.size.y + 1, "Result text fits: " + label.name)
	for button in [popup.leave_button, popup.rematch_button]:
		check(button.size.y >= 88 and popup.panel.get_global_rect().encloses(button.get_global_rect()), "Result actions fit panel and finger targets")
