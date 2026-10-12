extends Node
## Autoload singleton: game data, state, and core mechanics.
## Ported 1:1 from the HTML prototype's js/data.js + js/animals.js —
## Chicken-breed roster, persistent state, and core farm/shop mechanics.

const FARM_CONFIG: FarmConfig = preload("res://data/farm_config.tres")
const EggDropRates = preload("res://scripts/config/EggDropRateConfig.gd")
const EggShop = preload("res://scripts/config/EggShopConfig.gd")
const SaveStore = preload("res://scripts/farm/SaveStore.gd")
const TutorialProgressState = preload("res://scripts/tutorial/TutorialProgress.gd")
const RewardProgress = preload("res://scripts/rewards/RewardProgress.gd")
const PlayProgress = preload("res://scripts/config/PlayProgress.gd")
const MAX_TIER := 10
const BUY_STARTER_COST := 500
const FOOD_COST := 100
const FOOD_XP := 15
const FOOD_COIN_BONUS := 60
const GEM_POUCH_COST := 800
const GEM_POUCH_AMOUNT := 15
const MYSTERY_EGG_COST := 50
const MAX_ANIMALS := 40
# Stored as a zero-based upgrade index: 0 is displayed as Lv.1 and 9 as Lv.10.
const MAX_CANNON_LEVEL := 9
const CANNON_BASE_COST := 1200
const CANNON_COST_GROWTH := 1.75
const CHICKEN_ASSET_ROOT := "res://assets/chickens"
const CHICKEN_FRAME_SIZE := 384
const SUPPORT_ASSET_ROOT := "res://assets/chickens/support"
const UFO_FRAME_SIZE := 512
const UFO_FRAME_COUNT := 6
const ANIMATION_FRAMES := {"bounce": 6, "attack": 6, "hit": 4}
const ANIMATION_FPS := {"bounce": 8.0, "attack": 12.0, "hit": 10.0}

# English display names; internal slugs remain stable for save compatibility.
const EVOLUTION_LINE := [
	{"adj": "", "adj_slug": "", "rare_adj": "Shiny", "rare_slug": "shiny", "atk": 8, "hp": 40, "speed": 62},
	{"adj": "Chubby", "adj_slug": "beo", "rare_adj": "Golden", "rare_slug": "golden", "atk": 18, "hp": 95, "speed": 48},
	{"adj": "Giant", "adj_slug": "to", "rare_adj": "Crystal", "rare_slug": "crystal", "atk": 34, "hp": 190, "speed": 52},
	{"adj": "Tri-Eyed", "adj_slug": "bamat", "rare_adj": "Neon", "rare_slug": "neon", "atk": 60, "hp": 380, "speed": 44},
	{"adj": "Alien", "adj_slug": "hanhtinh", "rare_adj": "Cosmic", "rare_slug": "vutru", "atk": 120, "hp": 640, "speed": 58},
	{"adj": "Nuclear", "adj_slug": "hatnhan", "rare_adj": "Radioactive", "rare_slug": "phongxa", "atk": 210, "hp": 1100, "speed": 40},
	{"adj": "Cyber", "adj_slug": "congnghe", "rare_adj": "Quantum", "rare_slug": "luongtu", "atk": 360, "hp": 1750, "speed": 46},
	{"adj": "Galactic", "adj_slug": "vutru", "rare_adj": "Stellar", "rare_slug": "tinhtu", "atk": 590, "hp": 2700, "speed": 50},
	{"adj": "Mythic", "adj_slug": "thanthoai", "rare_adj": "Celestial", "rare_slug": "thiengioi", "atk": 920, "hp": 4100, "speed": 54},
	{"adj": "Supreme", "adj_slug": "toithuong", "rare_adj": "Eternal", "rare_slug": "vinhhang", "atk": 1450, "hp": 6500, "speed": 58},
]

# All creatures are chickens.  The shared frames are tinted by breed; adding a
# new breed is data-only and collection totals automatically follow it.
const SPECIES := [
	{
		"id": "ga_ta_vang", "noun": "Golden Farm Chicken", "label": "Farm Chicken", "emoji": "🐔", "hue": 42.0,
	},
	{
		"id": "ga_ac_den", "noun": "Black Silkie", "label": "Silkie", "emoji": "🐔", "hue": 270.0,
	},
	{
		"id": "ga_ri_do", "noun": "Red Jungle Chicken", "label": "Jungle Chicken", "emoji": "🐔", "hue": 8.0,
	},
	{
		"id": "ga_silk_trang", "noun": "White Silkie", "label": "White Silkie", "emoji": "🐔", "hue": 195.0,
	},
	{"id": "hybrid_ta_ac", "noun": "Eclipse Chicken", "label": "Eclipse", "emoji": "🧬", "hue": 305.0},
	{"id": "hybrid_ta_ri", "noun": "Solar Chicken", "label": "Solar", "emoji": "🧬", "hue": 22.0},
	{"id": "hybrid_ac_ri", "noun": "Shadow Chicken", "label": "Shadow", "emoji": "🧬", "hue": 245.0},
	{"id": "ga_comet", "noun": "Comet Chicken", "label": "Comet", "emoji": "☄️", "hue": -1.0},
	{"id": "ga_oracle", "noun": "Oracle Chicken", "label": "Oracle", "emoji": "🔮", "hue": -1.0},
	{"id": "ga_chaos", "noun": "Chaos Chicken", "label": "Chaos", "emoji": "🌀", "hue": -1.0},
]

