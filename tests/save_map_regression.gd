extends SceneTree
## Headless regression using generated fixtures, never the player's save.

const CONFIG = preload("res://data/farm_config.tres")
var checks := 0
var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmRegression/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func fixture(path: String, value: Variant) -> void:
	assert(path.begins_with("user://") and OS.get_user_data_dir().contains("MutationFarmRegression"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value if value is String else JSON.stringify(value))
	file.close()

func clear_fixtures() -> void:
	assert(OS.get_user_data_dir().contains("MutationFarmRegression"))
	for path in [game.SAVE_PATH, game.SAVE_PATH + ".bak", game.SAVE_PATH + ".tmp", game.SAVE_PATH + ".bak.tmp", game.LEGACY_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	game.load_game()

func _run() -> void:
	game = root.get_node("Game")
	if OS.get_cmdline_user_args().has("--farm-smoke"):
		root.add_child(load("res://tests/FarmSystemSmoke.tscn").instantiate())
		return
	check(not game.load_game() and game.save_load_status == "missing", "Fresh install has no save")
	check(game.is_tutorial_active() and game.tutorial_step_id() == "welcome", "Fresh install starts onboarding")
	var farm: Node = load("res://scripts/farm/FarmManager.gd").new()
	root.add_child(farm)
	farm.setup(CONFIG)
	game.animals.clear()
	game.unopened_eggs.clear()
	game.planet_egg_progress.clear()
	game.planet_cannon_levels.clear()
	game.coins = 1000000
	var saved_eggs: Dictionary = {}
	var saved_animals: Dictionary = {}
	var index := 0
	for planet in game.MAP_SPECIES:
		game.current_planet = planet
		check(game.delivery_level_for() == 0 and game.egg_upgrade_level_for() == 0, "Fresh progression: " + planet)
		game.set_delivery_level(index)
		game.set_egg_upgrade_level(index * 2)
		game.planet_cannon_levels[planet] = index
		game.set_delivery_remaining(20.0 + index)
		var animal: Dictionary = game.create_animal(game.species_ids_for_map()[0], index + 1, {"force_normal": true}).animal
		saved_animals[planet] = animal.id
		for egg_index in range(5):
			var egg: Dictionary = farm.eggs.deliver()
			check(not egg.is_empty(), "Each map has five independent egg slots: " + planet)
			saved_eggs[planet] = egg.id
		check(farm.eggs.deliver().is_empty(), "Sixth egg rejected: " + planet)
		index += 1
	game.current_planet = "ice"
	game.battle_team = [saved_animals.ice]
	game.tutorial_progress.reset_for_new_player()
	check(game.tutorial_progress.accept_event("ack_welcome"), "Prepare tutorial persistence fixture")
	var saved_tutorial: Dictionary = game.tutorial_snapshot()
	check(game.save_game(), "Persist five independent worlds")
	var baseline: Dictionary = game.SaveStore.read_snapshot(game.SAVE_PATH, game._is_valid_save)
	game.animals.clear()
	game.unopened_eggs.clear()
	game.planet_egg_progress.clear()
	game.planet_cannon_levels.clear()
	game.coins = 0
	check(game.load_game(), "Reload five-world save")
	check(game.current_planet == "ice" and game.coins == 1000000, "Restore selected world and wallet")
	check(game.battle_team == [saved_animals.ice], "Restore battle roster")
	check(game.tutorial_snapshot() == saved_tutorial, "Tutorial step round trips with game save")
	index = 0
	for planet in game.MAP_SPECIES:
		game.current_planet = planet
		check(game.delivery_level_for() == index and game.egg_upgrade_level_for() == index * 2, "Upgrade levels round trip: " + planet)
		check(game.cannon_level_for() == index and game.cannon_damage_for() == roundi(CONFIG.tap_damage * (1.0 + index * 0.5)), "Cannon level and damage round trip: " + planet)
		check(is_equal_approx(game.delivery_remaining_for(), 20.0 + index), "Timer round trip: " + planet)
		check(game.animals_for_map().size() == 1 and game.animals_for_map()[0].id == saved_animals[planet], "Roster stays on its world: " + planet)
		check(not farm.eggs.can_receive(), "Egg slots restored: " + planet)
		var foreign: String = saved_eggs.mars if planet != "mars" else saved_eggs.earth
		var before: int = game.animals.size()
		check(farm.eggs.hatch(foreign).is_empty(), "Reject hatching a foreign-world egg: " + planet)
		check(game.animals.size() == before, "Rejected hatch creates no creature: " + planet)
		var hatch: Dictionary = farm.eggs.hatch(saved_eggs[planet])
		check(not hatch.is_empty() and game.animal_belongs_to_map(hatch.animal), "Hatch assigned species: " + planet)
		index += 1
	game.current_planet = "earth"
	var mars_cannon_before: int = game.cannon_level_for("mars")
	var cannon_cost: int = game.cannon_upgrade_cost()
	var cannon_damage_before: int = game.cannon_damage_for()
	check(game.upgrade_cannon().ok and game.coins == 1000000 - cannon_cost and game.cannon_damage_for() > cannon_damage_before, "Cannon upgrade charges exact cost and raises damage")
	check(game.cannon_level_for("mars") == mars_cannon_before, "Earth cannon upgrade cannot change Mars cannon")
	var mars_before: Dictionary = game.planet_egg_progress.mars.duplicate(true)
	check(farm.delivery.upgrade(), "Upgrade Earth UFO")
	farm.delivery.step(0.5)
	check(game.planet_egg_progress.mars == mars_before, "Earth upgrade and countdown cannot change Mars")
	var self_merge: String = saved_animals.earth
	check(game.merge_animals(self_merge, self_merge).is_empty(), "Cannot merge one creature with itself")
	var top_a: Dictionary = game.create_animal("ga_ta_vang", 10, {"force_normal": true}).animal
	var top_b: Dictionary = game.create_animal("ga_ac_den", 10, {"force_normal": true}).animal
	check(farm.fusion.fuse(top_a.id, top_b.id).is_empty(), "Cannot fuse beyond Tier 10")
	check(not game.find_animal(top_a.id).is_empty() and not game.find_animal(top_b.id).is_empty(), "Rejected fusion preserves both creatures")
	check(game.create_animal("ga_ta_vang", 11).is_empty(), "Invalid tier cannot crash sprite/type lookup")
	# Interrupted writes, malformed schemas, and fallback must not lose the last good save.
	fixture(game.SAVE_PATH, baseline)
	game.coins = 999999
	check(game.save_game(), "Save replacement creates a verified backup")
	fixture(game.SAVE_PATH, "{truncated")
	fixture(game.SAVE_PATH + ".tmp", "{incomplete temporary write")
	check(game.load_game() and game.save_load_status == "recovered", "Recover corrupt primary from backup, ignore incomplete temp")
	check(game.coins == 1000000 and game.animals.size() == 5, "Recovery restores the entire previous snapshot")
	check(game.save_game(), "Repair primary after recovery")
	check(not game.SaveStore.read_snapshot(game.SAVE_PATH + ".bak", game._is_valid_save).is_empty(), "Recovery never backs up corrupt primary over good backup")
	clear_fixtures()
	fixture(game.SAVE_PATH, {"save_version": 3, "coins": "bad", "animals": []})
	var coins_before: float = game.coins
	check(not game.load_game() and game.coins == coins_before, "Malformed schema rejected before mutating memory")
	check(not game.save_game(), "Autosave cannot overwrite unreadable player data")
	check(FileAccess.get_file_as_string(game.SAVE_PATH).contains("bad"), "Invalid original remains available for recovery")
	# Legacy v2 breed mapping and old shared progression belong to Earth only.
	clear_fixtures()
	var legacy := baseline.duplicate(true)
	legacy.save_version = 2
	legacy.erase("planet_egg_progress")
	legacy.erase("planet_egg_progress_version")
	legacy.erase("tutorial_progress")
	legacy.current_planet = "ice"
	legacy.delivery_level = 4
	legacy.egg_upgrade_level = 7
	legacy.delivery_remaining = 11.5
	legacy.animals = [{"id": "legacy_chick", "species_id": "chick", "tier": 2}]
	legacy.discovered = ["chick", "chick_beo", "chick"]
	legacy.battle_team = ["legacy_chick"]
	fixture(game.LEGACY_SAVE_PATH, legacy)
	check(game.load_game() and game.save_load_status == "migrated", "Read legacy v2 file")
	check(not game.is_tutorial_active() and game.tutorial_snapshot().completed, "Veteran save without tutorial migrates to completed")
	check(game.animals[0].species_id == "ga_ri_do" and game.animals[0].id == "legacy_chick", "Migrate breed without changing creature identity")
	check(game.discovered == ["ga_ri_do", "ga_ri_do_beo"], "Migrate and deduplicate discovery IDs")
	check(game.delivery_level_for("earth") == 4 and game.egg_upgrade_level_for("earth") == 7, "Shared legacy upgrades preserved on Earth")
	check(game.delivery_level_for("ice") == 0 and game.egg_upgrade_level_for("ice") == 0, "Open world does not inherit Earth upgrades")
	check(game.save_game() and game.load_game(), "Migrated save can be saved and reloaded")
	check(game.delivery_level_for("earth") == 4 and game.delivery_level_for("ice") == 0, "Migration is idempotent")
	clear_fixtures()
	legacy.planet_egg_progress_version = 1
	legacy.planet_egg_progress = {"ice": {"delivery_level": 8, "egg_upgrade_level": 9, "delivery_remaining": 5.0}}
	fixture(game.SAVE_PATH, legacy)
	check(game.load_game(), "Read buggy progression v1 snapshot")
	check(game.delivery_level_for("earth") == 8 and game.egg_upgrade_level_for("earth") == 9, "Preserve strongest legacy progression on Earth")
	check(game.egg_upgrade_level_for("ice") == 0, "Repair shared upgrade leakage on Ice")
	# Actual App lifecycle: five-second autosave and pause/close save handlers.
	clear_fixtures()
	fixture(game.SAVE_PATH, baseline)
	var app: Control = load("res://scenes/Game.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	await process_frame
	for animal in game.animals:
		animal.x = 50.0
		animal.y = 50.0
	for planet in game.MAP_SPECIES:
		app._switch_planet(planet)
		await process_frame
		check(app.current_planet == planet and game.current_planet == planet, "Scene and state switch together: " + planet)
		check(app.farm_map.scene_file_path == app.MAP_SCENES[planet].resource_path, "Load the correct authored map scene: " + planet)
		check(app.critter_views.size() == 1 and app.critter_views.has(saved_animals[planet]), "Only current world's creatures render: " + planet)
		check(app.egg_views.size() == 5, "Only current world's eggs render: " + planet)
		var picked: Dictionary = app._animal_at(game.farm_size * 0.5)
		check(not picked.is_empty() and picked.id == saved_animals[planet], "Cannot select invisible creature from another planet: " + planet)
	game.coins = 43210
	app.save_elapsed = 4.99
	app._process(0.02)
	check(game.SaveStore.read_snapshot(game.SAVE_PATH, game._is_valid_save).coins == game.coins, "Autosave at five seconds")
	game.coins = 54321
	app.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(game.SaveStore.read_snapshot(game.SAVE_PATH, game._is_valid_save).coins == 54321, "Save before mobile background/pause")
	game.coins = 65432
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(game.SaveStore.read_snapshot(game.SAVE_PATH, game._is_valid_save).coins == 65432, "Save on close request")
	var report := {"checks": checks, "failures": failures, "save_directory": OS.get_user_data_dir(), "engine": Engine.get_version_info().string}
	var report_file := FileAccess.open("res://qa/save-map-regression.json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("SAVE_MAP_REGRESSION_%s: %d checks; %d failures" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
