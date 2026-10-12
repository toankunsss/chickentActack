class_name UFORaidManager
extends Node

signal raid_started(hp: int, seconds: float)
signal raid_updated(hp: int, seconds: float)
signal raid_defeated(loot: Dictionary)
signal creature_abducted(creature: Dictionary)

var config: FarmConfig
var loot_manager: LootManager
var active := false
var hp := 0
var max_hp := 0
var countdown := 0.0
var next_raid := 0.0

func setup(value: FarmConfig, loot: LootManager) -> void:
	config = value
	loot_manager = loot
	next_raid = randf_range(config.raid_interval_min, config.raid_interval_max)

func step(delta: float) -> void:
	if active:
		countdown -= delta
		raid_updated.emit(hp, maxf(0.0, countdown))
		if countdown <= 0.0:
			_abduct()
		return
	next_raid -= delta
	if next_raid <= 0.0:
		start_raid()

func start_raid() -> void:
	if active or Game.animals_for_map().is_empty():
		next_raid = 20.0
		return
	active = true
	max_hp = config.ufo_health
	hp = max_hp
	countdown = config.abduction_seconds
	raid_started.emit(hp, countdown)

func attack(damage: int = -1) -> void:
	if not active:
		return
	var hit_damage := config.tap_damage if damage < 0 else maxi(1, damage)
	hp = maxi(0, hp - hit_damage)
	# Update the health UI on the hit itself, including the final hit.
	raid_updated.emit(hp, maxf(0.0, countdown))
	if hp == 0:
		active = false
		var loot := loot_manager.roll_raid_loot()
		Game.coins += loot.coins
		Game.mutation_materials += loot.materials
		next_raid = randf_range(config.raid_interval_min, config.raid_interval_max)
		raid_defeated.emit(loot)

## Development-only hooks used by the temporary DEV MODE panel.
func debug_defeat() -> void:
	if not active:
		start_raid()
	while active:
		attack()

func debug_abduct() -> void:
	if not active:
		start_raid()
	if active:
		_abduct()

func _abduct() -> void:
	active = false
	var candidates := Game.animals_for_map().duplicate()
	candidates.sort_custom(func(a, b):
		var weight_a: float = 1.0 / maxf(1.0, a.tier * (2.0 if a.rarity == "rare" else 1.0))
		var weight_b: float = 1.0 / maxf(1.0, b.tier * (2.0 if b.rarity == "rare" else 1.0))
		return weight_a > weight_b)
	var pool_size := mini(3, candidates.size())
	var victim: Dictionary = candidates[randi_range(0, pool_size - 1)]
	Game.remove_animals([victim.id])
	Game.farm_defense_damaged_until = int(Time.get_unix_time_from_system()) + config.farm_damage_duration_seconds
	next_raid = randf_range(config.raid_interval_min, config.raid_interval_max)
	creature_abducted.emit(victim)