# Each farm owns two complete evolution lines (Tier 1 through Tier 10).
# Together the five farms cover all 100 collection characters exactly once.
const MAP_SPECIES := {
	"earth": ["ga_ta_vang", "ga_ac_den"],
	"mars": ["ga_ri_do", "ga_silk_trang"],
	"volcano": ["hybrid_ta_ac", "hybrid_ta_ri"],
	"ice": ["hybrid_ac_ri", "ga_comet"],
	"saturn": ["ga_oracle", "ga_chaos"],
}

const CROSSBREED_CHANCE_BY_TIER := {1: 0.70, 2: 0.55, 3: 0.40, 4: 0.25, 5: 0.16, 6: 0.12, 7: 0.09, 8: 0.06, 9: 0.04}

const RARE_HUE_BY_TIER := {1: 200.0, 2: 40.0, 3: 180.0, 4: 320.0, 5: 260.0, 6: 60.0, 7: 195.0, 8: 225.0, 9: 285.0, 10: 45.0}
# Strictly increasing visual size. Gameplay collision remains independent.
const TIER_SCALE := [0.82, 0.90, 0.98, 1.06, 1.14, 1.22, 1.30, 1.38, 1.46, 1.55]
const FARM_LEVEL_INCOME_BONUS := 0.01

# ---- runtime state ----
var coins: float = 12450.0
var gems: int = 125
var dna: int = 240
var alien_dna: int = 0
var mutation_materials: int = 0
var farm_level: int = 12
var xp: float = 30.0
var xp_to_next: float = 100.0
var animals: Array = []  # Array[Dictionary]
var discovered: Array = []  # ids, e.g. "mouse", "shiny_mouse"
var stats := {"created": 0, "merges": 0, "rares": 0}
var battle_team: Array = []  # animal ids — Battle screen not built yet, stays empty
var team_capacity: int = 15
var farm_defense_damaged_until: int = 0
var current_planet := "earth"
var adventure_chapter: int = 1
var unopened_eggs: Array = []
var egg_capacity_level: int = 0
# Progression is isolated per planet. Legacy scalar fields are kept only for
# migrating old saves and are no longer used by gameplay systems.
var planet_egg_progress: Dictionary = {}
var planet_cannon_levels: Dictionary = {}
var tutorial_progress = TutorialProgressState.new()
var reward_progress = RewardProgress.new()
var play_progress = PlayProgress.new()
var _chicken_names: Array = []
var _texture_cache: Dictionary = {}

var _seq := 1
var save_load_status := "missing"
var _save_blocked := false
var farm_size: Vector2 = Vector2(720, 900)

func ensure_planet_egg_progress(map_id: String = current_planet) -> Dictionary:
	if not planet_egg_progress.has(map_id):
		planet_egg_progress[map_id] = {
			"egg_upgrade_level": 0,
			"delivery_level": 0,
			"delivery_remaining": FARM_CONFIG.delivery_interval(0),
		}
	return planet_egg_progress[map_id]

func egg_upgrade_level_for(map_id: String = current_planet) -> int:
	return clampi(int(ensure_planet_egg_progress(map_id).get("egg_upgrade_level", 0)), 0, 10)

func set_egg_upgrade_level(value: int, map_id: String = current_planet) -> void:
	ensure_planet_egg_progress(map_id)["egg_upgrade_level"] = clampi(value, 0, 10)

func delivery_level_for(map_id: String = current_planet) -> int:
	return maxi(0, int(ensure_planet_egg_progress(map_id).get("delivery_level", 0)))

func set_delivery_level(value: int, map_id: String = current_planet) -> void:
	ensure_planet_egg_progress(map_id)["delivery_level"] = maxi(0, value)

func cannon_level_for(map_id: String = current_planet) -> int:
	return clampi(int(planet_cannon_levels.get(map_id, 0)), 0, MAX_CANNON_LEVEL)

func cannon_damage_for(map_id: String = current_planet) -> int:
	return roundi(FARM_CONFIG.tap_damage * (1.0 + cannon_level_for(map_id) * 0.5))

func cannon_upgrade_cost(map_id: String = current_planet) -> int:
	return roundi(CANNON_BASE_COST * pow(CANNON_COST_GROWTH, cannon_level_for(map_id)))

func upgrade_cannon(map_id: String = current_planet) -> Dictionary:
	var level := cannon_level_for(map_id)
	if level >= MAX_CANNON_LEVEL: return {"ok": false, "reason": "max_level"}
	var cost := cannon_upgrade_cost(map_id)
	if coins < cost: return {"ok": false, "reason": "coins", "cost": cost}
	var previous_coins := coins
	coins -= cost
	planet_cannon_levels[map_id] = level + 1
	if not save_game():
		coins = previous_coins
		planet_cannon_levels[map_id] = level
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "level": level + 1, "damage": cannon_damage_for(map_id), "cost": cost}

