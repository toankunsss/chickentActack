extends Node

const CONFIG: FarmConfig = preload("res://data/farm_config.tres")
const EggUpgrade = preload("res://scripts/config/EggUpgradeConfig.gd")
const EggDropRates = preload("res://scripts/config/EggDropRateConfig.gd")
const EggShop = preload("res://scripts/config/EggShopConfig.gd")

func _ready() -> void:
	Game.animals.clear()
	Game.unopened_eggs.clear()
	Game.egg_capacity_level = 0
	Game.planet_egg_progress.clear()
	Game.current_planet = "earth"
	Game.set_delivery_level(0)
	Game.set_egg_upgrade_level(0)
	assert(EggUpgrade.is_valid(), "Every egg upgrade probability row must total 100 percent")
	assert(is_equal_approx(EggUpgrade.success_rate(5), 75.0), "Egg Upgrade Lv5 to Lv6 must have a 75 percent success rate")
	assert(EggDropRates.is_valid(), "Every egg drop probability row must total 100 percent")
	assert(EggDropRates.roll(1, 99.0) == 1, "Egg Lv1 must always hatch Chicken Tier 1")
	assert(EggDropRates.roll(10, 99.0) == 10, "Egg MAX must reserve its final ten percent for Chicken Tier 10")
	assert(EggDropRates.roll(10, 89.0) == 9, "Egg MAX must not guarantee Chicken Tier 10")
	assert(EggShop.price(10) > EggShop.price(1), "Higher shop eggs must cost more Gold")
	var original_coins := Game.coins
	Game.coins = 0
	assert(not Game.hatch_shop_egg(1).ok, "Shop egg purchase must fail safely without enough Gold")
	Game.coins = original_coins
	var tier_four := Game.tier_data(4)
	assert(tier_four is Dictionary and tier_four.atk == 60, "Tier detail data must return a Dictionary")
	assert(Game.MAX_TIER == 10 and Game.SPECIES.size() == 10, "Chicken collection must expose 10 lineages across 10 tiers")
	var assigned_species: Array = []
	for map_id in Game.MAP_SPECIES:
		var map_species: Array = Game.species_ids_for_map(map_id)
		assert(map_species.size() == 2, "Every farm must own exactly two evolution lines")
		for species_id in map_species:
			assert(not assigned_species.has(species_id), "An evolution line cannot belong to two farms")
			assigned_species.append(species_id)
	assert(assigned_species.size() == 10, "The five farms must cover all ten evolution lines")
	for tier in range(1, Game.MAX_TIER + 1):
		assert(Game.egg_texture(tier) != null, "Every tier egg texture must load")
		if tier > 1:
			assert(Game.TIER_SCALE[tier - 1] > Game.TIER_SCALE[tier - 2], "Higher tiers must always render larger")
		for species in Game.SPECIES:
			var preview := {"species_id": species.id, "tier": tier, "rarity": "normal"}
			assert(Game.creature_texture(preview) != null, "Every collection sprite must load")
			assert(Game.creature_animation_texture(preview, "bounce", 0) != null, "Every bounce sheet must load")
			assert(Game.creature_animation_texture(preview, "attack", 0) != null, "Every attack sheet must load")
			assert(Game.creature_animation_texture(preview, "hit", 0) != null, "Every hit sheet must load")
	for frame in Game.UFO_FRAME_COUNT:
		assert(Game.ufo_texture("delivery", frame) != null, "Every delivery UFO frame must load")
		assert(Game.ufo_texture("boss", frame) != null, "Every boss UFO frame must load")
	for map_path in [
		"res://scenes/farm/FarmMapMars.tscn",
		"res://scenes/farm/FarmMapVolcano.tscn",
		"res://scenes/farm/FarmMapIce.tscn",
		"res://scenes/farm/FarmMapSaturn.tscn",
	]:
		var map_scene := load(map_path) as PackedScene
		assert(map_scene != null, "Every themed farm map resource must load")
		var map_instance := map_scene.instantiate()
		assert(map_instance != null, "Every themed farm map must instantiate")
		map_instance.free()
	var farm := FarmManager.new()
	add_child(farm)
	farm.setup(CONFIG)
	Game.current_planet = "mars"
	var mars_spawn := farm.creatures.create_tier_one(false)
	assert(Game.species_ids_for_map("mars").has(mars_spawn.animal.species_id), "A farm may only spawn its assigned evolution lines")
	Game.remove_animals([mars_spawn.animal.id])
	Game.current_planet = "earth"
	for i in 5:
		assert(not farm.eggs.deliver().is_empty(), "Egg delivery should fit default capacity")
	assert(Game.unopened_eggs.size() == 5, "Default egg capacity must be five")
	assert(int(Game.unopened_eggs[0].get("tier", 0)) >= 1, "Delivered eggs must have a valid tier")
	assert(farm.eggs.deliver().is_empty(), "Sixth unopened egg must be blocked")
	var first_egg_id: String = Game.unopened_eggs[0].id
	var first_egg_tier: int = int(Game.unopened_eggs[0].tier)
	var hatch := farm.eggs.hatch(first_egg_id)
	assert(not hatch.is_empty(), "Tapping an egg should hatch a creature")
	assert(first_egg_tier == 1 and int(hatch.animal.tier) == 1, "A fresh save must deliver Egg Lv1 and hatch Chicken Tier 1")
	assert(Game.unopened_eggs.size() == 4, "Hatching must free one egg slot")
	Game.set_egg_upgrade_level(10)
	assert(farm.eggs.roll_delivery_tier(0.0) == 1, "MAX upgrade must retain common Egg Lv1")
	assert(farm.eggs.roll_delivery_tier(99.0) == 5, "MAX upgrade must cap Egg Lv5 at five percent")
	Game.set_delivery_level(4, "earth")
	Game.set_delivery_remaining(12.0, "earth")
	Game.set_egg_upgrade_level(7, "earth")
	assert(Game.delivery_level_for("mars") == 0, "A new planet must reset UFO level")
	assert(is_equal_approx(Game.delivery_remaining_for("mars"), CONFIG.delivery_interval(0)), "A new planet must have its own delivery timer")
	assert(Game.egg_upgrade_level_for("mars") == 0, "A new planet must reset egg probabilities")
	assert(Game.delivery_level_for("earth") == 4 and Game.egg_upgrade_level_for("earth") == 7, "Returning to a planet must restore its own progression")
	var weighted_egg := farm.eggs.deliver()
	var weighted_hatch := farm.eggs.hatch(weighted_egg.id)
	assert(int(weighted_hatch.animal.tier) <= int(weighted_egg.tier), "Delivered eggs use weighted chicken drops up to their egg level")
	var a := Game.create_animal("ga_ta_vang", 4, {"force_normal": true})
	var b := Game.create_animal("ga_ac_den", 4, {"force_normal": true})
	assert(is_equal_approx(farm.fusion.chance(a.animal.id, b.animal.id), 0.46), "Tier 4 fusion chance must be 46 percent")
	farm.raids.start_raid()
	for i in 100:
		farm.raids.attack()
	assert(not farm.raids.active, "100 taps at 10 damage must defeat a 1000 HP UFO")
	print("FARM_SYSTEM_SMOKE_OK")
	get_tree().quit()
