extends Control
## Lightweight runtime vector effects: no texture sheet or per-frame node churn.
var active: Array[Dictionary] = []

func clear() -> void:
	active.clear()
	queue_redraw()

func play(event: Dictionary, origin: Vector2, targets: Array[Vector2]) -> void:
	if active.size() >= 48: active.pop_front()
	active.append({"event": event, "origin": origin, "targets": targets, "age": 0.0})
	queue_redraw()

func _process(delta: float) -> void:
	if active.is_empty(): return
	for effect in active: effect.age += delta
	active = active.filter(func(effect): return effect.age < 0.65)
	queue_redraw()

func _draw() -> void:
	for effect in active:
		var event: Dictionary = effect.event
		var t := clampf(float(effect.age) / 0.65, 0.0, 1.0)
		var origin: Vector2 = effect.origin
		var skill: Dictionary = event.get("skill", {})
		var motif := str(skill.get("visual", "energy"))
		var color := Color(skill.get("color", Color("fff0b5")))
		color.a = 1.0 - t * 0.7
		var pattern := "bolt" if event.type == "basic" else str(event.skill.pattern)
		if event.type == "heal":
			for target in effect.targets:
				draw_arc(target, 10 + t * 22, 0, TAU, 24, Color("79d58c"), 3, true)
				draw_line(target + Vector2(-8, 0), target + Vector2(8, 0), color, 4, true)
				draw_line(target + Vector2(0, -8), target + Vector2(0, 8), color, 4, true)
			continue
		if pattern in ["nova", "orbit", "wave"]:
			draw_arc(origin, 12 + t * 65, 0, TAU, 40, color, 4, true)
		var previous := origin
		var index := 0
		for target in effect.targets:
			var start := previous if pattern == "chain" else origin
			var travel := clampf(t * 1.8 - index * 0.08, 0.0, 1.0)
			var point: Vector2 = start.lerp(target, travel)
			if motif == "lightning":
				_lightning(start, target, color, t)
			elif pattern in ["beam", "snipe", "chain"] and motif != "ice":
				draw_line(start, target, Color(color, color.a * 0.35), 10, true)
				draw_line(start, target, color, 3, true)
			elif pattern == "meteor":
				point = (target + Vector2(35, -90)).lerp(target, travel)
				draw_line(point + Vector2(14, -30), point, color, 8, true)
			else:
				if pattern in ["volley", "burst", "orbit"]: point.x += sin(travel * PI) * (index - 1) * 16
				draw_line(start.lerp(point, 0.8), point, Color(color, color.a * 0.5), 4, true)
			var direction: Vector2 = (target - start).normalized()
			var radius := (22.0 if event.type != "basic" else 11.0) if motif == "ice" else (14.0 if event.type != "basic" else 8.0)
			_projectile(motif, point, direction, radius, color, t)
			if travel >= 0.9:
				if motif == "ice":
					_snowflake(target, 15 + (t - 0.5) * 36, color)
				else:
					draw_arc(target, 7 + (t - 0.5) * 34, 0, TAU, 20, color, 3, true)
			previous = target
			index += 1

func _projectile(motif: String, point: Vector2, direction: Vector2, radius: float, color: Color, time: float) -> void:
	var side := direction.orthogonal()
	match motif:
		"ice":
			for n in 3:
				var tail := point - direction * (radius + n * 10)
				draw_line(tail - side * (n + 2), tail + side * (n + 2), Color(color, 0.5 - n * 0.12), 3, true)
			var points := PackedVector2Array([point + direction * radius, point + side * radius * 0.45, point - direction * radius, point - side * radius * 0.45])
			draw_colored_polygon(points, color)
			points.append(points[0])
			draw_polyline(points, Color("2379b4"), 2, true)
			draw_line(point - direction * radius * 0.65, point + direction * radius * 0.7, Color("efffff"), 3, true)
		"fire":
			var points := PackedVector2Array([point + direction * radius, point + side * radius * 0.6, point - direction * radius * 2 + side * radius * 0.4, point - direction * radius, point - direction * radius * 1.8 - side * radius * 0.5, point - side * radius * 0.6])
			draw_colored_polygon(points, color)
			draw_circle(point, radius * 0.45, Color("fff3a0"))
		"water":
			for n in 3:
				draw_arc(point - direction * n * 9, radius + n * 3, direction.angle() - 1.2, direction.angle() + 1.2, 16, color, 4, true)
			draw_circle(point + side * radius, 3, Color("dcfaff"))
		"leaf":
			var points := PackedVector2Array([point + direction * radius, point + side * radius * 0.55, point - direction * radius, point - side * radius * 0.55])
			draw_colored_polygon(points, color)
			draw_line(points[0], points[2], Color("39713b"), 2, true)
		"rock":
			var points := PackedVector2Array()
			for n in 6: points.append(point + Vector2.from_angle(n * TAU / 6.0 + time) * radius * (0.8 if n % 2 else 1.0))
			draw_colored_polygon(points, color)
			points.append(points[0])
			draw_polyline(points, Color("655044"), 3, true)
		"wind":
			for n in 3: draw_arc(point + direction * n * 7, radius - n * 2, time * TAU, time * TAU + PI * 1.4, 16, color, 3, true)
		"lightning":
			draw_circle(point, radius * 0.4, Color("fff9d4"))
		_:
			draw_circle(point, radius * 0.5, Color("51321e"))
			draw_circle(point, radius * 0.35, color)

func _snowflake(center: Vector2, radius: float, color: Color) -> void:
	for n in 6:
		var direction := Vector2.from_angle(n * TAU / 6.0)
		var tip := center + direction * radius
		draw_line(center, tip, color, 2, true)
		for sign_value in [-1, 1]:
			draw_line(center + direction * radius * 0.55, tip + direction.orthogonal() * radius * 0.22 * sign_value, color, 2, true)

func _lightning(start: Vector2, target: Vector2, color: Color, time: float) -> void:
	var points := PackedVector2Array([start])
	var side := (target - start).normalized().orthogonal()
	for n in range(1, 8): points.append(start.lerp(target, n / 8.0) + side * sin(n * 4.3 + floor(time * 12)) * 12)
	points.append(target)
	draw_polyline(points, Color(color, 0.3), 9, true)
	draw_polyline(points, color, 3, true)