func delivery_remaining_for(map_id: String = current_planet) -> float:
	return float(ensure_planet_egg_progress(map_id).get("delivery_remaining", FARM_CONFIG.delivery_interval(delivery_level_for(map_id))))

func set_delivery_remaining(value: float, map_id: String = current_planet) -> void:
	ensure_planet_egg_progress(map_id)["delivery_remaining"] = maxf(0.0, value)

func species_index(species_id: String) -> int:
	for i in SPECIES.size():
		if SPECIES[i].id == species_id:
			return i
	return -1

func breed_index(breed_id: String) -> int:
	return species_index(breed_id)

func breed_count() -> int:
	return SPECIES.size()

func species_ids_for_map(map_id: String = current_planet) -> Array:
	return MAP_SPECIES.get(map_id, MAP_SPECIES.earth)

func animal_belongs_to_map(animal: Dictionary, map_id: String = current_planet) -> bool:
	return species_ids_for_map(map_id).has(str(animal.get("species_id", "")))

func animals_for_map(map_id: String = current_planet) -> Array:
	return animals.filter(func(animal): return animal_belongs_to_map(animal, map_id))

func tier_data(tier: int) -> Dictionary:
	var e: Dictionary = EVOLUTION_LINE[clampi(tier, 1, MAX_TIER) - 1]
	var combat: Dictionary = [
		{"role": "Scout", "trait": "Swift", "range": 1, "cost": 1, "role_punch": 1.0},
		{"role": "Assassin", "trait": "Berserk", "range": 1, "cost": 2, "role_punch": 1.05},
		{"role": "Support", "trait": "Support", "range": 2, "cost": 3, "role_punch": 0.95},
		{"role": "Tank", "trait": "Guardian", "range": 1, "cost": 4, "role_punch": 1.0},
		{"role": "DPS", "trait": "Venom", "range": 3, "cost": 5, "role_punch": 1.03},
		{"role": "Overlord", "trait": "Control", "range": 2, "cost": 6, "role_punch": 1.0},
		{"role": "Artillery", "trait": "Tech", "range": 3, "cost": 7, "role_punch": 1.04},
		{"role": "Starborn", "trait": "Cosmic", "range": 3, "cost": 8, "role_punch": 1.06},
		{"role": "Mythic", "trait": "Ascendant", "range": 2, "cost": 9, "role_punch": 1.08},
		{"role": "Ultimate", "trait": "Infinite", "range": 4, "cost": 10, "role_punch": 1.10},
	][tier - 1]
	return e.merged(combat)

func animal_power(animal: Dictionary) -> int:
	var d := tier_data(animal.tier)
	var multiplier := 1.05 if animal.get("rarity", "normal") == "rare" else 1.0
	return round((d.atk * multiplier * 1.4 + d.hp * multiplier / 6.0 + d.speed * (1.02 if multiplier > 1.0 else 1.0) * 1.2) * d.role_punch)

func creature_texture(animal: Dictionary) -> Texture2D:
	return _texture("%s/sprites/%03d.png" % [CHICKEN_ASSET_ROOT, creature_asset_id(animal)])

func creature_asset_id(animal: Dictionary) -> int:
	var tier := clampi(int(animal.get("tier", 1)), 1, MAX_TIER)
	var lineage := maxi(0, species_index(str(animal.get("species_id", SPECIES[0].id))))
	return (tier - 1) * 10 + clampi(lineage, 0, 9) + 1

func creature_animation_texture(animal: Dictionary, action: String, elapsed_ms: int) -> Texture2D:
	var safe_action := action if ANIMATION_FRAMES.has(action) else "bounce"
	var count: int = ANIMATION_FRAMES[safe_action]
	var fps: float = ANIMATION_FPS[safe_action]
	var frame := int(floor(float(elapsed_ms) / 1000.0 * fps)) % count
	var key := "%03d/%s/%d" % [creature_asset_id(animal), safe_action, frame]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var sheet: Texture2D = _texture("%s/animations/%03d/%s.png" % [CHICKEN_ASSET_ROOT, creature_asset_id(animal), safe_action])
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame * CHICKEN_FRAME_SIZE, 0, CHICKEN_FRAME_SIZE, CHICKEN_FRAME_SIZE)
	_texture_cache[key] = atlas
	return atlas

func egg_texture(tier: int) -> Texture2D:
	return _texture("%s/eggs/tier-%02d.png" % [SUPPORT_ASSET_ROOT, clampi(tier, 1, MAX_TIER)])

func ufo_texture(kind: String, frame: int) -> Texture2D:
	var safe_kind := "boss" if kind == "boss" else "delivery"
	var safe_frame := posmod(frame, UFO_FRAME_COUNT)
	var key := "support-ufo/%s/%d" % [safe_kind, safe_frame]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture("%s/%s-ufo.png" % [SUPPORT_ASSET_ROOT, safe_kind])
	atlas.region = Rect2(safe_frame * UFO_FRAME_SIZE, 0, UFO_FRAME_SIZE, UFO_FRAME_SIZE)
	_texture_cache[key] = atlas
	return atlas

