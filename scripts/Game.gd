extends Node
## Autoload singleton: game data, state, and core mechanics.
## Ported 1:1 from the HTML prototype's js/data.js + js/animals.js —
## same species, same evolution line, same merge/crossbreed numbers.

const RARE_MUTATION_CHANCE := 0.01
const MAX_TIER := 6
const BUY_STARTER_COST := 500
const MAX_ANIMALS := 40

# adj/rare_adj kept in Vietnamese, noun-first order ("Nấm Béo" not "Béo Nấm").
const EVOLUTION_LINE := [
	{"adj": "", "adj_slug": "", "rare_adj": "Lấp Lánh", "rare_slug": "shiny", "atk": 8, "hp": 40, "speed": 62},
	{"adj": "Béo", "adj_slug": "beo", "rare_adj": "Vàng", "rare_slug": "golden", "atk": 18, "hp": 95, "speed": 48},
	{"adj": "To", "adj_slug": "to", "rare_adj": "Pha Lê", "rare_slug": "crystal", "atk": 34, "hp": 190, "speed": 52},
	{"adj": "Ba Mắt", "adj_slug": "bamat", "rare_adj": "Neon", "rare_slug": "neon", "atk": 60, "hp": 380, "speed": 44},
	{"adj": "Ngoài Hành Tinh", "adj_slug": "hanhtinh", "rare_adj": "Vũ Trụ", "rare_slug": "vutru", "atk": 120, "hp": 640, "speed": 58},
	{"adj": "Hạt Nhân", "adj_slug": "hatnhan", "rare_adj": "Phóng Xạ", "rare_slug": "phongxa", "atk": 210, "hp": 1100, "speed": 40},
]

# Species render as the shared idle/walk sprite frames (Critter.gd), tinted
# per-species by hue (-1 = no tint, keep the original black/white line art).
const SPECIES := [
	{
		"id": "nam_pet", "noun": "Nấm", "label": "Nấm", "emoji": "🍄", "hue": 35.0,
	},
	{
		"id": "pet_cao", "noun": "Cáo Tím", "label": "Cáo Tím", "emoji": "🦊", "hue": 280.0,
	},
	{
		"id": "ran_hong_pet", "noun": "Rắn Hồng", "label": "Rắn Hồng", "emoji": "🐍", "hue": 330.0,
	},
	{
		"id": "tuyet_pet", "noun": "Tuyết", "label": "Tuyết", "emoji": "❄️", "hue": -1.0,
	},
]

const CROSSBREED_CHANCE_BY_TIER := {1: 0.70, 2: 0.55, 3: 0.40, 4: 0.25, 5: 0.12}

const RARE_HUE_BY_TIER := {1: 200.0, 2: 40.0, 3: 180.0, 4: 320.0, 5: 260.0, 6: 60.0}
const TIER_SCALE := [1.0, 1.1, 1.22, 1.36, 1.5, 1.66]

# ---- runtime state ----
var coins: float = 12450.0
var gems: int = 125
var dna: int = 240
var farm_level: int = 12
var xp: float = 30.0
var xp_to_next: float = 100.0
var animals: Array = []  # Array[Dictionary]
var discovered: Array = []  # ids, e.g. "mouse", "shiny_mouse"
var stats := {"created": 0, "merges": 0, "rares": 0}
var battle_team: Array = []  # animal ids — Battle screen not built yet, stays empty
var team_capacity: int = 15

var _seq := 1
var farm_size: Vector2 = Vector2(720, 900)

func species_index(species_id: String) -> int:
	for i in SPECIES.size():
		if SPECIES[i].id == species_id:
			return i
	return -1

func tier_name(species_id: String, tier: int) -> String:
	var sp = SPECIES[species_index(species_id)]
	var adj = EVOLUTION_LINE[tier - 1].adj
	return sp.noun + (" " + adj if adj != "" else "")

