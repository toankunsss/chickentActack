extends Control
var friendly := true
var selected := false

func _draw() -> void:
	draw_set_transform(size * 0.5, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, size.x * 0.46, Color(0.12, 0.20, 0.13, 0.22))
	if selected:
		draw_arc(Vector2.ZERO, size.x * 0.46, 0, TAU, 32, Color("fff2a4"), 4, true)
	else:
		draw_arc(Vector2.ZERO, size.x * 0.46, 0, TAU, 24, Color("78cbd9") if friendly else Color("efab83"), 2, true)