func _texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path) as Texture2D
	return _texture_cache[path]

func creature_color(animal: Dictionary) -> Color:
	var tier := clampi(int(animal.get("tier", 1)), 1, MAX_TIER)
	if str(animal.get("rarity", "normal")) == "rare":
		return Color(1.0, 0.88, 0.52)
	return Color.WHITE

func chicken_name(asset_id: int) -> String:
	if _chicken_names.is_empty():
		var file := FileAccess.open("%s/chickens.json" % CHICKEN_ASSET_ROOT, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				for item in parsed.get("sprites", []):
					_chicken_names.append(str(item.get("name", "Chicken")))
	var index := clampi(asset_id - 1, 0, 99)
	return str(_chicken_names[index]) if index < _chicken_names.size() else "Chicken %03d" % asset_id

func tier_name(species_id: String, tier: int) -> String:
	var index := species_index(species_id)
	if index < 0:
		return "Unknown Chicken"
	var sp = SPECIES[index]
	var adj = EVOLUTION_LINE[tier - 1].adj
	return (adj + " " if adj != "" else "") + sp.noun

func tier_rare_name(species_id: String, tier: int) -> String:
	var index := species_index(species_id)
	if index < 0:
		return "Mutant Chicken"
	var sp = SPECIES[index]
	var e = EVOLUTION_LINE[tier - 1]
	return e.rare_adj + " " + (e.adj + " " if e.adj != "" else "") + sp.noun

func type_id(species_id: String, tier: int) -> String:
	var slug: String = EVOLUTION_LINE[tier - 1].adj_slug
	if slug == "":
		return species_id
	return species_id + "_" + slug

func rare_type_id(species_id: String, tier: int) -> String:
	return type_id(species_id, tier) + "_" + EVOLUTION_LINE[tier - 1].rare_slug

func _next_id() -> String:
	_seq += 1
	return "a%d_%d" % [_seq, Time.get_ticks_msec()]

## Creates a new animal dict for species/tier. opts: {x, y, force_rare, force_normal}
func create_animal(species_id: String, tier: int, opts: Dictionary = {}) -> Dictionary:
	if species_index(species_id) < 0 or tier < 1 or tier > MAX_TIER:
		return {}
	var is_rare: bool
	if opts.get("force_rare", false):
		is_rare = true
	elif opts.get("force_normal", false):
		is_rare = false
	else:
		is_rare = randf() < FARM_CONFIG.shiny_chance

	var animal := {
		"id": _next_id(),
		"tier": tier,
		"species_id": species_id,
		"breed_id": species_id,
		"type": type_id(species_id, tier),
		"rarity": "rare" if is_rare else "normal",
		"x": opts.get("x", 10.0 + randf() * 80.0),
		"y": opts.get("y", 10.0 + randf() * 74.0),
		"facing": 1,
		"walking": false,
		"idle_until": 0,
		"target_x": 0.0,
		"target_y": 0.0,
		"dragging": false,
	}
	animals.append(animal)
	stats.created += 1
	if is_rare:
		stats.rares += 1

	var mutation_id = rare_type_id(species_id, tier) if is_rare else type_id(species_id, tier)
	var is_first = not discovered.has(mutation_id)
	if is_first:
		discovered.append(mutation_id)

	return {"animal": animal, "is_rare": is_rare, "is_first": is_first}

func find_animal(id: String) -> Dictionary:
	for a in animals:
		if a.id == id:
			return a
	return {}

func remove_animals(ids: Array) -> void:
	animals = animals.filter(func(a): return not ids.has(a.id))

## same species + same tier -> "merge"; same tier, different species -> "crossbreed"
func pairing_kind(a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() or b.is_empty():
		return ""
	if a.has("id") and a.id == b.get("id", ""):
		return ""
	if not animal_belongs_to_map(a) or not animal_belongs_to_map(b):
		return ""
	if b.tier != a.tier or a.tier >= MAX_TIER:
		return ""
	return "merge" if b.species_id == a.species_id else "crossbreed"

func merge_animals(id_a: String, id_b: String) -> Dictionary:
	if id_a == id_b:
		return {}
	var a = find_animal(id_a)
	var b = find_animal(id_b)
	if a.is_empty() or b.is_empty() or a.tier != b.tier or a.species_id != b.species_id or a.tier >= MAX_TIER:
		return {}
	if not animal_belongs_to_map(a) or not animal_belongs_to_map(b):
		return {}
	var mid_x = (a.x + b.x) / 2.0
	var mid_y = (a.y + b.y) / 2.0
	remove_animals([id_a, id_b])
	stats.merges += 1
	return create_animal(a.species_id, a.tier + 1, {"x": mid_x, "y": mid_y})

func crossbreed_animals(id_a: String, id_b: String) -> Dictionary:
	var a = find_animal(id_a)
	var b = find_animal(id_b)
	if pairing_kind(a, b) != "crossbreed":
		return {}
	var tier = a.tier
	var chance = CROSSBREED_CHANCE_BY_TIER.get(tier, 0.1)
	var success = randf() < chance
	var mid_x = (a.x + b.x) / 2.0
	var mid_y = (a.y + b.y) / 2.0
	remove_animals([id_a, id_b])
	stats.merges += 1
	if not success:
		var consolation := randi_range(20, 50)
		coins += consolation
		return {"success": false, "chance": chance, "consolation": consolation}
	var chosen = a.species_id if randf() < 0.5 else b.species_id
	var result = create_animal(chosen, tier + 1, {"x": mid_x, "y": mid_y})
	result["success"] = true
	return result

func display_name(animal: Dictionary) -> String:
	var name := chicken_name(creature_asset_id(animal))
	return "%s ✨" % name if str(animal.get("rarity", "normal")) == "rare" else name

func passive_income() -> int:
	var total := 0.0
	for a in animals:
		var value: float = FARM_CONFIG.base_income_per_tier * a.tier
		if a.rarity == "rare":
			value *= FARM_CONFIG.shiny_income_multiplier
		total += value
	return roundi(total * farm_income_multiplier())

func farm_income_multiplier() -> float:
	# Farm XP is permanent progression. Each level after Lv.1 adds one percent
	# to passive Gold produced by creatures on every planet.
	return 1.0 + maxf(0.0, float(farm_level - 1)) * FARM_LEVEL_INCOME_BONUS

func is_farm_damaged() -> bool:
	return Time.get_unix_time_from_system() < farm_defense_damaged_until

func passive_income_after_damage() -> int:
	var income := passive_income()
	return roundi(income * FARM_CONFIG.damaged_income_multiplier) if is_farm_damaged() else income

func buy_food() -> Dictionary:
	if coins < FOOD_COST:
		return {"ok": false, "reason": "coins"}
	coins -= FOOD_COST
	xp += FOOD_XP
	coins += FOOD_COIN_BONUS
	return {"ok": true, "xp": FOOD_XP, "coins": FOOD_COIN_BONUS}

func buy_gem_pouch() -> Dictionary:
	if coins < GEM_POUCH_COST:
		return {"ok": false, "reason": "coins"}
	coins -= GEM_POUCH_COST
	gems += GEM_POUCH_AMOUNT
	return {"ok": true, "gems": GEM_POUCH_AMOUNT}

func hatch_mystery_egg(opts: Dictionary = {}) -> Dictionary:
	if gems < MYSTERY_EGG_COST:
		return {"ok": false, "reason": "gems"}
	if animals_for_map().size() >= MAX_ANIMALS:
		return {"ok": false, "reason": "farm_full"}
	gems -= MYSTERY_EGG_COST
	var breed_id: String = species_ids_for_map().pick_random()
	var tier := 1 if randf() < 0.70 else 2
	var egg_rare := randf() < 0.03
	var result := create_animal(breed_id, tier, {"x": opts.get("x", 50.0), "y": opts.get("y", 50.0), "force_rare": egg_rare, "force_normal": not egg_rare})
	result["ok"] = true
	result["egg_tier"] = tier
	return result

func hatch_shop_egg(egg_level: int, opts: Dictionary = {}) -> Dictionary:
	var level := clampi(egg_level, 1, MAX_TIER)
	var price := EggShop.price(level)
	if coins < price:
		return {"ok": false, "reason": "coins"}
	if animals_for_map().size() >= MAX_ANIMALS:
		return {"ok": false, "reason": "farm_full"}
	coins -= price
	var chicken_tier: int = EggDropRates.roll(level)
	var breed_id: String = species_ids_for_map().pick_random()
	var result := create_animal(breed_id, chicken_tier, {
		"x": opts.get("x", 50.0), "y": opts.get("y", 50.0),
	})
	result["ok"] = true
	result["egg_level"] = level
	result["chicken_tier"] = chicken_tier
	return result

# ---- tutorial ----
func energy_balance(now: int = -1) -> int:
	return play_progress.refresh_energy(int(Time.get_unix_time_from_system()) if now < 0 else now)

func spend_battle_energy(now: int = -1) -> Dictionary:
	var previous: Dictionary = play_progress.state.duplicate(true)
	if not play_progress.spend(int(Time.get_unix_time_from_system()) if now < 0 else now):
		return {"ok": false, "reason": "energy"}
	if not save_game():
		play_progress.state = previous
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "cost": PlayProgress.BATTLE_COST}

func save_battle_reward(owned_cells: int) -> Dictionary:
	# The arena owns the per-match claim guard; persist before reporting success.
	var prize: Dictionary = PlayProgress.battle_reward(owned_cells)
	var previous_coins := coins
	var previous_xp := xp
	coins += prize.gold
	xp += prize.xp
	if not save_game():
		coins = previous_coins
		xp = previous_xp
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "gold": prize.gold, "xp": prize.xp}

