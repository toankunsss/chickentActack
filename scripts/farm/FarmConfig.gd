class_name FarmConfig
extends Resource

@export_group("Egg Delivery")
@export var delivery_intervals: Array[float] = [60.0, 55.0, 50.0, 45.0, 40.0, 35.0, 30.0, 25.0, 20.0, 15.0, 12.0]
@export var delivery_base_cost: int = 500
@export var delivery_cost_growth: float = 1.65

@export_group("Creatures")
@export_range(0.0, 1.0) var shiny_chance: float = 0.03
@export var base_income_per_tier: float = 2.0
@export var shiny_income_multiplier: float = 1.5
@export var income_tick_seconds: float = 2.2

@export_group("Fusion")
@export_range(0.0, 1.0) var cross_species_base_rate: float = 0.70
@export_range(0.0, 1.0) var cross_species_tier_penalty: float = 0.08
@export_range(0.0, 1.0) var cross_species_min_rate: float = 0.20
@export_range(0.0, 1.0) var critical_failure_chance: float = 0.10
@export_range(0.0, 1.0) var shiny_inheritance_one: float = 0.35
@export var hybrid_recipes: Dictionary = {
	"ga_ac_den|ga_ta_vang": "hybrid_ta_ac",
	"ga_ri_do|ga_ta_vang": "hybrid_ta_ri",
	"ga_ac_den|ga_ri_do": "hybrid_ac_ri",
}

@export_group("Enemy UFO Raid")
@export var raid_interval_min: float = 150.0
@export var raid_interval_max: float = 260.0
@export var ufo_health: int = 1000
@export var tap_damage: int = 10
@export var abduction_seconds: float = 15.0
@export var farm_damage_duration_seconds: int = 600
@export var damaged_income_multiplier: float = 0.40

@export_group("Loot Chances")
@export_range(0.0, 1.0) var material_chance: float = 0.60
@export_range(0.0, 1.0) var egg_chance: float = 0.30
@export_range(0.0, 1.0) var rare_egg_chance: float = 0.10
@export_range(0.0, 1.0) var rare_creature_chance: float = 0.03
@export_range(0.0, 1.0) var shiny_creature_chance: float = 0.005

func delivery_interval(level: int) -> float:
	return delivery_intervals[clampi(level, 0, delivery_intervals.size() - 1)]

func delivery_upgrade_cost(level: int) -> int:
	return roundi(delivery_base_cost * pow(delivery_cost_growth, level))

func fusion_chance(tier: int) -> float:
	return maxf(cross_species_min_rate, cross_species_base_rate - (tier - 1) * cross_species_tier_penalty)

func hybrid_result(species_a: String, species_b: String) -> String:
	var pair := [species_a, species_b]
	pair.sort()
	return str(hybrid_recipes.get("%s|%s" % [pair[0], pair[1]], ""))
