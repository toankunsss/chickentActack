class_name FusionManager
extends Node

var config: FarmConfig
var rng := RandomNumberGenerator.new()

func setup(value: FarmConfig) -> void:
	config = value
	rng.randomize()

func chance(id_a: String, id_b: String) -> float:
	var a := Game.find_animal(id_a)
	var b := Game.find_animal(id_b)
	if a.is_empty() or b.is_empty() or a.tier != b.tier or a.species_id == b.species_id or a.tier >= Game.MAX_TIER:
		return 0.0
	if not Game.animal_belongs_to_map(a) or not Game.animal_belongs_to_map(b):
		return 0.0
	return config.fusion_chance(a.tier)

func fuse(id_a: String, id_b: String) -> Dictionary:
	var a := Game.find_animal(id_a)
	var b := Game.find_animal(id_b)
	var success_rate := chance(id_a, id_b)
	if success_rate <= 0.0:
		return {}
	var shiny_a: bool = str(a.rarity) == "rare"
	var shiny_b: bool = str(b.rarity) == "rare"
	var position := Vector2((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
	# Validate recipes before any destructive mutation, even on a failed roll.
	var species: String = config.hybrid_result(str(a.species_id), str(b.species_id))
	if not species.is_empty() and Game.species_index(species) < 0:
		return {}
	# A successful fusion must stay on the planet where the pair lives.
	# Legacy recipes may point to a lineage owned by another planet; those use
	# the existing 50/50 parent-lineage fallback instead of exporting the child.
	if not Game.species_ids_for_map().has(species):
		species = ""
	if rng.randf() >= success_rate:
		var critical := rng.randf() < config.critical_failure_chance
		var removed: Array = [id_a, id_b] if critical else [[id_a, id_b][rng.randi_range(0, 1)]]
		var survivor_id := "" if critical else (id_b if removed.has(id_a) else id_a)
		Game.remove_animals(removed)
		return {"success": false, "critical": critical, "chance": success_rate, "removed_ids": removed, "survivor_id": survivor_id}
	if species.is_empty():
		species = str(a.species_id) if rng.randf() < 0.5 else str(b.species_id)
	var inherit_shiny: bool = (shiny_a and shiny_b) or ((shiny_a or shiny_b) and rng.randf() < config.shiny_inheritance_one)
	Game.remove_animals([id_a, id_b])
	var result := Game.create_animal(species, a.tier + 1, {
		"x": position.x, "y": position.y,
		"force_rare": inherit_shiny, "force_normal": not inherit_shiny,
	})
	result["success"] = true
	result["chance"] = success_rate
	result["removed_ids"] = [id_a, id_b]
	return result
