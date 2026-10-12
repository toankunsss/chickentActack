extends "res://tests/modal_visual_qa.gd"
const CONFIG = preload("res://data/farm_config.tres")

func _outcome_seed(kind: String) -> int:
	for candidate in range(1, 1000):
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		var success := probe.randf() < CONFIG.fusion_chance(2)
		var critical := not success and probe.randf() < CONFIG.critical_failure_chance
		if (kind == "success" and success) or (kind == "critical" and critical) or (kind == "failure" and not success and not critical):
			return candidate
	return -1

func _run() -> void:
	game = root.get_node("Game")
	# Outcome animation owns the input in this fixture; tutorial behavior is
	# validated separately and must not cover the Fusion confirmation button.
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.2).timeout
		for kind in ["success", "failure", "critical"]:
			game.animals.clear()
			game.discovered.clear()
			game.current_planet = "earth"
			var left: Dictionary = game.create_animal("ga_ta_vang", 2, {"force_normal": true}).animal
			var right: Dictionary = game.create_animal("ga_ac_den", 2, {"force_normal": true}).animal
			app._sync_critters()
			app.pending_fusion.assign([left.id, right.id])
			app._show_fusion_modal(left, right, 0.62)
			await create_timer(0.3).timeout
			app.farm_manager.fusion.rng.seed = _outcome_seed(kind)
			var confirm: Button = app.fusion_panel.get_node("Confirm")
			var point := confirm.get_global_rect().get_center()
			for pressed in [true, false]:
				var tap := InputEventScreenTouch.new()
				tap.position = point
				tap.pressed = pressed
				root.push_input(tap, true)
				await process_frame
			check(app.fusion_resolving, "Touch starts resolution")
			check(confirm.disabled and app.fusion_panel.get_node("Close").disabled, "Buttons locked during animation")
			var snapshot: Array = game.animals.duplicate(true)
			var random_state: int = app.farm_manager.fusion.rng.state
			app._confirm_fusion()
			app._hide_fusion_modal()
			check(game.animals == snapshot and app.farm_manager.fusion.rng.state == random_state, "Repeated confirm cannot consume or reroll")
			check(app.fusion_modal_layer.visible, "Close cannot interrupt the resolving phase")
			var saved: Dictionary = game.SaveStore.read_snapshot(game.SAVE_PATH, game._is_valid_save)
			# JSON normalizes numeric types and floating-point precision. Compare
			# to the actual serialized representation, not an in-memory Variant.
			var persisted_roster: Array = JSON.parse_string(JSON.stringify(snapshot))
			check(not saved.is_empty() and saved.get("animals", []) == persisted_roster, "Outcome persisted before animation completes")
			_blocked_navigation()
			await create_timer(0.85).timeout
			check(app.fusion_result_showing and not app.fusion_resolving, "Result ready to acknowledge")
			check(confirm.text == "CONTINUE" and not confirm.disabled, "Continue replaces Fuse")
			check(app.fusion_result_content.visible, "Result content visible")
			check(app.fusion_result.success == (kind == "success"), "Outcome matches seeded live manager")
			if kind == "success":
				check(game.animals.size() == 1 and game.animals[0].tier == 3, "Success creates one Tier 3")
				check(game.animal_belongs_to_map(game.animals[0], "earth"), "Earth offspring remains on Earth")
				check(app.fusion_result_image.texture == game.creature_texture(game.animals[0]), "Result shows actual offspring")
			elif kind == "failure":
				check(game.animals.size() == 1 and game.animals[0].tier == 2, "Normal failure retains one parent")
				check(app.fusion_result_message.text.contains(game.display_name(game.animals[0])), "Survivor named correctly")
				check(app.fusion_result_image.texture == game.creature_texture(game.animals[0]), "Survivor artwork matches")
			else:
				check(game.animals.is_empty(), "Critical failure loses both")
				check(app.fusion_result_mark.visible and not app.fusion_result_image.visible, "Critical failure does not show a fake survivor")
				check(app.fusion_result_message.text.contains("Both creatures were lost"), "Loss explained explicitly")
			await _capture("fusion_result_" + kind)
			await _pointer_shield()
			await _click(confirm, true)
			check(not app.fusion_modal_layer.visible, "Continue closes the result")
			if kind == "success":
				check(is_instance_valid(app.discovery_overlay), "First success enters Who Is It reveal")
				await create_timer(3.0).timeout
				check(not is_instance_valid(app.discovery_overlay), "Discovery finishes and restores input")
			check(game.animals == snapshot, "Acknowledgement does not perform another fusion")
	var file := FileAccess.open("res://qa/fusion-outcome-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "3 outcomes x 3 viewport sizes, live manager and touch events"}, "\t"))
	file.close()
	if failures.is_empty():
		print("FUSION_OUTCOME_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)
