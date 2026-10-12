extends "res://tests/modal_visual_qa.gd"
const OFFLINE = preload("res://scripts/battle/OfflineOpponent.gd")
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
	for id in range(61, 76):
		var animal: Dictionary = game.create_animal(game.SPECIES[(id - 1) % 10].id, (id - 1) / 10 + 1, {"force_normal": true}).animal
		game.battle_team.append(animal.id)
	app._show_screen("battle_match")
	var arena: Control = app.battle_arena_screen
	arena.set_process(false)
	var snapshot := OFFLINE.build(game, 1, 420)
	await create_timer(0.4).timeout
	var before := Time.get_ticks_usec()
	arena.start_snapshot(snapshot)
	var duration := float(Time.get_ticks_usec() - before) / 1000.0
	print("START_SNAPSHOT_MS: %.3f" % duration)
	var slowest := 0.0
	var prepare_start := Time.get_ticks_usec()
	while arena.preparing:
		var frame_start := Time.get_ticks_usec()
		arena._process(0.016)
		slowest = maxf(slowest, float(Time.get_ticks_usec() - frame_start) / 1000.0)
		await process_frame
	print("PREPARE_MS: %.3f; MAX_PREPARE_UPDATE_MS: %.3f" % [float(Time.get_ticks_usec() - prepare_start) / 1000.0, slowest])
	check(arena.running and arena.simulation.elapsed == 0.0, "Ready without advancing battle")
	arena.abandon_match()
	quit()
