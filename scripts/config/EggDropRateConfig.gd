class_name EggDropRateConfig
extends RefCounted

# Egg quality raises the expected chicken tier, but never guarantees its cap.
const RATES := {
	1: {1: 100.0},
	2: {1: 65.0, 2: 35.0},
	3: {1: 40.0, 2: 40.0, 3: 20.0},
	4: {1: 20.0, 2: 35.0, 3: 30.0, 4: 15.0},
	5: {1: 10.0, 2: 22.0, 3: 28.0, 4: 25.0, 5: 15.0},
	6: {1: 7.0, 2: 13.0, 3: 20.0, 4: 25.0, 5: 23.0, 6: 12.0},
	7: {1: 5.0, 2: 8.0, 3: 13.0, 4: 19.0, 5: 22.0, 6: 21.0, 7: 12.0},
	8: {1: 4.0, 2: 6.0, 3: 9.0, 4: 13.0, 5: 17.0, 6: 20.0, 7: 20.0, 8: 11.0},
	9: {1: 3.0, 2: 4.0, 3: 7.0, 4: 9.0, 5: 12.0, 6: 15.0, 7: 18.0, 8: 21.0, 9: 11.0},
	10: {1: 2.0, 2: 3.0, 3: 5.0, 4: 7.0, 5: 9.0, 6: 11.0, 7: 14.0, 8: 17.0, 9: 22.0, 10: 10.0},
}

static func rates(egg_level: int) -> Dictionary:
	return RATES[clampi(egg_level, 1, 10)]

static func roll(egg_level: int, roll_value := -1.0) -> int:
	var cursor := randf() * 100.0 if roll_value < 0.0 else clampf(roll_value, 0.0, 99.999999)
	var accumulated := 0.0
	for tier in range(1, 11):
		accumulated += float(rates(egg_level).get(tier, 0.0))
		if cursor < accumulated:
			return tier
	return 1

static func is_valid() -> bool:
	for egg_level in RATES:
		var total := 0.0
		for value in RATES[egg_level].values():
			total += float(value)
		if not is_equal_approx(total, 100.0):
			return false
	return RATES.size() == 10 and float(RATES[10].get(10, 0.0)) <= 10.0
