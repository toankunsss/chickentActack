extends Control
## Project-local sprite wrapper for the boss-raid cannon, with a short firing flash.

const CANNON_TEXTURE := preload("res://assets/ui/raid-cannon.png")

var firing := false
var entrance_glow := 0.0

func _draw() -> void:
	if entrance_glow > 0.0:
		var platform_center := Vector2(size.x * 0.5, size.y * 0.58)
		draw_circle(platform_center, 46.0 + entrance_glow * 18.0, Color(0.12, 0.66, 1.0, 0.18 * entrance_glow))
		draw_arc(platform_center, 76.0, 0.0, TAU, 48, Color(0.35, 0.88, 1.0, 0.78 * entrance_glow), 3.0, true)
	if firing:
		var muzzle := Vector2(size.x * 0.5, size.y * 0.22)
		var beam_end_y := -size.y
		var boss_group := get_parent().get_node_or_null("RaidBossGroup") as Control
		if boss_group != null:
			beam_end_y = boss_group.position.y + 140.0 - position.y
		var beam_end := Vector2(muzzle.x, beam_end_y)
		draw_line(muzzle, beam_end, Color(0.10, 0.58, 1.0, 0.18), 34.0, true)
		draw_line(muzzle, beam_end, Color(0.30, 0.84, 1.0, 0.55), 16.0, true)
		draw_line(muzzle, beam_end, Color("e9ffff"), 5.0, true)
	var texture_size := Vector2(CANNON_TEXTURE.get_size())
	var scale_factor := minf(size.x / texture_size.x, size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	var draw_position := (size - draw_size) * 0.5
	draw_texture_rect(CANNON_TEXTURE, Rect2(draw_position, draw_size), false)
	if firing:
		var muzzle := Vector2(size.x * 0.5, size.y * 0.22)
		draw_circle(muzzle, size.x * 0.10, Color(0.10, 0.72, 1.0, 0.40))
		draw_colored_polygon(PackedVector2Array([
			muzzle + Vector2(0.0, -size.y * 0.10),
			muzzle + Vector2(size.x * 0.09, size.y * 0.04),
			muzzle + Vector2(0.0, size.y * 0.01),
			muzzle + Vector2(-size.x * 0.09, size.y * 0.04),
		]), Color("dffaff"))

func set_firing(value: bool) -> void:
	firing = value
	queue_redraw()

func set_entrance_glow(value: float) -> void:
	entrance_glow = clampf(value, 0.0, 1.0)
	queue_redraw()
