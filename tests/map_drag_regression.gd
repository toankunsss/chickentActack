extends SceneTree
var app: Control
var game: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmDragQA/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	game = root.get_node("Game")
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	game.animals.clear()
	game.unopened_eggs.clear()
	var residents := {}
	for planet in game.MAP_SPECIES:
		game.current_planet = planet
		residents[planet] = game.create_animal(game.species_ids_for_map(planet)[0], 2, {"force_normal": true, "x": 50.0, "y": 50.0}).animal
	for source in game.MAP_SPECIES:
		for destination in game.MAP_SPECIES:
			if source == destination:
				continue
			app._replace_farm_map(source, false)
			app._sync_critters()
			await process_frame
			var a: Dictionary = residents[source]
			var b: Dictionary = residents[destination]
			var point: Vector2 = app.farm_layer.to_global(Vector2(game.farm_size.x * 0.5, game.farm_size.y * 0.5))
			app._begin_drag(point)
			check(app.drag_id == a.id, "Pick only visible source on " + source)
			app._update_drag(point + Vector2(12, 0))
			app._replace_farm_map(destination, false)
			await process_frame
			var before: Dictionary = a.duplicate(true)
			check(app.drag_id.is_empty() and not a.dragging, "Changing map cancels drag: " + source + " -> " + destination)
			app._update_drag(app.farm_layer.to_global(Vector2(game.farm_size.x * 0.5, game.farm_size.y * 0.5)))
			app._end_drag()
			check(a.x == before.x and a.y == before.y, "Late move cannot relocate hidden source")
			check(not app.fusion_modal_layer.visible and app.pending_fusion.is_empty(), "Late release cannot offer cross-map fusion")
			check(game.pairing_kind(a, b).is_empty(), "Pairing rejects cross-map pair")
			check(app.farm_manager.fusion.fuse(a.id, b.id).is_empty(), "Fusion manager rejects cross-map pair")
			# Probe the legacy API too, but restore state after reproducing corruption.
			var snapshot: Array = game.animals.duplicate(true)
			var wallet: float = game.coins
			var stats: Dictionary = game.stats.duplicate(true)
			var discoveries: Array = game.discovered.duplicate()
			check(game.crossbreed_animals(a.id, b.id).is_empty(), "Legacy crossbreed rejects cross-map pair")
			check(game.animals == snapshot and game.coins == wallet and game.stats == stats and game.discovered == discoveries, "Rejected crossbreed has no side effects")
			game.animals.assign(snapshot)
			game.coins = wallet
			game.stats = stats
			game.discovered.assign(discoveries)
			for planet in residents:
				residents[planet] = game.find_animal(residents[planet].id)
			for animal in game.animals:
				animal.x = 50.0
				animal.y = 50.0
				animal.dragging = false
			app.fusion_modal_layer.visible = false
			app.pending_fusion.clear()
	app._replace_farm_map("earth", false)
	await process_frame
	var earth: Dictionary = residents.earth
	var local_point := Vector2(game.farm_size.x * 0.5, game.farm_size.y * 0.5)
	app.critter_views[earth.id].hide()
	check(app._animal_at(local_point).is_empty(), "Hidden view is never a drag target")
	app.critter_views[earth.id].show()
	var start: Vector2 = app.farm_layer.to_global(local_point)
	app._begin_drag(start)
	app._show_screen("shop")
	check(app.drag_id.is_empty() and not earth.dragging, "Leaving Farm cancels drag")
	app._show_screen("farm")
	await create_timer(0.25).timeout
	# Normal same-map merge must still work after the stricter guards.
	var second: Dictionary = game.create_animal(earth.species_id, 2, {"force_normal": true, "x": 80.0, "y": 50.0}).animal
	app._sync_critters()
	app._begin_drag(start)
	app._update_drag(app.farm_layer.to_global(Vector2(game.farm_size.x * 0.8, game.farm_size.y * 0.5)))
	app._end_drag()
	check(game.find_animal(earth.id).is_empty() and game.find_animal(second.id).is_empty(), "Same-map drag merge still consumes the intended pair")
	check(game.animals_for_map("earth").size() == 1 and game.animals_for_map("earth")[0].tier == 3, "Same-map merge creates one next-tier creature")
	var merged: Dictionary = game.animals_for_map("earth")[0]
	var partner: Dictionary = game.create_animal("ga_ac_den", 3, {"force_normal": true}).animal
	check(game.pairing_kind(merged, partner) == "crossbreed", "Same-map different lineage still eligible for Fusion")
	check(app.farm_manager.fusion.chance(merged.id, partner.id) > 0.0, "Same-map Fusion keeps configured chance")
	check(game.pairing_kind(merged, merged).is_empty(), "Self-pairing rejected")
	check(game.pairing_kind({}, partner).is_empty(), "Removed drag source rejected")
	var report := {"checks": checks, "failures": failures, "map_transitions": 20}
	var file := FileAccess.open("res://qa/map-drag-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if failures.is_empty():
		print("MAP_DRAG_REGRESSION_OK: %d checks, 20 directed map transitions" % checks)
	quit(0 if failures.is_empty() else 1)
