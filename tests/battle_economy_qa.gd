extends "res://tests/modal_visual_qa.gd"
const OFFLINE = preload("res://scripts/battle/OfflineOpponent.gd")
var arena: Control
var fixture: Dictionary

func _prepare() -> void:
	arena.start_snapshot(fixture)
	while arena.preparing:
		arena._process(0.016)
		await process_frame
	arena._process(4.0)

func _outcome(value: String) -> void:
	arena.simulation.running = false
	arena.simulation.result = value
	arena._finish_match()

func _tap_result_action() -> void:
	# Result controls intentionally reject the tap that opened the popup. Wait
	# for its wall-clock guard, not a delta-time timer under renderer load.
	while Time.get_ticks_msec() <= arena.result_popup.input_guard_until:
		await process_frame
	await _click(arena.result_popup.rematch_button, true)

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
	game.xp_to_next = 1000
	for i in 3:
		var animal: Dictionary = game.create_animal(game.species_ids_for_map()[i % 2], 2, {"force_normal": true}).animal
		game.battle_team.append(animal.id)
	arena = app.battle_arena_screen
	arena.set_process(false)
	fixture = OFFLINE.build(game, 0, 451)
	app._show_screen("battle_match")
	game.play_progress.state.energy = 50
	game.play_progress.state.energy_at = int(Time.get_unix_time_from_system())
	await _prepare()
	check(game.energy_balance() == 50, "Preparation and countdown cost nothing")
	arena.abandon_match()
	check(game.energy_balance() == 50 and game.coins == 1000, "Cancelling countdown costs nothing and awards nothing")
	await _prepare()
	game._save_blocked = true
	arena._process(0.016)
	check(not arena.running and game.energy_balance() == 50, "Failed debit rolls back and prevents combat")
	check(arena.simulation.elapsed == 0, "Failed debit cannot advance simulation")
	game._save_blocked = false
	await _prepare()
	arena._process(0.016)
	check(game.energy_balance() == 45 and arena.energy_committed, "First combat update spends exactly five")
	arena._process(0.016)
	arena.start_snapshot(fixture)
	check(game.energy_balance() == 45, "Further updates and repeated start do not charge again")
	arena.abandon_match()
	check(game.energy_balance() == 45 and game.coins == 1000, "Abandon after combat gives no refund or reward")
	_outcome("victory")
	check(game.coins == 1000, "Late victory after abandon cannot pay")
	await _prepare()
	arena._process(0.016)
	check(game.energy_balance() == 40, "Next match has a separate energy cost")
	var owned: int = arena.simulation.territory.count(1)
	var expected: Dictionary = game.PlayProgress.battle_reward(owned)
	game._save_blocked = true
	_outcome("victory")
	check(arena.reward_pending and not arena.reward_granted, "Failed prize save remains pending")
	check(game.coins == 1000 and game.xp == 0, "Failed prize save rolls back both currencies")
	check(arena.result_popup.reward.text.begins_with("PENDING") and arena.result_popup.leave_button.disabled, "Pending UI never claims prize was granted")
	arena._leave()
	arena.start_snapshot(fixture)
	check(arena.reward_pending and not arena.running and arena.result_popup.visible, "Leave and rematch cannot discard a pending prize")
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.4).timeout
		var popup: CanvasLayer = arena.result_popup
		check(app.get_viewport_rect().encloses(popup.panel.get_global_rect()), "Pending reward panel fits phone")
		for label in [popup.subtitle, popup.reward, popup.stats]:
			check(label.get_line_count() * label.get_line_height() <= label.size.y + 1, "Pending text fits its label")
		await _capture("battle_reward_pending")
	await _tap_result_action()
	check(arena.reward_pending and game.coins == 1000, "Repeated failed retry cannot grant partial prize")
	game._save_blocked = false
	await _tap_result_action()
	check(arena.reward_granted and not arena.reward_pending, "Retry persists the prize")
	check(game.coins == 1000 + expected.gold and game.xp == expected.xp, "Victory grants exact Gold formula and XP")
	check(arena.result_popup.reward.text == "+%d GOLD  /  +%d XP" % [expected.gold, expected.xp], "Result shows the actual saved reward")
	check(game.energy_balance() == 40, "Claiming or retrying does not spend more energy")
	var paid: float = game.coins
	arena._finish_match()
	check(game.coins == paid and game.xp == expected.xp, "Duplicate finish cannot pay again")
	check(game.load_game() and game.coins == paid and game.xp == expected.xp and game.energy_balance() == 40, "Both energy and reward survive save reload")
	await _capture("battle_reward_saved")
	await _tap_result_action()
	check(arena.running and game.energy_balance() == 40, "Rematch countdown remains free")
	while arena.preparing:
		arena._process(0.016)
		await process_frame
	arena._process(4.0)
	arena._process(0.016)
	check(game.energy_balance() == 35, "Rematch combat spends five again")
	_outcome("defeat")
	check(game.coins == paid and game.xp == expected.xp, "Defeat gives no reward")
	arena.abandon_match()
	await _prepare()
	arena._process(0.016)
	_outcome("draw")
	check(game.coins == paid and game.xp == expected.xp and game.energy_balance() == 30, "Draw consumes energy but gives no reward")
	arena.abandon_match()
	game.play_progress.state.energy = 4
	game.play_progress.state.energy_at = int(Time.get_unix_time_from_system())
	arena.start_snapshot(fixture)
	check(not arena.running and game.energy_balance() == 4, "Insufficient energy blocks match without debit")
	app._show_screen("battle")
	app.battle_screen.refresh_energy()
	check(app.battle_screen.ready_button.disabled, "Lobby disables battle when energy is too low")
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.3).timeout
		var label: Label = app.battle_screen.status_label
		check(label.text.contains("WIN:") and label.text.contains("Energy"), "Lobby discloses both price and victory reward")
		check(label.get_line_count() * label.get_line_height() <= label.size.y + 1, "Reward preview text fits on phone")
		await _capture("battle_economy_lobby")
	app._show_screen("battle_match")
	game.play_progress.state.energy = 5
	await _prepare()
	arena._process(0.016)
	check(arena.running and game.energy_balance() == 0, "Exact entry balance is allowed and reaches zero, never negative")
	_outcome("defeat")
	await _tap_result_action()
	check(not arena.running and game.energy_balance() == 0, "Actual rematch button cannot start at zero energy")
	arena.abandon_match()
	game.play_progress.state.energy = 5
	await _prepare()
	game.play_progress.state.energy = 0
	arena._process(0.016)
	check(not arena.running and arena.simulation.elapsed == 0, "Affordability is rechecked after countdown before combat")
	var file := FileAccess.open("res://qa/battle-economy-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	if failures.is_empty(): print("BATTLE_ECONOMY_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)
