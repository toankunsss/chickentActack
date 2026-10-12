extends RefCounted
## Small shared skin, matching the game's cream/wood and chunky Baloo typography.
const FONT = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-Bold.ttf")

static func button(control: Button, fill: Color, ink := Color("51321e")) -> void:
	control.add_theme_font_override("font", FONT)
	control.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill if state == "normal" else (fill.lightened(0.08) if state == "hover" else fill.darkened(0.08))
		if state == "disabled": box.bg_color = Color("c9c1af")
		box.border_color = Color("724528")
		box.set_border_width_all(3)
		box.border_width_bottom = 5 if state != "pressed" else 2
		box.set_corner_radius_all(14)
		control.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, ink)
	control.add_theme_color_override("font_disabled_color", Color("716858"))
