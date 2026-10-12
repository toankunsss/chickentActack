extends SceneTree
var app: Control
var game: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var cache := OS.get_user_data_dir().path_join("shader_cache")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmRaidQA/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	if DirAccess.dir_exists_absolute(cache):
		for shader in DirAccess.get_directories_at(cache):
			for version in DirAccess.get_directories_at(cache.path_join(shader)):
				DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir().path_join("shader_cache").path_join(shader).path_join(version))
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func capture(tag: String, resolution: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://qa/screens/raid_%s_%dx%d.png" % [tag, resolution.x, resolution.y]) == OK, "Screenshot " + tag)

func _run() -> void:
	game = root.get_node("Game")
	# Raid input is tested independently; the onboarding overlay has its own QA
	# and must not consume the synthetic cannon taps in this fixture.
	game.skip_tutorial()
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	game.current_planet = "earth"
	game.planet_cannon_levels = {"earth": 2}
	game.animals.clear()
	game.create_animal("ga_ta_vang", 1, {"force_normal": true})
	app._sync_critters()
	var raids: Node = app.farm_manager.raids
	for resolution in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		root.size = resolution
		await create_timer(0.2).timeout
		raids.start_raid()
		await create_timer(0.7).timeout
		check(app.raid_overlay.visible, "Raid is visible")
		check(app.raid_hp_bar.value == raids.hp and app.raid_hp_bar.max_value == raids.max_hp, "Full bar matches boss health")
		check(app.raid_hp_label.text == "%d / %d HP" % [raids.hp, raids.max_hp], "HP label has current and maximum")
		check(app.raid_boss_visual.texture == game.ufo_texture("boss", 0), "Boss arrives idle, not hurt")
		check(is_equal_approx(app.raid_hp_bar.get_global_rect().get_center().x, app.raid_boss_visual.get_global_rect().get_center().x), "HP stays centered beneath boss")
		for child in app.raid_blocker.get_children():
			check(not child is Label, "No banner text on launch deck")
		check(app.raid_blocker.mouse_filter == Control.MOUSE_FILTER_STOP, "Deck still blocks bottom tabs")
		await capture("full", resolution)
		var previous_hp: int = raids.hp
		var button: Button = app.raid_fire_button
		var point := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		check(root.gui_get_hovered_control() == button, "Cannon hit target at %s" % resolution)
		await process_frame
		for pressed in [true, false]:
			# Keep the synthetic pointer on the cannon; host-window motion can be
			# delivered between the press/release halves on slower visual runs.
			root.push_input(motion, true)
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = point
			click.pressed = pressed
			root.push_input(click, true)
			await process_frame
		await create_timer(0.15).timeout
		check(raids.hp == previous_hp - game.cannon_damage_for(), "Upgraded cannon click deals its saved damage at %s (HP %d -> %d)" % [resolution, previous_hp, raids.hp])
		check(app.raid_hp_bar.value == raids.hp, "HP bar updates without waiting for raid timer step")
		check(is_equal_approx(app.raid_hp_bar.get_global_rect().get_center().x, app.raid_boss_visual.get_global_rect().get_center().x), "HP and sprite remain aligned after recoil")
		while raids.hp > raids.max_hp * 0.5:
			raids.attack()
		check(app.raid_hp_bar.get_theme_stylebox("fill").bg_color == Color("ffbd45"), "Half-health bar turns amber")
		while raids.hp > raids.max_hp * 0.25:
			raids.attack()
		check(app.raid_hp_bar.get_theme_stylebox("fill").bg_color == Color("ed654f"), "Low-health bar turns red")
		await capture("low", resolution)
		while raids.active:
			raids.attack()
		check(app.raid_hp_bar.value == 0, "Final hit updates health to zero")
		check(not app.raid_overlay.visible, "Defeat removes boss, bar and cannon overlay")
		# Next loop also proves that a fresh boss starts with a full bar again.
	var file := FileAccess.open("res://qa/raid-visual-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	if failures.is_empty():
		print("RAID_VISUAL_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)