func daily_shop(now: int = -1) -> Dictionary:
	var previous: Dictionary = play_progress.state.duplicate(true)
	if play_progress.advance_shop(int(Time.get_unix_time_from_system()) if now < 0 else now):
		if not save_game():
			play_progress.state = previous
			return {}
	return play_progress.offers(current_planet, species_ids_for_map())

func purchase_daily_egg(level: int, offer_day: int) -> Dictionary:
	var offers := daily_shop()
	if offers.is_empty() or offers.day != offer_day or not offers.eggs.has(level): return {"ok": false, "reason": "offer_changed"}
	var previous := _shop_rollback_state()
	return _finish_shop_purchase(hatch_shop_egg(level), previous)

func purchase_daily_chicken(offer_id: String, offer_day: int) -> Dictionary:
	var offers := daily_shop()
	if offers.is_empty() or offers.day != offer_day: return {"ok": false, "reason": "offer_changed"}
	for offer in offers.chickens:
		if offer.id != offer_id: continue
		if coins < offer.price: return {"ok": false, "reason": "coins"}
		if animals_for_map().size() >= MAX_ANIMALS: return {"ok": false, "reason": "farm_full"}
		var previous := _shop_rollback_state()
		coins -= offer.price
		var result := create_animal(offer.species, int(offer.tier), {"force_normal": true, "x": randf_range(15, 85), "y": randf_range(20, 85)})
		result["ok"] = true
		return _finish_shop_purchase(result, previous)
	return {"ok": false, "reason": "offer_changed"}

