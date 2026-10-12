class_name LootManager
extends Node

var config: FarmConfig

func setup(value: FarmConfig) -> void:
	config = value

func roll_raid_loot() -> Dictionary:
	var loot := {"coins": randi_range(150, 350), "materials": 0, "egg": false, "rare_egg": false, "rare": false, "shiny": false}
	if randf() < config.material_chance:
		loot.materials = randi_range(1, 3)
	loot.egg = randf() < config.egg_chance
	loot.rare_egg = randf() < config.rare_egg_chance
	loot.rare = randf() < config.rare_creature_chance
	loot.shiny = randf() < config.shiny_creature_chance
	return loot
