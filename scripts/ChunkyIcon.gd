extends Control
## Simple hand-drawn vector icons (coin / gem / bolt) in the same
## thick-black-outline chunky-cartoon style as the rest of the UI —
## used instead of mismatched external icons for the HUD currencies.

@export var kind: String = "coin"  # "coin" | "gem" | "bolt"
@export var fill: Color = Color(1, 0.79, 0.25)
@export var outline: Color = Color(0.14, 0.1, 0.08)
@export var outline_width: float = 3.0

func _draw() -> void:
	var s: Vector2 = size
	match kind:
		"coin":
			var c := s / 2.0
			var r: float = min(s.x, s.y) / 2.0 - outline_width
			draw_circle(c, r, fill)
			draw_arc(c, r, 0, TAU, 48, outline, outline_width, true)
			draw_arc(c, r * 0.62, 0, TAU, 32, outline, outline_width * 0.8, true)
		"gem":
			var w := s.x
			var h := s.y
			var pts := PackedVector2Array([
				Vector2(w * 0.5, h * 0.04),
				Vector2(w * 0.92, h * 0.38),
				Vector2(w * 0.5, h * 0.96),
				Vector2(w * 0.08, h * 0.38),
			])
			draw_colored_polygon(pts, fill)
			var closed := pts
			closed.append(pts[0])
			draw_polyline(closed, outline, outline_width, true)
			draw_line(Vector2(w * 0.08, h * 0.38), Vector2(w * 0.92, h * 0.38), outline, outline_width * 0.6, true)
			draw_line(Vector2(w * 0.5, h * 0.04), Vector2(w * 0.5, h * 0.96), outline, outline_width * 0.5, true)
		"bolt":
			var w := s.x
			var h := s.y
			var pts := PackedVector2Array([
				Vector2(w * 0.58, h * 0.02),
				Vector2(w * 0.18, h * 0.58),
				Vector2(w * 0.46, h * 0.58),
				Vector2(w * 0.40, h * 0.98),
				Vector2(w * 0.86, h * 0.4),
				Vector2(w * 0.54, h * 0.4),
			])
			draw_colored_polygon(pts, fill)
			var closed := pts
			closed.append(pts[0])
			draw_polyline(closed, outline, outline_width, true)