func _shop_rollback_state() -> Dictionary:
	return {"coins": coins, "animals": animals.duplicate(true), "discovered": discovered.duplicate(true), "stats": stats.duplicate(true), "seq": _seq}

func _finish_shop_purchase(result: Dictionary, previous: Dictionary) -> Dictionary:
	if not result.get("ok", false): return result
	if save_game(): return result
	coins = previous.coins
	animals = previous.animals
	discovered = previous.discovered
	stats = previous.stats
	_seq = previous.seq
	return {"ok": false, "reason": "save_failed"}

func accept_tutorial_event(event_id: String, payload: Dictionary = {}) -> bool:
	var changed := tutorial_progress.accept_event(event_id, payload)
	if changed:
		save_game()
	return changed

func tutorial_step_id() -> String:
	return tutorial_progress.current_step_id()

func is_tutorial_active() -> bool:
	return tutorial_progress.is_active()

func skip_tutorial() -> bool:
	var changed := tutorial_progress.skip()
	if changed:
		save_game()
	return changed

func reset_tutorial_for_replay() -> void:
	tutorial_progress.reset_for_replay()
	save_game()

func tutorial_snapshot() -> Dictionary:
	return tutorial_progress.snapshot()

func claim_daily_reward() -> Dictionary:
	return _reward_transaction(false)

func complete_ad_reward(quote: Dictionary) -> Dictionary:
	if str(quote.get("kind", "")) == "gift" and energy_balance() >= PlayProgress.ENERGY_CAP:
		return {"ok": false, "reason": "energy_full"}
	return _reward_transaction(true, quote)

func _reward_transaction(ad: bool, quote: Dictionary = {}) -> Dictionary:
	var previous: Dictionary = reward_progress.snapshot()
	var previous_play_progress: Dictionary = play_progress.state.duplicate(true)
	var previous_coins := coins
	var previous_gems := gems
	var now := int(Time.get_unix_time_from_system())
	var result: Dictionary = reward_progress.complete_ad(quote, now) if ad else reward_progress.claim(now)
	if not result.ok: return result
	coins += int(result.reward.gold)
	gems += int(result.reward.gems)
	var granted_energy := play_progress.grant_energy(int(result.reward.get("energy", 0)))
	if result.reward.has("energy"): result.reward.energy = granted_energy
	if not save_game():
		reward_progress.restore(previous)
		play_progress.state = previous_play_progress
		coins = previous_coins
		gems = previous_gems
		return {"ok": false, "reason": "save_failed"}
	return result

# ---- save/load ----
const SAVE_PATH := "user://mutation_farm_save_v3.json"
const LEGACY_SAVE_PATH := "user://mutation_farm_save_v2.json"
const PLANET_EGG_PROGRESS_VERSION := 2
const LEGACY_BREED_MAP := {
	"nam_pet": "ga_ta_vang", "pet_cao": "ga_ac_den", "ran_hong_pet": "ga_ri_do", "tuyet_pet": "ga_silk_trang",
	"mouse": "ga_ta_vang", "piglet": "ga_ac_den", "chick": "ga_ri_do",
}

func save_game() -> bool:
	# An unreadable existing save is not permission to replace player progress.
	if _save_blocked:
		return false
	var data := {
		"save_version": 3, "coins": coins, "gems": gems, "dna": dna,
		"alien_dna": alien_dna, "mutation_materials": mutation_materials,
		"farm_level": farm_level, "xp": xp, "xp_to_next": xp_to_next,
		"animals": animals, "discovered": discovered, "stats": stats, "battle_team": battle_team,
		"farm_defense_damaged_until": farm_defense_damaged_until, "current_planet": current_planet,
		"adventure_chapter": adventure_chapter,
		"unopened_eggs": unopened_eggs, "egg_capacity_level": egg_capacity_level,
		"planet_egg_progress": planet_egg_progress,
		"planet_cannon_levels": planet_cannon_levels,
		"planet_egg_progress_version": PLANET_EGG_PROGRESS_VERSION,
		"tutorial_progress": tutorial_snapshot(),
		"reward_progress": reward_progress.snapshot(),
		"play_progress": play_progress.state.duplicate(true),
	}
	return SaveStore.write_snapshot(SAVE_PATH, data, _is_valid_save)

