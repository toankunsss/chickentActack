extends SceneTree
## Run with --script res://tests/egg_upgrade_visual_qa.gd using a rendering driver.
## Uses a separate save directory and captures the real game at three phone sizes.

func _initialize() -> void:
	var original_shader_cache := OS.get_user_data_dir().path_join("shader_cache")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmEggUpgradeQA")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	# The renderer initializes shader cache directories before this test switches
	# user://. Recreate directory names only; no player files are copied.
	if DirAccess.dir_exists_absolute(original_shader_cache):
		for shader in DirAccess.get_directories_at(original_shader_cache):
			for version in DirAccess.get_directories_at(original_shader_cache.path_join(shader)):
				DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir().path_join("shader_cache").path_join(shader).path_join(version))
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_user_data_dir().ends_with("MutationFarmEggUpgradeQA"), "QA must not access the player's save")
	var app: Control = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	app._toggle_upgrade_menu()
	await create_timer(0.4).timeout
	var title: Label = app.upgrade_menu.get_node("Title")
	var fusion_title: Label
	for child in app.fusion_panel.get_children():
		if child is Label and child.text == "FUSION":
			fusion_title = child
	assert(fusion_title != null, "Fusion title is the typography reference")
	assert(title.get_theme_font("font") == fusion_title.get_theme_font("font"))
	assert(title.get_theme_color("font_color") == fusion_title.get_theme_color("font_color"))
	assert(title.get_theme_color("font_outline_color") == fusion_title.get_theme_color("font_outline_color"))
	assert(title.get_theme_constant("outline_size") == fusion_title.get_theme_constant("outline_size"))
	assert(title.get_theme_font_size("font_size") == fusion_title.get_theme_font_size("font_size"))
	var close: TextureButton = app.egg_upgrade_close_button
	assert(app.cannon_upgrade_label != null and app.cannon_upgrade_button != null, "Upgrade modal includes the Energy Cannon row")
	assert(app.cannon_upgrade_label.text.contains("ENERGY CANNON") and app.cannon_upgrade_label.text.contains("Damage"), "Cannon row explains level and damage")
	assert(app.upgrade_menu.get_global_rect().encloses(app.cannon_upgrade_button.get_global_rect()), "Cannon upgrade button stays inside modal")
	assert(not app.cannon_upgrade_button.get_global_rect().intersects(app.egg_upgrade_rates.get_global_rect()), "Cannon controls do not overlap egg rate table")
	assert(close.stretch_mode == TextureButton.STRETCH_KEEP_ASPECT_CENTERED, "Close icon must fit instead of tiling/cropping")
	assert(close.texture_normal != null and close.size.x >= 64 and close.size.y >= 64)
	DirAccess.make_dir_recursive_absolute("res://qa/screens")
	for resolution in [Vector2i(720, 1280), Vector2i(390, 844), Vector2i(360, 640)]:
		root.size = resolution
		if not app.egg_upgrade_modal_layer.visible:
			app._toggle_upgrade_menu()
			await create_timer(0.4).timeout
		await create_timer(0.2).timeout
		assert(title.label_settings == null, "Scene LabelSettings must not override the shared Fusion heading")
		assert(close.ignore_texture_size, "The SVG must fit the button's bounds")
		assert(close.texture_normal.resource_path == "res://assets/ui/egg-upgrade/egg-upgrade-close.svg")
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		assert(shot.save_png("res://qa/screens/egg_upgrade_fixed_%dx%d.png" % [resolution.x, resolution.y]) == OK)
		await _check_close(app, close, resolution.x == 360)
	print("EGG_UPGRADE_VISUAL_QA_OK: Fusion typography, three phone renders, real mouse/touch X clicks, no map click-through")
	quit()

func _check_close(app: Control, close: TextureButton, touch: bool) -> void:
	# Real pointer events exercise the close hitbox and the input blocker.
	var previous_planet: String = app.current_planet
	var click_position := close.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = click_position
	root.push_input(motion, true)
	print("Close hit test: ", click_position, " hovered=", root.gui_get_hovered_control())
	assert(root.gui_get_hovered_control() == close, "Pointer over X must hit the close button, not map switching")
	await process_frame
	for pressed in [true, false]:
		if touch:
			var tap := InputEventScreenTouch.new()
			tap.index = 0
			tap.position = click_position
			tap.pressed = pressed
			root.push_input(tap, true)
		else:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = click_position
			click.pressed = pressed
			root.push_input(click, true)
		await process_frame
	await create_timer(0.4).timeout
	assert(not app.egg_upgrade_modal_layer.visible, "Clicking X must close the modal")
	assert(app.current_planet == previous_planet, "Closing must not click the map behind the modal")
