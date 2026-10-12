extends SceneTree
const SIM = preload("res://scripts/battle/BattleSimulation.gd")
const SKILLS = preload("res://scripts/battle/BattleSkillCatalog.gd")
const OFFLINE = preload("res://scripts/battle/OfflineOpponent.gd")
var checks := 0
var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmBattleQA/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func entry(id: int, scaled := false) -> Dictionary:
	var animal := {"species_id": game.SPECIES[(id - 1) % 10].id, "tier": (id - 1) / 10 + 1, "rarity": "normal"}
	var stats: Dictionary = game.tier_data(animal.tier)
	return {"animal": animal, "asset_id": id, "hp": float(stats.hp) if scaled else 10000.0, "atk": float(stats.atk) if scaled else 100.0, "range": stats.range}

func duel(id: int) -> RefCounted:
	var sim := SIM.new()
	sim.setup([entry(id)], [entry(1), entry(2), entry(3)], 42)
	var caster: Dictionary = sim.units[0]
	caster.row = 5
	caster.column = 1
	caster.cooldown = 0.0
	caster.hp = 5000.0
	for index in range(1, sim.units.size()):
		sim.units[index].row = 4
		sim.units[index].column = index - 1
	return sim

func run() -> void:
	game = root.get_node("Game")
	var unique: Dictionary = {}
	check(SKILLS.MOVES.size() == 100, "All 100 collection characters have moves")
	check(SKILLS.for_id(43).visual == "ice" and SKILLS.for_id(43).effect == "slow", "Ice shards retain slow gameplay")
	check(SKILLS.for_id(42).visual == "water" and SKILLS.for_id(42).effect == "heal", "Water appearance independent of heal mechanic")
	check(SKILLS.for_id(41).visual == "fire" and SKILLS.for_id(44).visual == "lightning", "Fire and lightning are distinct shapes")
	var ice := duel(43)
	ice._damage(ice.units[0], ice.units[1], 10.0, "basic")
	check(ice.events.back().skill.visual == "ice", "Ice basic attack also carries ice visuals")
	for id in range(1, 101):
		var skill := SKILLS.for_id(id)
		check(not unique.has(skill.name), "Unique skill name %d" % id)
		unique[skill.name] = true
		check(game.creature_asset_id(entry(id).animal) == id, "Correct species/tier mapping %d" % id)
		check(skill.cooldown >= 4.0 and skill.range > 0 and skill.power > 0.0, "Valid combat configuration %d" % id)
		var sim := duel(id)
		var caster: Dictionary = sim.units[0]
		var target: Dictionary = sim.units[2]
		var before := float(target.hp)
		var own_hp := float(caster.hp)
		sim.cast(caster, sim.enemies_in_range(caster, skill.range))
		check(caster.casts == 1 and is_equal_approx(caster.cooldown, skill.cooldown), "Cast starts full cooldown %d" % id)
		check(sim.events.any(func(event): return event.type == "cast" and event.skill.id == id), "Matching visual event %d" % id)
		check(sim.units.any(func(unit): return unit.side == -1 and unit.hp < unit.max_hp), "Skill actually damages enemy %d" % id)
		check(caster.hp >= own_hp, "No friendly fire %d" % id)
		var hp_snapshot := float(target.hp)
		sim.cast(caster, sim.enemies_in_range(caster, skill.range))
		check(caster.casts == 1 and target.hp == hp_snapshot, "Cannot bypass cooldown %d" % id)
		match str(skill.effect):
			"burn", "poison", "slow", "stun", "weaken":
				check(sim.units.any(func(unit): return unit.side == -1 and unit.statuses.has(skill.effect)), "Applies %s for %d" % [skill.effect, id])
			"heal", "drain": check(caster.hp > own_hp and caster.hp <= caster.max_hp, "Healing bounded %d" % id)
			"shield": check(caster.shield > 0.0 and caster.shield_time == 4.0, "Shield active %d" % id)
			"haste": check(caster.statuses.has("haste"), "Haste active %d" % id)
			"execute": check(target.hp < before, "Execute hit %d" % id)
		# Expiry must not stick around or leave negative shield/HP after ticks.
		for unit in sim.units: unit.action = 100.0; unit.cooldown = 100.0
		sim.advance(6.0)
		for unit in sim.units:
			check(unit.hp >= 0.0 and unit.hp <= unit.max_hp and unit.shield >= 0.0, "Bounded health %d" % id)
			check(unit.statuses.is_empty() and unit.shield == 0.0, "Statuses expire %d" % id)
	_status_contracts()
	_offline_contracts()
	# Exercise real movement/targeting at every tier, reproducible across render rates.
	for tier in range(10):
		var players: Array = []
		var enemies: Array = []
		for lineage in range(10):
			players.append(entry(tier * 10 + lineage + 1, true))
			enemies.append(entry(tier * 10 + (lineage + 3) % 10 + 1, true))
		var a := SIM.new()
		var b := SIM.new()
		a.setup(players, enemies, 100 + tier)
		b.setup(players, enemies, 100 + tier)
		for frame in 1800:
			a.advance(1.0 / 60.0)
			var occupied: Dictionary = {}
			for unit in a.units:
				var key := "%d:%d" % [unit.row, unit.column]
				check(not occupied.has(key), "No overlapping units tier %d" % (tier + 1))
				occupied[key] = true
				check(unit.row >= 0 and unit.row < SIM.ROWS and unit.column >= 0 and unit.column < SIM.COLUMNS, "Unit stays on board")
			if not a.running: break
		b.advance(30.0)
		check(not a.running and a.result in ["victory", "defeat", "draw"], "Match ends tier %d" % (tier + 1))
		check(a.result == b.result and a.units == b.units, "Deterministic across timestep size tier %d" % (tier + 1))
		check(a.events.any(func(event): return event.type == "cast"), "Auto casts in live match")
	var full := SIM.new()
	var fifteen: Array = []
	for id in range(1, 16): fifteen.append(entry(id))
	full.setup(fifteen, fifteen, 1)
	check(full.units.size() == 30, "All 15 selected creatures spawn on each side")
	var occupied: Dictionary = {}
	for unit in full.units:
		var key := "%d:%d" % [unit.row, unit.column]
		check(not occupied.has(key), "15 vs 15 initial placement distinct")
		occupied[key] = true
	full.setup([], fifteen)
	check(not full.running and full.result == "invalid", "Empty roster cannot farm rewards")
	var file := FileAccess.open("res://qa/battle-skill-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "100 skills, status contracts, ten tiers, deterministic simulation, 15 vs 15"}, "\t"))
	file.close()
	if failures.is_empty(): print("BATTLE_SKILL_REGRESSION_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)

func _status_contracts() -> void:
	var sim := duel(1)
	var attacker: Dictionary = sim.units[0]
	var target: Dictionary = sim.units[2]
	target.shield = 150.0
	target.shield_time = 4.0
	var hp := float(target.hp)
	check(sim._damage(attacker, target, 100.0, "basic") == 0.0 and target.hp == hp and target.shield == 50.0, "Shield absorbs before HP")
	check(sim._damage(attacker, target, 100.0, "basic") == 50.0 and target.hp == hp - 50.0, "Shield overflow damages HP")
	attacker.statuses.weaken = {"time": 3.0}
	check(sim._damage(attacker, target, 100.0, "basic") == 75.0, "Weaken reduces damage 25 percent")
	attacker.statuses.stun = {"time": 0.6}
	sim.cast(attacker, sim.enemies_in_range(attacker, 4))
	check(attacker.casts == 0, "Stun prevents casting")
	attacker.action = 0.0
	var before := Vector2(attacker.column, attacker.row)
	sim.advance(0.3)
	check(Vector2(attacker.column, attacker.row) == before and attacker.casts == 0, "Stun blocks actions")

func _offline_contracts() -> void:
	game.animals.clear()
	game.battle_team.clear()
	for id in range(1, 16):
		var animal: Dictionary = game.create_animal(game.SPECIES[(id - 1) % 10].id, 5, {"force_normal": true}).animal
		game.battle_team.append(animal.id)
	var before: Array = game.animals.duplicate(true)
	var coins: float = game.coins
	var a := OFFLINE.build(game, 1, 456)
	var b := OFFLINE.build(game, 1, 456)
	check(a == b, "Offline preview deterministic with same seed")
	check(a.enemies.size() == 15 and a.players.size() == 15, "AI adapts to selected team size")
	check(a.enemies != OFFLINE.build(game, 1, 457).enemies, "New AI seed changes composition")
	var easy := OFFLINE.build(game, 0, 456)
	var hard := OFFLINE.build(game, 2, 456)
	for index in 15:
		check(easy.enemies[index].hp < a.enemies[index].hp and hard.enemies[index].hp > a.enemies[index].hp, "Difficulty changes actual HP")
		check(easy.enemies[index].atk < a.enemies[index].atk and hard.enemies[index].atk > a.enemies[index].atk, "Difficulty changes actual ATK")
	check(game.animals == before and game.coins == coins, "Generating AI does not mutate farm or wallet")
	var transported: Dictionary = JSON.parse_string(JSON.stringify(a))
	var original := SIM.new()
	var decoded := SIM.new()
	original.setup(a.players, a.enemies, a.seed)
	decoded.setup(transported.players, transported.enemies, int(transported.seed))
	original.advance(30.0)
	decoded.advance(30.0)
	check(original.result == decoded.result and original.totals == decoded.totals, "Serialized offline snapshot preserves combat result")
	game.battle_team.append(game.battle_team[0])
	game.battle_team.append("missing-animal")
	check(OFFLINE.build(game, 1, 456).players.size() == 15, "Invalid/duplicate team IDs cannot add extra fighters")
