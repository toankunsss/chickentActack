class_name CreatureManager
extends Node

var config: FarmConfig

func setup(value: FarmConfig) -> void:
	config = value

func create_tier_one(force_shiny := false, spawn_position := Vector2(-1.0, -1.0)) -> Dictionary:
	return create_at_tier(1, force_shiny, spawn_position)

func create_at_tier(tier: int, force_shiny := false, spawn_position := Vector2(-1.0, -1.0)) -> Dictionary:
	if Game.animals_for_map().size() >= Game.MAX_ANIMALS:
		return {}
	var allowed_species: Array = Game.species_ids_for_map()
	var species_id: String = allowed_species.pick_random()
	var shiny := force_shiny or randf() < config.shiny_chance
	var spawn_x := spawn_position.x if spawn_position.x >= 0.0 else randf_range(12.0, 84.0)
	var spawn_y := spawn_position.y if spawn_position.y >= 0.0 else randf_range(20.0, 84.0)
	return Game.create_animal(species_id, clampi(tier, 1, Game.MAX_TIER), {
		"x": clampf(spawn_x, 3.0, 97.0), "y": clampf(spawn_y, 8.0, 94.0),
		"force_rare": shiny, "force_normal": not shiny,
	})

func remove(id: String) -> void:
	Game.remove_animals([id])
