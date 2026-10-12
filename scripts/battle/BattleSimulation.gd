extends RefCounted
## Fixed-step combat. No scene, clocks, saves, or global RNG; replayable with a seed.
const SKILLS = preload("res://scripts/battle/BattleSkillCatalog.gd")
const ROWS := 11
const COLUMNS := 3
const STEP := 0.1
const DURATION := 30.0
var units: Array[Dictionary] = []
var events: Array[Dictionary] = []
var territory: Array[int] = []
var remaining := DURATION
var elapsed := 0.0
var running := false
var result := ""
var player_hearts := 3
var enemy_hearts := 3
var accumulator := 0.0
var ticks := 0
var rng := RandomNumberGenerator.new()
var totals: Dictionary = {}
var board_rows := ROWS

func setup(players: Array, enemies: Array, match_seed: int = 1) -> void:
	units.clear()
	events.clear()
	territory.clear()
	remaining = DURATION
	elapsed = 0.0
	accumulator = 0.0
	ticks = 0
	result = ""
	totals = {1: {"damage": 0.0, "casts": 0, "kills": 0}, -1: {"damage": 0.0, "casts": 0, "kills": 0}}
	player_hearts = 3
	enemy_hearts = 3
	rng.seed = match_seed
	board_rows = clampi(ceili(float(maxi(players.size(), enemies.size())) / COLUMNS) * 2 + 1, 7, ROWS)
	var middle := board_rows / 2
	for row in board_rows:
		for column in COLUMNS:
			territory.append(1 if row > middle else (-1 if row < middle else 0))
	for side in [1, -1]:
		var roster: Array = players if side == 1 else enemies
		for index in mini(roster.size(), 15):
			var entry: Dictionary = roster[index]
			var row := board_rows - 1 - index / COLUMNS if side == 1 else index / COLUMNS
			var skill := SKILLS.for_id(int(entry.asset_id))
			units.append({"uid": ("p" if side == 1 else "e") + str(index), "animal": entry.animal.duplicate(true),
				"side": side, "row": row, "column": index % COLUMNS, "hp": float(entry.hp), "max_hp": float(entry.hp),
				"atk": float(entry.atk), "range": int(entry.range), "skill": skill,
				"cooldown": rng.randf_range(0.8, 1.8), "action": 0.0, "statuses": {}, "shield": 0.0,
				"shield_time": 0.0, "animation": "bounce", "animation_time": 0.0, "casts": 0})
	running = not players.is_empty() and not enemies.is_empty()
	if not running: result = "invalid"

func advance(delta: float) -> void:
	if not running or delta <= 0.0: return
	accumulator += delta
	while accumulator + 0.000001 >= STEP and running:
		accumulator -= STEP
		_tick()

func drain_events() -> Array[Dictionary]:
	var output := events.duplicate()
	events.clear()
	return output

func _tick() -> void:
	ticks += 1
	elapsed = ticks * STEP
	remaining = maxf(0.0, DURATION - elapsed)
	# Alternating initiative avoids always giving the player's first row first hit.
	var order := units.duplicate()
	if ticks % 2 == 0: order.reverse()
	for unit in order:
		if unit.hp <= 0.0: continue
		_update_statuses(unit)
		if unit.hp <= 0.0: continue
		unit.animation_time = maxf(0.0, float(unit.animation_time) - STEP)
		unit.cooldown = maxf(0.0, float(unit.cooldown) - STEP)
		var pace := 0.6 if unit.statuses.has("slow") else 1.0
		if unit.statuses.has("haste"): pace *= 1.35
		unit.action = maxf(0.0, float(unit.action) - STEP * pace)
		if unit.statuses.has("stun"): continue
		var targets := enemies_in_range(unit, int(unit.skill.range))
		if unit.cooldown <= 0.0 and not targets.is_empty():
			cast(unit, targets)
			continue
		if unit.action > 0.0: continue
		var nearby := enemies_in_range(unit, int(unit.range))
		if not nearby.is_empty():
			_damage(unit, nearby[0], float(unit.atk), "basic")
			unit.animation = "attack"
			unit.animation_time = 0.45
			unit.action = 0.8
		else:
			_move(unit)
			unit.action = 0.65
	units = units.filter(func(unit): return unit.hp > 0.0)
	var allies := units.filter(func(unit): return unit.side == 1)
	var enemies := units.filter(func(unit): return unit.side == -1)
	if remaining <= 0.0 or allies.is_empty() or enemies.is_empty() or player_hearts <= 0 or enemy_hearts <= 0:
		running = false
		var score_a := _score(1)
		var score_b := _score(-1)
		result = "draw" if is_equal_approx(score_a, score_b) else ("victory" if score_a > score_b else "defeat")

