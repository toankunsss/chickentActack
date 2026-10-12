class_name EggShopConfig
extends RefCounted

# Gold prices are centralized here so shop balance never leaks into UI code.
const ITEMS := [
	{"level": 1, "price": 500}, {"level": 2, "price": 1500},
	{"level": 3, "price": 4000}, {"level": 4, "price": 9000},
	{"level": 5, "price": 18000}, {"level": 6, "price": 40000},
	{"level": 7, "price": 85000}, {"level": 8, "price": 175000},
	{"level": 9, "price": 350000}, {"level": 10, "price": 700000},
]

static func item(egg_level: int) -> Dictionary:
	return ITEMS[clampi(egg_level, 1, 10) - 1]

static func price(egg_level: int) -> int:
	return int(item(egg_level).price)