func tier_rare_name(species_id: String, tier: int) -> String:
	var sp = SPECIES[species_index(species_id)]
	var e = EVOLUTION_LINE[tier - 1]
	return sp.noun + (" " + e.adj if e.adj != "" else "") + " " + e.rare_adj

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
	var is_rare: bool
	if opts.get("force_rare", false):
		is_rare = true
	elif opts.get("force_normal", false):
		is_rare = false
	else:
		is_rare = randf() < RARE_MUTATION_CHANCE

	var animal := {
		"id": _next_id(),
		"tier": tier,
		"species_id": species_id,
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
	if b.is_empty() or b.tier != a.tier or a.tier >= MAX_TIER:
		return ""
	return "merge" if b.species_id == a.species_id else "crossbreed"

func merge_animals(id_a: String, id_b: String) -> Dictionary:
	var a = find_animal(id_a)
	var b = find_animal(id_b)
	if a.is_empty() or b.is_empty() or a.tier != b.tier or a.species_id != b.species_id or a.tier >= MAX_TIER:
		return {}
	var mid_x = (a.x + b.x) / 2.0
	var mid_y = (a.y + b.y) / 2.0
	remove_animals([id_a, id_b])
	stats.merges += 1
	return create_animal(a.species_id, a.tier + 1, {"x": mid_x, "y": mid_y})

func crossbreed_animals(id_a: String, id_b: String) -> Dictionary:
	var a = find_animal(id_a)
	var b = find_animal(id_b)
	if a.is_empty() or b.is_empty() or a.tier != b.tier or a.species_id == b.species_id or a.tier >= MAX_TIER:
		return {}
	var tier = a.tier
	var chance = CROSSBREED_CHANCE_BY_TIER.get(tier, 0.1)
	var success = randf() < chance
	var mid_x = (a.x + b.x) / 2.0
	var mid_y = (a.y + b.y) / 2.0
	remove_animals([id_a, id_b])
	stats.merges += 1
	if not success:
		return {"success": false, "chance": chance}
	var chosen = a.species_id if randf() < 0.5 else b.species_id
	var result = create_animal(chosen, tier + 1, {"x": mid_x, "y": mid_y})
	result["success"] = true
	return result

func display_name(animal: Dictionary) -> String:
	if animal.rarity == "rare":
		return tier_rare_name(animal.species_id, animal.tier)
	return tier_name(animal.species_id, animal.tier)

func passive_income() -> int:
	var total := 0
	for a in animals:
		total += a.tier * 2 + (1 if a.rarity == "rare" else 0)
	return total

# ---- save/load ----
const SAVE_PATH := "user://mutation_farm_save_v2.json"  # v2: pet species (old saves used mouse/piglet/chick)

func save_game() -> void:
	var data := {
		"coins": coins, "gems": gems, "dna": dna,
		"farm_level": farm_level, "xp": xp, "xp_to_next": xp_to_next,
		"animals": animals, "discovered": discovered, "stats": stats,
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	coins = parsed.get("coins", coins)
	gems = parsed.get("gems", gems)
	dna = parsed.get("dna", dna)
	farm_level = parsed.get("farm_level", farm_level)
	xp = parsed.get("xp", xp)
	xp_to_next = parsed.get("xp_to_next", xp_to_next)
	animals = parsed.get("animals", [])
	discovered = parsed.get("discovered", [])
	stats = parsed.get("stats", stats)
	return true

func init_demo_data() -> void:
	if animals.size() > 0:
		return
	create_animal("nam_pet", 1, {"force_normal": true})
	create_animal("nam_pet", 1, {"force_normal": true})
	create_animal("nam_pet", 1, {"force_normal": true})
	create_animal("nam_pet", 2, {"force_normal": true})
	create_animal("pet_cao", 1, {"force_normal": true})
	create_animal("ran_hong_pet", 1, {"force_normal": true})
	create_animal("tuyet_pet", 1, {"force_normal": true})
