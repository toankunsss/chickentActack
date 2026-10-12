extends "res://tests/modal_visual_qa.gd"

func _run() -> void:
	game = root.get_node("Game")
	game.skip_tutorial()
	var sound: Node = root.get_node("Audio")
	sound.suspend_audio(false)
	app = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	app.set_process(false)
	var popup: CanvasLayer = app.settings_popup
	await create_timer(0.3).timeout
	check(sound.context == "farm", "Farm music starts with app")
	check(sound.sounds.size() == 23 and sound.tracks.size() == 3, "All 26 audio assets load")
	for stream in sound.sounds.values() + sound.tracks.values():
		check(stream != null and stream.get_length() > 0.05, "Audio stream has duration")
		var peak := 0
		var pcm: PackedByteArray = stream.data
		for i in range(0, pcm.size(), 2): peak = maxi(peak, absi(pcm.decode_s16(i)))
		check(peak > 100 and peak < 32767, "PCM is audible data without clipping")
	for stream in sound.tracks.values():
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == stream.data.size() / 2, "Music loops full PCM buffer")
		check(absi(stream.data.decode_s16(0) - stream.data.decode_s16(stream.data.size() - 2)) < 800, "Loop boundary has no large discontinuity")
	sound.set_volume("Music", 0.31)
	sound.set_volume("SFX", 0.62)
	sound.set_muted(true)
	sound.set_language("es")
	sound.save_preferences()
	check(sound.save_error == OK, "Independent preference save succeeds")
	sound.music_volume = 0.9
	sound.sfx_volume = 0.9
	sound.muted = false
	sound.language = "en"
	sound.load_preferences()
	check(is_equal_approx(sound.music_volume, 0.31) and is_equal_approx(sound.sfx_volume, 0.62) and sound.muted and sound.language == "es", "Preferences reload audio and language settings")
	sound.set_language("en")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Master toggle mutes both buses")
	sound.set_muted(false)
	sound.set_volume("Music", 0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Zero music preserves sound effects")
	sound.set_volume("Music", 0.55)
	sound.suspend_audio(true)
	check(sound.music_players[sound.active_player].stream_paused, "Background pauses music")
	sound.suspend_audio(false)
	check(not sound.music_players[sound.active_player].stream_paused, "Foreground resumes music")
	for player in sound.voices: player.stop()
	sound.cooldowns.clear()
	for i in 40: sound.play_sfx("cannon")
	check(sound.voices.filter(func(p): return p.playing).size() == 1, "Repeated cannon sound throttled")
	for cue in sound.CUES: sound.play_sfx(cue)
	check(sound.voices.filter(func(p): return p.playing).size() <= 8, "Bounded voice pool")
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		resolution = size
		root.size = size
		await create_timer(0.3).timeout
		check(app.get_node_or_null("UI/TopHUD/TopBar/Help") == null, "Duplicate help button removed from top HUD")
		check(app.get_viewport_rect().encloses(app.settings_button.get_global_rect()), "Gear fits top right")
		await _capture("settings_hud")
		await _click(app.settings_button, true)
		check(popup.visible and app._has_blocking_modal(), "Gear opens blocking modal")
		check(popup.language_select.item_count == 8 and popup.language_select.selected == 0, "Settings offers eight popular non-Vietnamese languages")
		check(popup.language_select.size.x >= popup.panel.size.x - 64.0, "Language dropdown spans the full modal content width")
		popup.language_select.select(5)
		popup.language_select.item_selected.emit(5)
		await process_frame
		check(sound.language == "ja" and popup.title_label.text == "設定" and app.rewards_hub.daily_button.get_node("Caption").text == "デイリーボーナス", "Language changes visible UI immediately")
		popup.language_select.select(0)
		popup.language_select.item_selected.emit(0)
		await process_frame
		check(sound.language == "en" and popup.title_label.text == "SETTINGS" and app.rewards_hub.daily_button.get_node("Caption").text == "DAILY CHECK-IN", "English can be restored immediately")
		await _capture("settings_open")
		check(app.get_viewport_rect().encloses(popup.panel.get_global_rect()), "Settings panel fits screen")
		for button in [popup.mute_button, popup.preview_button, popup.done_button]:
			check(popup.panel.get_global_rect().encloses(button.get_global_rect()) and button.size.y >= 88, "Finger-size action inside frame")
		check(popup.get("help_button") == null, "Completed tutorial cannot be replayed from Settings")
		var planet: String = app.current_planet
		app._cycle_farm_map()
		app._show_screen("shop")
		check(app.current_planet == planet and app.current_screen == "farm", "Modal blocks map and tab code paths")
		# The point is deliberately outside the panel. It must hit only the dim.
		for pressed in [true, false]:
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.pressed = pressed
			tap.position = Vector2(8, 200)
			root.push_input(tap, true)
		check(app.current_planet == planet and popup.visible, "Map behind overlay cannot be clicked")
		await _tap_slider(popup.sliders.Music, 0.35)
		check(sound.music_volume > 0.2 and sound.music_volume < 0.5, "Real pointer changes music volume")
		await _tap_slider(popup.sliders.SFX, 0.7)
		check(sound.sfx_volume > 0.5 and sound.sfx_volume < 0.85, "Real pointer changes SFX volume")
		await _click(popup.mute_button, true)
		check(sound.muted and popup.preview_button.disabled, "Mute updates test sound availability")
		await _click(popup.mute_button, true)
		await _click(popup.preview_button, true)
		await _capture("settings_popup")
		await _click(popup.done_button, true)
		check(not popup.visible and not app._has_blocking_modal(), "Done closes and releases input after guard")
		app._show_screen("shop")
		await create_timer(0.25).timeout
		await _click(app.settings_button, true)
		check(popup.visible, "Settings accessible from shop")
		await _click(popup.done_button, true)
		app._show_screen("farm")
		await create_timer(0.25).timeout
	app._show_screen("battle_match")
	await create_timer(0.75).timeout
	check(sound.context == "battle" and not app.settings_button.is_visible_in_tree(), "Fullscreen battle switches soundtrack and hides Farm HUD")
	app._show_screen("farm")
	game.create_animal("ga_ta_vang", 1)
	app.farm_manager.raids.start_raid()
	check(sound.context == "raid", "UFO raid switches soundtrack")
	app.farm_manager.raids.debug_defeat()
	check(sound.context == "farm", "Raid completion restores Farm music")
	sound.set_context("battle")
	sound.set_context("raid")
	sound.set_context("farm")
	await create_timer(0.8).timeout
	check(sound.music_players.filter(func(p): return p.playing).size() == 1, "Rapid context changes leave one playing track")
	app.settings_popup.open()
	await create_timer(0.1).timeout
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await create_timer(0.25).timeout
	check(not popup.visible and not app._has_blocking_modal(), "Escape closes without leaving an input blocker")
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", "bad")
	cfg.set_value("audio", "sfx", -1)
	cfg.set_value("audio", "muted", "not bool")
	cfg.save(sound.PREFS)
	sound.load_preferences()
	check(sound.music_volume == 0.55 and sound.sfx_volume == 0 and not sound.muted, "Malformed preference values sanitized")
	var file := FileAccess.open("res://qa/audio-settings-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Desktop GUI, PCM integrity, settings persistence, routing, background lifecycle; not physical Android or subjective listening"}, "\t"))
	file.close()
	if failures.is_empty(): print("AUDIO_SETTINGS_QA_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)

func _tap_slider(slider: Control, fraction: float) -> void:
	var point := slider.get_global_rect().position + Vector2(slider.size.x * fraction, slider.size.y * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)
		await process_frame