func load_game() -> bool:
	var parsed: Dictionary = {}
	var had_save := false
	_save_blocked = false
	save_load_status = "missing"
	for path in [SAVE_PATH, SAVE_PATH + ".bak", LEGACY_SAVE_PATH]:
		had_save = had_save or FileAccess.file_exists(path)
		parsed = SaveStore.read_snapshot(path, _is_valid_save)
		if not parsed.is_empty():
			save_load_status = "loaded" if path == SAVE_PATH else ("recovered" if path.ends_with(".bak") else "migrated")
			break
	if parsed.is_empty():
		_save_blocked = had_save
		save_load_status = "invalid" if had_save else "missing"
		if not had_save:
			tutorial_progress.reset_for_new_player()
			reward_progress.restore({})
			play_progress.restore({})
		return false
	coins = parsed.get("coins", coins)
	gems = parsed.get("gems", gems)
	dna = parsed.get("dna", dna)
	play_progress.restore(parsed.get("play_progress", {}), dna)
	alien_dna = parsed.get("alien_dna", alien_dna)
	mutation_materials = parsed.get("mutation_materials", mutation_materials)
	farm_level = parsed.get("farm_level", farm_level)
	xp = parsed.get("xp", xp)
	xp_to_next = parsed.get("xp_to_next", xp_to_next)
	animals = parsed.get("animals", [])
	discovered = parsed.get("discovered", [])
	stats = parsed.get("stats", stats)
	battle_team = parsed.get("battle_team", [])
	farm_defense_damaged_until = parsed.get("farm_defense_damaged_until", farm_defense_damaged_until)
	current_planet = parsed.get("current_planet", current_planet)
	adventure_chapter = parsed.get("adventure_chapter", adventure_chapter)
	unopened_eggs = parsed.get("unopened_eggs", [])
	egg_capacity_level = int(parsed.get("egg_capacity_level", 0))
	var saved_planet_progress: Dictionary = parsed.get("planet_egg_progress", {})
	var progress_version := int(parsed.get("planet_egg_progress_version", 0))
	if progress_version < PLANET_EGG_PROGRESS_VERSION:
		# Version 1 accidentally attached the old shared progression to whichever
		# planet happened to be open during migration. Preserve the strongest old
		# record as Earth/Farm progress and reset every other planet.
		var legacy_record := {
			"egg_upgrade_level": clampi(int(parsed.get("egg_upgrade_level", 0)), 0, 10),
			"delivery_level": maxi(0, int(parsed.get("delivery_level", 0))),
			"delivery_remaining": float(parsed.get("delivery_remaining", 0.0)),
		}
		var best_score := int(legacy_record.egg_upgrade_level) * 1000 + int(legacy_record.delivery_level)
		for map_id in saved_planet_progress:
			var candidate: Dictionary = saved_planet_progress[map_id]
			var score := int(candidate.get("egg_upgrade_level", 0)) * 1000 + int(candidate.get("delivery_level", 0))
			if score > best_score:
				best_score = score
				legacy_record = candidate.duplicate(true)
		var legacy_delivery_level := maxi(0, int(legacy_record.get("delivery_level", 0)))
		var legacy_remaining := float(legacy_record.get("delivery_remaining", 0.0))
		if legacy_remaining <= 0.0:
			legacy_remaining = FARM_CONFIG.delivery_interval(legacy_delivery_level)
		planet_egg_progress = {
			"earth": {
				"egg_upgrade_level": clampi(int(legacy_record.get("egg_upgrade_level", 0)), 0, 10),
				"delivery_level": legacy_delivery_level,
				"delivery_remaining": legacy_remaining,
			}
		}
	else:
		planet_egg_progress = saved_planet_progress.duplicate(true)
	for map_id in MAP_SPECIES:
		ensure_planet_egg_progress(map_id)
	planet_cannon_levels = parsed.get("planet_cannon_levels", {}).duplicate(true)
	for map_id in MAP_SPECIES:
		planet_cannon_levels[map_id] = clampi(int(planet_cannon_levels.get(map_id, 0)), 0, MAX_CANNON_LEVEL)
	_migrate_legacy_roster()
	# Existing saves predate onboarding and should not force veteran players
	# through a first-run flow. New installs are reset in the missing-save path.
	tutorial_progress.restore(parsed.get("tutorial_progress", {}), TutorialProgressState.MISSING_VETERAN)
	reward_progress.restore(parsed.get("reward_progress", {}))
	return true

