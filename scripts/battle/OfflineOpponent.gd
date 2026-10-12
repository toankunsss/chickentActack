extends RefCounted
## Offline adapter emits a self-contained match snapshot. No network or save writes.
const VERSION := 1
const MODES := ["EASY", "NORMAL", "HARD"]
const SCALE := [0.8, 1.0, 1.2]
const NAMES := ["Feather Squad", "Comet Crew", "Seed Slingers", "Crystal Flock", "Storm Wings"]

static func entry(game: Node, animal: Dictionary, scale: float = 1.0) -> Dictionary:
	var stats: Dictionary = game.tier_data(int(animal.tier))
	var rare := 1.05 if animal.get("rarity", "normal") == "rare" else 1.0
	return {"animal": animal.duplicate(true), "asset_id": game.creature_asset_id(animal),
		"hp": float(stats.hp) * rare * scale, "atk": float(stats.atk) * rare * scale, "range": int(stats.range)}

static func build(game: Node, difficulty: int, match_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	var level := clampi(difficulty, 0, 2)
	var players: Array = []
	var enemies: Array = []
	var seen: Dictionary = {}
	var enemy_power := 0
	for id in game.battle_team:
		var animal: Dictionary = game.find_animal(str(id))
		if animal.is_empty() or seen.has(id) or players.size() >= mini(15, game.team_capacity): continue
		seen[id] = true
		players.append(entry(game, animal))
		var enemy := {"species_id": game.SPECIES[rng.randi_range(0, 9)].id,
			"tier": int(animal.tier), "rarity": "normal"}
		enemies.append(entry(game, enemy, SCALE[level]))
		enemy_power += roundi(game.animal_power(enemy) * float(SCALE[level]))
	# Seeded formation variation; never modifies the player's saved roster.
	for index in range(enemies.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap: Dictionary = enemies[index]
		enemies[index] = enemies[other]
		enemies[other] = swap
	return {"version": VERSION, "mode": "offline", "seed": match_seed, "difficulty": MODES[level],
		"opponent": "AI · " + str(NAMES[rng.randi_range(0, NAMES.size() - 1)]),
		"opponent_power": enemy_power, "players": players, "enemies": enemies}