func _score(side: int) -> float:
	var hearts := player_hearts if side == 1 else enemy_hearts
	if hearts <= 0: return -1.0
	var alive := units.filter(func(unit): return unit.side == side and unit.hp > 0.0)
	if alive.is_empty(): return 0.0
	var score := float(hearts * 10000 + alive.size() * 100)
	for unit in alive: score += float(unit.hp) / float(unit.max_hp) * 10.0
	return score + float(territory.count(side)) * 0.01

func _update_statuses(unit: Dictionary) -> void:
	for key in unit.statuses.keys():
		var status: Dictionary = unit.statuses[key]
		if key in ["burn", "poison"]:
			_take_damage(unit, float(status.damage) * minf(STEP, status.time), int(status.get("source_side", -int(unit.side))))
		status.time -= STEP
		if status.time <= 0.00001: unit.statuses.erase(key)
	unit.shield_time = maxf(0.0, float(unit.shield_time) - STEP)
	if unit.shield_time <= 0.0: unit.shield = 0.0

func distance(a: Dictionary, b: Dictionary) -> int:
	return absi(int(a.row) - int(b.row)) + absi(int(a.column) - int(b.column))

func enemies_in_range(unit: Dictionary, reach: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for other in units:
		if other.side != unit.side and other.hp > 0.0 and distance(unit, other) <= reach: found.append(other)
	found.sort_custom(func(a, b): return distance(unit, a) < distance(unit, b) if distance(unit, a) != distance(unit, b) else str(a.uid) < str(b.uid))
	return found

func cast(unit: Dictionary, candidates: Array[Dictionary]) -> void:
	if unit.hp <= 0.0 or candidates.is_empty() or unit.cooldown > 0.0 or unit.statuses.has("stun"): return
	var skill: Dictionary = unit.skill
	var primary: Dictionary = candidates[0]
	var selected: Array[Dictionary] = []
	match str(skill.pattern):
		"snipe":
			for other in candidates:
				if float(other.hp) / float(other.max_hp) < float(primary.hp) / float(primary.max_hp): primary = other
			selected.append(primary)
		"burst": selected.assign([primary, primary, primary])
		"volley":
			for index in 3: selected.append(candidates[index % candidates.size()])
		"blast", "meteor":
			for other in units:
				if other.side != unit.side and other.hp > 0.0 and distance(primary, other) <= (2 if skill.pattern == "meteor" else 1): selected.append(other)
		"beam":
			for other in candidates:
				if other.column == primary.column: selected.append(other)
		"wave":
			for other in candidates:
				if (int(unit.row) - int(other.row)) * int(unit.side) >= 0: selected.append(other)
		"nova": selected.assign(candidates)
		"chain":
			selected.append(primary)
			for other in candidates:
				if selected.size() < 3 and other != primary: selected.append(other)
		"orbit": selected.assign(candidates.slice(0, 2))
		_: selected.append(primary)
	if selected.is_empty(): selected.append(primary)
	var destinations: Array[Vector2] = []
	var total_damage := 0.0
	for target in selected:
		if target.hp <= 0.0: continue
		var amount := float(unit.atk) * float(skill.power)
		if skill.effect == "execute" and target.hp < target.max_hp * 0.35: amount *= 1.5
		total_damage += _damage(unit, target, amount, "skill")
		destinations.append(Vector2(target.column, target.row))
		if target.hp > 0.0:
			match str(skill.effect):
				"burn", "poison":
					var dps := float(unit.atk) * (0.18 if skill.effect == "burn" else 0.12)
					var previous: Dictionary = target.statuses.get(skill.effect, {})
					target.statuses[skill.effect] = {"time": 3.0 if skill.effect == "burn" else 5.0, "damage": maxf(dps, float(previous.get("damage", 0.0))), "source_side": int(unit.side)}
				"slow", "stun", "weaken":
					target.statuses[skill.effect] = {"time": {"slow": 2.0, "stun": 0.6, "weaken": 3.0}[skill.effect]}
	match str(skill.effect):
		"heal":
			var ally := unit
			for other in units:
				if other.side == unit.side and other.hp > 0.0 and float(other.hp) / float(other.max_hp) < float(ally.hp) / float(ally.max_hp): ally = other
			ally.hp = minf(ally.max_hp, ally.hp + unit.atk * 1.2)
			events.append({"type": "heal", "from": Vector2(unit.column, unit.row), "to": [Vector2(ally.column, ally.row)], "skill": skill, "side": unit.side})
		"shield":
			unit.shield = minf(unit.max_hp * 0.5, unit.atk * 1.5)
			unit.shield_time = 4.0
		"haste": unit.statuses["haste"] = {"time": 3.0}
		"drain": unit.hp = minf(unit.max_hp, unit.hp + total_damage * 0.35)
	unit.cooldown = skill.cooldown
	unit.action = 0.5
	unit.casts += 1
	totals[int(unit.side)].casts += 1
	unit.animation = "attack"
	unit.animation_time = 0.55
	events.append({"type": "cast", "uid": unit.uid, "from": Vector2(unit.column, unit.row), "to": destinations, "skill": skill, "side": unit.side})

func _damage(source: Dictionary, target: Dictionary, amount: float, kind: String) -> float:
	if source.statuses.has("weaken"): amount *= 0.75
	var dealt := _take_damage(target, amount, int(source.side))
	target.animation = "hit"
	target.animation_time = 0.3
	if kind == "basic": events.append({"type": "basic", "from": Vector2(source.column, source.row), "to": [Vector2(target.column, target.row)], "side": source.side, "skill": source.skill})
	return dealt

func _take_damage(target: Dictionary, amount: float, source_side: int) -> float:
	if target.hp <= 0.0: return 0.0
	var absorbed := minf(float(target.shield), amount)
	target.shield -= absorbed
	var dealt := minf(float(target.hp), amount - absorbed)
	target.hp = maxf(0.0, float(target.hp) - dealt)
	totals[source_side].damage += dealt
	if target.hp <= 0.0:
		totals[source_side].kills += 1
		territory[int(target.row) * COLUMNS + int(target.column)] = source_side
	return dealt

func _move(unit: Dictionary) -> void:
	var foes := enemies_in_range(unit, ROWS + COLUMNS)
	var goal := Vector2i(int(unit.column), int(unit.row) - int(unit.side))
	if not foes.is_empty():
		var foe: Dictionary = foes[0]
		var dr := signi(int(foe.row) - int(unit.row))
		var dc := signi(int(foe.column) - int(unit.column))
		var options: Array[Vector2i] = []
		if dr != 0: options.append(Vector2i(unit.column, int(unit.row) + dr))
		if dc != 0: options.append(Vector2i(int(unit.column) + dc, unit.row))
		for option in options:
			if not _occupied(option): goal = option; break
		if options.is_empty() or _occupied(goal): return
	if goal.y < 0 or goal.y >= board_rows:
		if unit.side == 1: enemy_hearts = maxi(0, enemy_hearts - 1)
		else: player_hearts = maxi(0, player_hearts - 1)
		unit.hp = 0.0
		return
	if goal.x < 0 or goal.x >= COLUMNS or _occupied(goal): return
	unit.row = goal.y
	unit.column = goal.x
	territory[goal.y * COLUMNS + goal.x] = int(unit.side)

func _occupied(point: Vector2i) -> bool:
	return units.any(func(unit): return unit.hp > 0.0 and unit.row == point.y and unit.column == point.x)
