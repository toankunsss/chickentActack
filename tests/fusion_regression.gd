extends SceneTree
var game: Node
var manager: Node
var checks := 0
var failures: Array[String] = []
const CONFIG = preload("res://data/farm_config.tres")

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmFusionQA/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func pair(planet: String, tier := 2, shiny_count := 0) -> Array:
	game.animals.clear()
	game.current_planet = planet
	var species: Array = game.species_ids_for_map(planet)
	return [game.create_animal(species[0], tier, {"x": 30.0, "y": 50.0, "force_rare": shiny_count > 0, "force_normal": shiny_count == 0}).animal,
		game.create_animal(species[1], tier, {"x": 70.0, "y": 50.0, "force_rare": shiny_count > 1, "force_normal": shiny_count < 2}).animal]

func seed_for(kind: String) -> int:
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
	manager = load("res://scripts/farm/FusionManager.gd").new()
	root.add_child(manager)
	manager.setup(CONFIG.duplicate(true))
	# All valid pairs/tiers must keep their offspring on their current planet.
	manager.config.cross_species_base_rate = 1.0
	manager.config.cross_species_min_rate = 1.0
	manager.config.cross_species_tier_penalty = 0.0
	for planet in game.MAP_SPECIES:
		for tier in range(1, 10):
			for trial in range(10):
				var parents := pair(planet, tier)
				manager.rng.seed = trial
				var wallet: float = game.coins
				var result: Dictionary = manager.fuse(parents[0].id, parents[1].id)
				check(result.get("success", false), "Guaranteed success fixture")
				if not result.has("animal"):
					continue
				check(game.animals.size() == 1 and result.animal.tier == tier + 1, "Two parents produce one next-tier creature")
				check(game.animal_belongs_to_map(result.animal, planet), "Offspring cannot leave " + planet)
				check(result.animal.x == 50.0 and result.animal.y == 50.0, "Offspring appears at midpoint")
				check(game.coins == wallet, "Fusion does not change Gold")
				var before: Array = game.animals.duplicate(true)
				check(manager.fuse(parents[0].id, parents[1].id).is_empty() and game.animals == before, "Repeated attempt cannot consume or create twice")
	manager.setup(CONFIG.duplicate(true))
	for kind in ["success", "failure", "critical"]:
		var parents := pair("earth")
		manager.rng.seed = seed_for(kind)
		var result: Dictionary = manager.fuse(parents[0].id, parents[1].id)
		check(result.success == (kind == "success"), "Seeded outcome: " + kind)
		check(result.removed_ids.size() == (1 if kind == "failure" else 2), "Outcome identifies exact lost IDs")
		if kind == "failure":
			check(game.animals.size() == 1 and game.animals[0].id == result.survivor_id, "Failure identifies actual survivor")
		elif kind == "critical":
			check(result.critical and game.animals.is_empty() and result.survivor_id.is_empty(), "Critical failure removes both")
		else:
			check(game.animal_belongs_to_map(result.animal, "earth"), "Legacy Earth recipe stays on Earth")
	# Invalid recipe/pair data must not consume either creature.
	var parents := pair("earth")
	manager.config.hybrid_recipes["ga_ac_den|ga_ta_vang"] = "invalid_species"
	var before: Array = game.animals.duplicate(true)
	check(manager.fuse(parents[0].id, parents[1].id).is_empty() and game.animals == before, "Invalid recipe is non-destructive")
	manager.setup(CONFIG.duplicate(true))
	parents = pair("earth", 10)
	check(manager.fuse(parents[0].id, parents[1].id).is_empty(), "Tier 10 cannot fuse")
	check(manager.fuse(parents[0].id, parents[0].id).is_empty(), "Cannot fuse with self")
	check(manager.fuse("missing", parents[0].id).is_empty(), "Missing ID rejected")
	# Existing shiny rules remain unchanged.
	for shiny_count in range(3):
		parents = pair("mars", 2, shiny_count)
		manager.config.shiny_inheritance_one = 1.0
		manager.rng.seed = seed_for("success")
		var result: Dictionary = manager.fuse(parents[0].id, parents[1].id)
		check(result.animal.rarity == ("normal" if shiny_count == 0 else "rare"), "Shiny inheritance count %d" % shiny_count)
	var file := FileAccess.open("res://qa/fusion-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	if failures.is_empty():
		print("FUSION_REGRESSION_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)
