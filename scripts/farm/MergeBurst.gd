class_name MergeBurst
extends Node2D

var color := Color("ffd84d")
var duration := 1.05
var elapsed := 0.0

func setup(burst_color: Color = Color("ffd84d")) -> void:
	color = burst_color
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var pulse := sin(t * PI)
	var outer_radius := lerpf(18.0, 105.0, t)
	var inner_radius := lerpf(10.0, 58.0, minf(1.0, t * 1.8))
	var fade := 1.0 - t
	draw_circle(Vector2.ZERO, inner_radius, Color(color, 0.14 * pulse))
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 64, Color(color, 0.85 * fade), 8.0)
	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 48, Color.WHITE, 5.0 * fade)
	for i in 12:
		var angle := TAU * float(i) / 12.0 + t * 1.6
		var start := Vector2.from_angle(angle) * lerpf(20.0, 55.0, t)
		var end := Vector2.from_angle(angle) * lerpf(48.0, 130.0, t)
		draw_line(start, end, Color(color, 0.9 * fade), 5.0)
	for i in 6:
		var angle := TAU * float(i) / 6.0 - t * 2.2
		var star_pos := Vector2.from_angle(angle) * lerpf(25.0, 82.0, pulse)
		draw_circle(star_pos, 5.0 + pulse * 4.0, Color.WHITE, true)
