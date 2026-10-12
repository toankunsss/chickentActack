extends SceneTree
## Headless structural QA for the tutorial overlay. Gameplay progression is
## covered through semantic events, never synthetic button clicks.

const OVERLAY := preload("res://scenes/ui/TutorialOverlay.tscn")
const SIZES := [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var overlay: TutorialController = OVERLAY.instantiate()
	root.add_child(overlay)
	await process_frame
	assert(overlay.blockers.size() == 4, "Tutorial spotlight must use four input blockers")
	assert(overlay.STEP_IDS.size() == 8, "Tutorial must contain exactly eight onboarding steps")
	for size in SIZES:
		root.content_scale_size = size
		await process_frame
		overlay.visible = true
		overlay.current_step = "welcome"
		overlay._show_step()
		await process_frame
		var viewport_size := root.get_visible_rect().size
		var rect := overlay.callout.get_global_rect()
		assert(rect.position.x >= 11.0 and rect.position.y >= 11.0, "Callout must keep safe margins at %s" % size)
		assert(rect.end.x <= viewport_size.x - 11.0 and rect.end.y <= viewport_size.y - 11.0, "Callout must fit viewport at %s" % size)
		assert(overlay.next_button.size.y >= 48.0, "CTA must remain finger-friendly")
	overlay.replay_mode = true
	overlay.current_step = "collection"
	overlay._show_completion()
	overlay._on_next_pressed()
	assert(not overlay.visible, "Finish must close replay mode instead of reopening completion")
	var game := root.get_node("Game")
	game.skip_tutorial()
	var app: Control = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var live_tutorial: TutorialController = app.tutorial
	live_tutorial.replay()
	assert(live_tutorial.current_step == "welcome" and app.current_screen == "farm", "Replay starts on Farm")
	live_tutorial._on_next_pressed()
	assert(live_tutorial.current_step == "open_shop" and live_tutorial.target != null and live_tutorial.target.is_visible_in_tree(), "Shop step highlights a visible target")
	assert(live_tutorial.pointer.visible and absf(live_tutorial.pointer.get_global_rect().get_center().x - live_tutorial.target.get_global_rect().get_center().x) < 12.0, "Animated pointer aims at the highlighted control")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/screens"))
	assert(root.get_texture().get_image().save_png("res://qa/screens/tutorial_visit_market.png") == OK, "Tutorial step screenshot saves")
	live_tutorial._on_next_pressed()
	await process_frame
	assert(live_tutorial.current_step == "select_chickens" and app.current_screen == "shop", "Replay Next routes to Shop before chicken step")
	assert(live_tutorial.target != null and live_tutorial.target.is_visible_in_tree(), "Chicken tab target resolves on Shop")
	live_tutorial._on_next_pressed()
	await process_frame
	assert(live_tutorial.current_step == "acquire_pair" and app.current_screen == "shop", "Purchase step remains on Shop")
	live_tutorial._on_next_pressed()
	assert(live_tutorial.current_step == "return_farm" and live_tutorial.target != null and live_tutorial.target.is_visible_in_tree(), "Return step highlights Farm tab")
	live_tutorial._on_next_pressed()
	await process_frame
	assert(live_tutorial.current_step == "merge" and app.current_screen == "farm", "Merge step routes back to Farm")
	assert(live_tutorial.skip_button.get_theme_stylebox("normal") is StyleBoxFlat and live_tutorial.next_button.get_theme_stylebox("normal") is StyleBoxFlat, "Tutorial actions use game-styled buttons")
	print("TUTORIAL_ONBOARDING_QA_OK")
	quit(0)
