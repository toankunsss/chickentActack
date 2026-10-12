extends RefCounted
## Local/offline economy. Energy is spent in Battle and restored only by
## explicitly verified rewarded ads; it never regenerates from device time.
const ENERGY_CAP := 240
const BATTLE_COST := 5
const WIN_GOLD := 150
const WIN_GOLD_PER_CELL := 10
const WIN_XP := 20
const DAY_OFFSET := 7 * 3600
var state := {"energy": ENERGY_CAP, "energy_at": 0, "shop_day": -1, "shop_seed": 0}

static func battle_reward(owned_cells: int) -> Dictionary:
	return {"gold": WIN_GOLD + maxi(0, owned_cells) * WIN_GOLD_PER_CELL, "xp": WIN_XP}

static func day_at(now: int) -> int:
	return floori(float(now + DAY_OFFSET) / 86400.0)

func restore(data: Dictionary, legacy_energy := ENERGY_CAP) -> void:
	state = data.duplicate(true) if valid(data) else {"energy": maxi(0, legacy_energy), "energy_at": 0, "shop_day": -1, "shop_seed": 0}
	# JSON decodes all numbers as floats; canonicalize counters before comparison.
	for key in state: state[key] = int(state[key])

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	var limits := {"energy": [0, 10000000], "energy_at": [0, 86400000000], "shop_day": [-1, 1000000], "shop_seed": [0, 2147483647]}
	for key in limits:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return false
		if value < limits[key][0] or value > limits[key][1]: return false
	return true

func refresh_energy(now: int) -> int:
	# Keep energy_at for save compatibility, but elapsed time grants nothing.
	if state.energy_at == 0: state.energy_at = now
	return int(state.energy)

func grant_energy(amount: int) -> int:
	var before := int(state.energy)
	state.energy = mini(ENERGY_CAP, before + maxi(0, amount))
	return int(state.energy) - before

func spend(now: int) -> bool:
	if refresh_energy(now) < BATTLE_COST: return false
	state.energy = int(state.energy) - BATTLE_COST
	return true

func advance_shop(now: int) -> bool:
	var day := day_at(now)
	if day <= int(state.shop_day): return false
	state.shop_day = day
	state.shop_seed = randi_range(1, 2147483646)
	return true

func offers(map_id: String, species: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.shop_seed) + map_id.hash()
	var pool: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10]
	var eggs: Array[int] = [1]
	for i in 3:
		var index := rng.randi_range(0, pool.size() - 1)
		eggs.append(pool[index])
		pool.remove_at(index)
	eggs.sort()
	var chickens: Array[Dictionary] = []
	# Keep both Tier-1 lines for onboarding and guaranteed merge pairs.
	for breed in species:
		chickens.append({"id": str(breed) + ":1", "species": str(breed), "tier": 1, "price": 500})
		var tier := rng.randi_range(2, 4)
		chickens.append({"id": "%s:%d" % [breed, tier], "species": str(breed), "tier": tier, "price": 500 * int(pow(3, tier - 1))})
	return {"day": int(state.shop_day), "eggs": eggs, "chickens": chickens}
