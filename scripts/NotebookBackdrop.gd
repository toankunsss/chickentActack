extends Control
## Full-screen ruled notebook paper. The page deliberately fills the entire
## viewport so no decorative desktop background leaks around mobile screens.

const PAPER := Color("fff8dc")
const RULE := Color("eadb91")
const MARGIN_RED := Color("e26055")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	# The warm paper surface now covers the complete mobile viewport.
	var page := Rect2(Vector2.ZERO, size)
	draw_rect(page, PAPER)
	var content_top := 145.0
	var content_bottom := size.y - 140.0
	var line_y := content_top + 28.0
	while line_y < content_bottom:
		draw_line(Vector2(page.position.x + 3, line_y), Vector2(page.end.x - 3, line_y), RULE, 2.0)
		line_y += 42.0
	draw_line(Vector2(82, content_top), Vector2(82, content_bottom), MARGIN_RED, 3.0)