func _is_valid_save(data: Dictionary) -> bool:
	if not data.has("coins") or not data.has("animals"):
		return false
	if not _save_number(data.get("save_version", 2), 2, 3):
		return false
	for key in ["coins", "gems", "dna", "alien_dna", "mutation_materials", "xp", "farm_defense_damaged_until", "egg_capacity_level"]:
		if not _save_number(data.get(key, 0)):
			return false
	for key in ["farm_level", "xp_to_next", "adventure_chapter"]:
		if not _save_number(data.get(key, 1), 1):
			return false
	if not data.get("current_planet", "earth") is String or not MAP_SPECIES.has(data.get("current_planet", "earth")):
		return false
	if not data.animals is Array or not data.get("unopened_eggs", []) is Array:
		return false
	var animal_ids: Dictionary = {}
	for animal in data.animals:
		if not animal is Dictionary or not animal.get("id") is String or str(animal.id).is_empty():
			return false
		if animal_ids.has(animal.id) or not _save_number(animal.get("tier"), 1, MAX_TIER):
			return false
		animal_ids[animal.id] = true
		if not animal.get("breed_id", animal.get("species_id", "")) is String:
			return false
		if animal.get("rarity", "normal") not in ["normal", "rare"]:
			return false
		for key in ["x", "y", "target_x", "target_y", "idle_until"]:
			if not _save_number(animal.get(key, 0)):
				return false
	var egg_ids: Dictionary = {}
	for egg in data.get("unopened_eggs", []):
		if not egg is Dictionary or not egg.get("id") is String or str(egg.id).is_empty():
			return false
		if egg_ids.has(egg.id) or not _save_number(egg.get("tier", 1), 1, MAX_TIER):
			return false
		egg_ids[egg.id] = true
		if not MAP_SPECIES.has(egg.get("map_id", "earth")):
			return false
		for key in ["x", "y", "created_at"]:
			if not _save_number(egg.get(key, 0)):
				return false
	for key in ["discovered", "battle_team"]:
		if not data.get(key, []) is Array:
			return false
		for value in data.get(key, []):
			if not value is String:
				return false
	if not data.get("stats", {}) is Dictionary or not data.get("planet_egg_progress", {}) is Dictionary:
		return false
	if not data.get("planet_cannon_levels", {}) is Dictionary:
		return false
	for map_id in data.get("planet_cannon_levels", {}):
		if not MAP_SPECIES.has(map_id) or not _save_number(data.planet_cannon_levels[map_id], 0, MAX_CANNON_LEVEL): return false
	for value in data.get("stats", {}).values():
		if not _save_number(value):
			return false
	if not _save_number(data.get("planet_egg_progress_version", 0), 0, PLANET_EGG_PROGRESS_VERSION):
		return false
	for record in data.get("planet_egg_progress", {}).values():
		if not record is Dictionary or not _valid_saved_progress(record):
			return false
	if data.has("tutorial_progress"):
		if not data.tutorial_progress is Dictionary or not TutorialProgressState.is_valid_snapshot(data.tutorial_progress):
			return false
	if data.has("reward_progress") and not RewardProgress.valid(data.reward_progress): return false
	if data.has("play_progress") and not PlayProgress.valid(data.play_progress): return false
	return _valid_saved_progress(data)

func _valid_saved_progress(record: Dictionary) -> bool:
	return _save_number(record.get("egg_upgrade_level", 0), 0, 10) \
		and _save_number(record.get("delivery_level", 0), 0, FARM_CONFIG.delivery_intervals.size() - 1) \
		and _save_number(record.get("delivery_remaining", 0))

func _save_number(value: Variant, minimum: float = 0.0, maximum: float = INF) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _migrate_legacy_roster() -> void:
	for animal in animals:
		var old_id: String = animal.get("breed_id", animal.get("species_id", "ga_ta_vang"))
		var breed_id: String = LEGACY_BREED_MAP.get(old_id, old_id)
		if species_index(breed_id) < 0:
			breed_id = "ga_ta_vang"
		animal["species_id"] = breed_id
		animal["breed_id"] = breed_id
		animal["type"] = type_id(breed_id, int(animal.get("tier", 1)))
		# Older snapshots omit transient movement state; never resume a held drag.
		animal["rarity"] = animal.get("rarity", "normal")
		animal["x"] = animal.get("x", 50.0)
		animal["y"] = animal.get("y", 50.0)
		animal["facing"] = animal.get("facing", 1)
		animal["walking"] = false
		animal["dragging"] = false
		animal["idle_until"] = 0
		animal["target_x"] = animal.x
		animal["target_y"] = animal.y
	stats.merge({"created": 0, "merges": 0, "rares": 0}, false)
	var migrated_discovered: Array = []
	for id in discovered:
		var mapped: String = id
		for old_id in LEGACY_BREED_MAP:
			if mapped.begins_with(old_id):
				mapped = LEGACY_BREED_MAP[old_id] + mapped.trim_prefix(old_id)
				break
		if not migrated_discovered.has(mapped):
			migrated_discovered.append(mapped)
	discovered = migrated_discovered

func init_demo_data() -> void:
	if animals.size() > 0:
		return
	create_animal("ga_ta_vang", 1, {"force_normal": true})
	create_animal("ga_ta_vang", 1, {"force_normal": true})
	create_animal("ga_ta_vang", 2, {"force_normal": true})
	create_animal("ga_ac_den", 1, {"force_normal": true})
	create_animal("ga_ri_do", 1, {"force_normal": true})
	create_animal("ga_silk_trang", 1, {"force_normal": true})
