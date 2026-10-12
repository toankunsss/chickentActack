class_name EggUpgradeConfig
extends RefCounted

const MAX_LEVEL := 10

# Index is the current upgrade level. Every row intentionally totals 100.
const PROBABILITIES := [
	{1: 100.0},
	{1: 90.0, 2: 10.0},
	{1: 80.0, 2: 18.0, 3: 2.0},
	{1: 70.0, 2: 25.0, 3: 5.0},
	{1: 60.0, 2: 30.0, 3: 9.0, 4: 1.0},
	{1: 52.0, 2: 32.0, 3: 14.0, 4: 2.0},
	{1: 45.0, 2: 33.0, 3: 18.0, 4: 4.0},
	{1: 39.0, 2: 32.0, 3: 22.0, 4: 6.0, 5: 1.0},
	{1: 34.0, 2: 30.0, 3: 25.0, 4: 9.0, 5: 2.0},
	{1: 30.0, 2: 27.0, 3: 26.0, 4: 13.0, 5: 4.0},
	{1: 27.0, 2: 25.0, 3: 25.0, 4: 18.0, 5: 5.0},
]

const UPGRADE_COSTS := [1000, 2500, 5000, 10000, 20000, 40000, 80000, 150000, 300000, 600000]

# Chance for the transition starting at each level (Lv.5 -> Lv.6 = 75%).
# Early upgrades remain guaranteed while late-game upgrades become a Gold sink.
const SUCCESS_RATES := [100.0, 100.0, 100.0, 95.0, 85.0, 75.0, 65.0, 55.0, 45.0, 35.0]

static func rates(level: int) -> Dictionary:
	return PROBABILITIES[clampi(level, 0, MAX_LEVEL)]

static func cost(level: int) -> int:
	return UPGRADE_COSTS[level] if level >= 0 and level < MAX_LEVEL else 0

static func success_rate(level: int) -> float:
	return SUCCESS_RATES[level] if level >= 0 and level < MAX_LEVEL else 100.0

static func is_valid() -> bool:
	for row in PROBABILITIES:
		var total := 0.0
		for value in row.values():
			total += float(value)
		if not is_equal_approx(total, 100.0):
			return false
	return PROBABILITIES.size() == MAX_LEVEL + 1 and UPGRADE_COSTS.size() == MAX_LEVEL and SUCCESS_RATES.size() == MAX_LEVEL
