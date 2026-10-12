extends "res://tests/modal_visual_qa.gd"
## Reuses isolated save/render helpers; never touches the player's roster.
func _run() -> void:
	game = root.get_node("Game")
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	app.farm_manager.process_mode = Node.PROCESS_MODE_DISABLED
	var safe_content := Rect2(294, 186, 306, 186)
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.2).timeout
		for planet in game.MAP_SPECIES:
			app._replace_farm_map(planet, false)
			var species: Array = game.species_ids_for_map(planet)
			var left := {"species_id": species[0], "tier": 2, "rarity": "normal"}
			var right := {"species_id": species[1], "tier": 2, "rarity": "normal"}
			app._show_fusion_modal(left, right, 0.62)
			await create_timer(0.3).timeout
			await _capture("fusion_inset_" + str(planet))
			# Check every eligible tier's names/textures, not only short sample names.
			for tier in range(1, 10):
				left.tier = tier
				right.tier = tier
				app.fusion_left_image.texture = game.creature_texture(left)
				app.fusion_right_image.texture = game.creature_texture(right)
				app.fusion_left_name.text = game.display_name(left)
				app.fusion_right_name.text = game.display_name(right)
				await process_frame
				await process_frame
				for card_name in ["LeftCreatureCard", "RightCreatureCard"]:
					var card: Panel = app.fusion_panel.get_node(card_name)
					var style: StyleBoxFlat = card.get_theme_stylebox("panel")
					check(safe_content.encloses(card.get_rect().grow(style.shadow_size)), "Card and glow stay inside cream inset: %s T%d %s" % [planet, tier, card_name])
					check(card.clip_contents, "Card clips its own children")
					var portrait: TextureRect = card.get_node("Portrait")
					var caption: Label = card.get_node("Caption")
					var inside := Rect2(Vector2.ZERO, card.size)
					check(inside.encloses(portrait.get_rect()), "Portrait fits card")
					check(inside.encloses(caption.get_rect()), "Caption fits card")
					check(is_equal_approx(portrait.get_rect().get_center().x, card.size.x * 0.5), "Portrait centered in its card")
			app.fusion_modal_layer.visible = false
	var file := FileAccess.open("res://qa/fusion-layout-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "coverage": "5 maps, tiers 1-9, 3 viewport sizes"}, "\t"))
	file.close()
	if failures.is_empty():
		print("FUSION_LAYOUT_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)
