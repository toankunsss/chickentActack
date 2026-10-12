extends Control
## Small deterministic paper confetti; no textures, timers or per-particle nodes.
var age := 2.0
var origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func burst(point: Vector2) -> void:
	origin = point
	age = 0.0
	queue_redraw()

func clear() -> void:
	age = 2.0
	queue_redraw()

func _process(delta: float) -> void:
	if age >= 1.4: return
	age += delta
	queue_redraw()

func _draw() -> void:
	if age >= 1.4: return
	var colors := [Color("ffc74e"), Color("8dd659"), Color("73d9ed"), Color("f59fc3")]
	for index in 28:
		var angle := PI + (index + 0.5) * PI / 28.0
		var velocity := Vector2.from_angle(angle) * (150.0 + (index % 5) * 35.0)
		var point := origin + velocity * age + Vector2(0, 200.0 * age * age)
		var color: Color = colors[index % colors.size()]
		color.a = minf(1.0, (1.4 - age) * 2.5)
		var tip := Vector2.from_angle(index + age * 5) * 5.0
		draw_line(point - tip, point + tip, color, 5.0, true)
