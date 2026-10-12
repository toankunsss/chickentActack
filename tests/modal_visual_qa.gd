extends SceneTree
## Exercises real modal controls with isolated state and a rendering driver.
const EGG = preload("res://scripts/config/EggUpgradeConfig.gd")
var app: Control
var game: Node
var checks := 0
var failures: Array[String] = []
var resolution := Vector2i.ZERO

func _initialize() -> void:
	var cache := OS.get_user_data_dir().path_join("shader_cache")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmModalQA/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	if DirAccess.dir_exists_absolute(cache):
		for shader in DirAccess.get_directories_at(cache):
			for version in DirAccess.get_directories_at(cache.path_join(shader)):
				DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir().path_join("shader_cache").path_join(shader).path_join(version))
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [resolution, message])
		push_error(failures.back())

func _run() -> void:
	game = root.get_node("Game")
	# Modal geometry tests need deterministic ownership of pointer input. The
	# tutorial has its own full-screen Skip button and is covered separately by
	# tutorial_onboarding_qa.gd.
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	game.animals.clear()
	game.unopened_eggs.clear()
	game.coins = 2000000
	await process_frame
	var left: Dictionary = game.create_animal("ga_ta_vang", 2, {"force_normal": true}).animal
	var right: Dictionary = game.create_animal("ga_ac_den", 2, {"force_normal": true}).animal
	app._sync_critters()
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.3).timeout
		await _egg_flow()
		await _fusion_flow(left, right)
		await _collection_flow(left)
		await _discovery_flow(left)
	var report := {"checks": checks, "failures": failures, "sizes": ["360x640", "390x844", "720x1280"], "scope": "Desktop renderer, injected mouse/touch; not physical Android"}
	var file := FileAccess.open("res://qa/modal-visual-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if failures.is_empty():
		print("MODAL_VISUAL_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)

func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://qa/screens/modal_%s_%dx%d.png" % [tag, resolution.x, resolution.y]
	check(root.get_texture().get_image().save_png(path) == OK, "Capture " + tag)

func _click(control: Control, touch := false) -> void:
	check(control.is_visible_in_tree(), "Target visible: " + control.name)
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	# Dispatch viewport-local coordinates, independent of host DPI/window resizing.
	root.push_input(motion, true)
	check(root.gui_get_hovered_control() == control, "Correct hit target: %s (actual %s at %s)" % [control.name, root.gui_get_hovered_control(), point])
	for pressed in [true, false]:
		# A native mouse move can arrive between frames and replace GUI hover.
		# Reassert the pointer immediately before each injected press/release.
		root.push_input(motion, true)
		if touch:
			var tap := InputEventScreenTouch.new()
			tap.position = point
			tap.pressed = pressed
			root.push_input(tap, true)
		else:
			var click := InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click, true)
	# Dispatch a complete tap atomically; OS focus/motion cannot interleave with
	# the two synthetic halves. This still traverses GUI hit-testing and signals.
	await process_frame
	await create_timer(0.4).timeout

func _button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == caption:
			return child
	return null

func _blocked_navigation() -> void:
	var planet: String = app.current_planet
	var screen: String = app.current_screen
	app._switch_planet("ice" if planet != "ice" else "earth")
	app._show_screen("shop" if screen != "shop" else "farm")
	check(app.current_planet == planet and app.current_screen == screen, "Modal blocks map and screen routing")
	check(app._has_blocking_modal(), "Modal input shield active")

func _pointer_shield() -> void:
	var screen: String = app.current_screen
	var planet: String = app.current_planet
	# Tap actual GUI positions in the viewport, not button signals.
	var points: Array[Vector2] = [Vector2(120, app.size.y - 60), app.map_switch_button.get_global_rect().get_center()]
	for point in points:
		for pressed in [true, false]:
			var tap := InputEventScreenTouch.new()
			tap.position = point
			tap.pressed = pressed
			root.push_input(tap, true)
			await process_frame
	check(app.current_screen == screen and app.current_planet == planet, "Physical taps cannot reach tab or map behind modal")

func _egg_flow() -> void:
	game.set_egg_upgrade_level(5)
	game.coins = 2000000
	app._toggle_upgrade_menu()
	await create_timer(0.4).timeout
	await _click(app.egg_upgrade_button)
	check(app.egg_upgrade_confirm_panel.visible, "Upgrade opens warning")
	check(app.egg_upgrade_confirm_chance.text == "SUCCESS 75%", "Warning shows actual success probability")
	check(app.egg_upgrade_confirm_failure.text == "FAILURE 25%", "Warning shows actual failure probability")
	check(game.coins == 2000000 and game.egg_upgrade_level_for() == 5, "Opening warning is free")
	_blocked_navigation()
	await _capture("egg_warning")
	await _click(app.egg_upgrade_confirm_panel.get_node("Cancel"), true)
	check(app.upgrade_menu.visible and not app.egg_upgrade_confirm_panel.visible, "Cancel returns to main upgrade panel")
	check(game.coins == 2000000 and game.egg_upgrade_level_for() == 5, "Cancel preserves money and level")
	await _click(app.egg_upgrade_button)
	await _click(app.egg_upgrade_close_button)
	check(not app.egg_upgrade_modal_layer.visible, "X closes warning")
	app._toggle_upgrade_menu()
	await create_timer(0.4).timeout
	await _click(app.egg_upgrade_button)
	await _click(app.egg_upgrade_confirm_panel.get_node("Confirm"), true)
	check(game.coins == 2000000 - EGG.cost(5), "Confirm charges exactly once with touch emulation")
	check(game.egg_upgrade_level_for() in [5, 6], "Attempt changes level only on success")
	await create_timer(0.35).timeout
	await _click(app.egg_upgrade_close_button)
	# Force both outcomes separately, through the production attempt function.
	app._toggle_upgrade_menu()
	await create_timer(0.4).timeout
	game.set_egg_upgrade_level(5)
	game.coins = 2000000
	app._attempt_egg_upgrade(1)
	await create_timer(0.6).timeout
	check(game.egg_upgrade_level_for() == 6 and game.coins == 2000000 - EGG.cost(5), "Forced success charges and increments once")
	check(app.egg_upgrade_success_rows.size() == 5, "Success explains all five egg types")
	for index in range(5):
		var row: Dictionary = app.egg_upgrade_success_rows[index]
		check(row.icon.texture == game.egg_texture(index + 1), "Success uses owned egg art %d" % index)
		check(row.rate.text == "%.0f%%" % float(EGG.rates(6).get(index + 1, 0.0)), "Success matches resulting drop rates")
	_blocked_navigation()
	await _capture("egg_success")
	await _click(app.egg_upgrade_success_panel.get_node("Confirm"), true)
	check(not app.egg_upgrade_modal_layer.visible, "OK closes success")
	app._toggle_upgrade_menu()
	await create_timer(0.4).timeout
	game.set_egg_upgrade_level(5)
	game.coins = 2000000
	app._attempt_egg_upgrade(0)
	check(game.egg_upgrade_level_for() == 5 and game.coins == 2000000 - EGG.cost(5), "Failure keeps level and spends cost")
	check(app.egg_upgrade_feedback.text.contains("FAILED"), "Failure feedback is explicit")
	await _capture("egg_failure")
	await _click(app.egg_upgrade_close_button)

func _fusion_flow(left: Dictionary, right: Dictionary) -> void:
	var count: int = game.animals.size()
	app.pending_fusion.assign([left.id, right.id])
	app._show_fusion_modal(left, right, 0.62)
	await create_timer(0.3).timeout
	check(app.fusion_left_name.text == game.display_name(left), "Fusion left caption matches sprite")
	check(app.fusion_right_name.text == game.display_name(right), "Fusion right caption matches sprite")
	check(not app.fusion_chance_label.get_parsed_text().contains("[/"), "No exposed BBCode")
	check(app.fusion_chance_label.get_content_height() <= app.fusion_chance_label.size.y, "Fusion warning is not clipped")
	_blocked_navigation()
	await _capture("fusion")
	await _pointer_shield()
	await _click(_button(app.fusion_panel, "CANCEL"), true)
	check(not app.fusion_modal_layer.visible and game.animals.size() == count, "Fusion Cancel preserves both creatures")
	app.pending_fusion.assign([left.id, right.id])
	app._show_fusion_modal(left, right, 0.62)
	await create_timer(0.3).timeout
	await _click(app.fusion_panel.get_node("Close"))
	check(not app.fusion_modal_layer.visible and game.animals.size() == count, "Fusion X closes without changes")

func _collection_flow(creature: Dictionary) -> void:
	app._show_screen("mutations")
	await create_timer(0.3).timeout
	var popup: Control = app.collection_screen.popup
	var entry := {"species_id": creature.species_id, "tier": creature.tier, "rare": false, "hybrid": false, "owned_count": 1, "unlocked": true}
	popup.show_entry(entry)
	await create_timer(0.3).timeout
	check(popup.creature_image.texture == game.creature_texture(creature), "Collection detail uses actual character sprite")
	check(popup.panel.position.is_equal_approx((popup.size - popup.panel.size) * 0.5), "Collection panel centered on responsive viewport")
	_blocked_navigation()
	await _capture("collection")
	await _pointer_shield()
	await _click(popup.close_button, true)
	check(not popup.visible, "Collection close works")
	entry.unlocked = false
	popup.show_entry(entry)
	await create_timer(0.3).timeout
	check(popup.title_label.text == "UNDISCOVERED" and popup.creature_image.modulate == Color.BLACK, "Locked character remains anonymous silhouette")
	await _capture("collection_locked")
	await _click(popup.close_button)
	app._show_screen("farm")
	await create_timer(0.3).timeout

func _discovery_flow(creature: Dictionary) -> void:
	app._play_merge_reveal({"animal": creature, "is_first": true}, false)
	await create_timer(0.45).timeout
	check(is_instance_valid(app.discovery_overlay), "First discovery opens fullscreen reveal")
	_blocked_navigation()
	check(app.discovery_overlay.get_parent().layer > app.egg_upgrade_canvas.layer, "Reveal covers navigation canvas")
	await _capture("discovery_silhouette")
	await _pointer_shield()
	await create_timer(1.2).timeout
	await _capture("discovery_revealed")
	await create_timer(1.5).timeout
	check(not is_instance_valid(app.discovery_overlay), "Reveal cleans up after animation")
	check(not app._has_blocking_modal(), "Reveal releases input")
	var view: Node2D = app.critter_views[creature.id]
	check(view.modulate.a == 1.0 and view.scale == Vector2.ONE, "Creature restored to farm")
