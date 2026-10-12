class_name EggManager
extends Node

signal egg_added(egg: Dictionary)
signal egg_hatched(result: Dictionary)
signal capacity_full

const MAX_UNOPENED_EGGS := 5
const EggUpgrade = preload("res://scripts/config/EggUpgradeConfig.gd")
const EggDropRates = preload("res://scripts/config/EggDropRateConfig.gd")

var config: FarmConfig
var creatures: CreatureManager

func setup(value: FarmConfig, creature_manager: CreatureManager) -> void:
	config = value
	creatures = creature_manager

func capacity() -> int:
	return MAX_UNOPENED_EGGS

func can_receive() -> bool:
	return _eggs_for_current_map().size() < capacity()

func _eggs_for_current_map() -> Array:
	return Game.unopened_eggs.filter(func(egg): return str(egg.get("map_id", "earth")) == Game.current_planet)

func ensure_position(egg: Dictionary) -> Vector2:
	if egg.has("x") and egg.has("y"):
		return Vector2(float(egg.x), float(egg.y))
	var candidate := Vector2(50.0, 55.0)
	for attempt in 24:
		candidate = Vector2(randf_range(12.0, 88.0), randf_range(22.0, 86.0))
		var overlaps := false
		for other in _eggs_for_current_map():
			if other.has("x") and other.has("y") and candidate.distance_to(Vector2(float(other.x), float(other.y))) < 17.0:
				overlaps = true
				break
		if not overlaps:
			break
	egg["x"] = candidate.x
	egg["y"] = candidate.y
	return candidate

func deliver() -> Dictionary:
	if not can_receive():
		capacity_full.emit()
		return {}
	var egg := {
		"id": "egg_%d_%d" % [Time.get_ticks_usec(), randi()],
		"created_at": Time.get_unix_time_from_system(),
		"tier": roll_delivery_tier(),
		"map_id": Game.current_planet,
	}
	ensure_position(egg)
	Game.unopened_eggs.append(egg)
	egg_added.emit(egg)
	return egg

func roll_delivery_tier(roll := -1.0) -> int:
	var cursor := randf() * 100.0 if roll < 0.0 else clampf(roll, 0.0, 99.999999)
	var accumulated := 0.0
	var rates: Dictionary = EggUpgrade.rates(Game.egg_upgrade_level_for())
	for tier in range(1, 6):
		accumulated += float(rates.get(tier, 0.0))
		if cursor < accumulated:
			return tier
	return 1

func hatch(egg_id: String, spawn_position := Vector2(-1.0, -1.0)) -> Dictionary:
	var index := -1
	for i in Game.unopened_eggs.size():
		if Game.unopened_eggs[i].id == egg_id:
			index = i
			break
	if index < 0:
		return {}
	var egg: Dictionary = Game.unopened_eggs[index]
	if str(egg.get("map_id", "earth")) != Game.current_planet:
		return {}
	var egg_level := int(egg.get("tier", 1))
	var chicken_tier: int = EggDropRates.roll(egg_level)
	var result := creatures.create_at_tier(chicken_tier, false, spawn_position)
	if result.is_empty():
		return {}
	result["egg_level"] = egg_level
	result["chicken_tier"] = chicken_tier
	Game.unopened_eggs.remove_at(index)
	egg_hatched.emit(result)
	return result
