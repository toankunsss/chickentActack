extends Control
## Code-native cartoon intro; driven by the arena clock so pausing freezes it.
const FONT = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf")
const BEAT := 0.8
const DURATION := BEAT * 4.0
var elapsed := 0.0
var preparing := false
var headline: Label
var caption: Label
var sounded_phase := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	headline = Label.new()
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.add_theme_font_override("font", FONT)
	headline.add_theme_color_override("font_outline_color", Color("58301e"))
	headline.add_theme_constant_override("outline_size", 10)
	headline.add_theme_color_override("font_shadow_color", Color("392820"))
	headline.add_theme_constant_override("shadow_offset_y", 7)
	add_child(headline)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_override("font", FONT)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color("fff3cf"))
	caption.add_theme_color_override("font_outline_color", Color("392820"))
	caption.add_theme_constant_override("outline_size", 5)
	add_child(caption)
	hide()

func show_time(time: float, loading: bool = false) -> void:
	elapsed = time
	preparing = loading
	show()
	var phase := mini(3, int(time / BEAT))
	if loading: sounded_phase = -1
	elif phase != sounded_phase:
		sounded_phase = phase
		Audio.play_sfx("go" if phase == 3 else "count")
	var progress := fmod(time, BEAT) / BEAT
	headline.text = "GET READY" if loading else ["1", "2", "3", "BATTLE!"][phase]
	headline.add_theme_font_size_override("font_size", 62 if loading else (82 if phase == 3 else 144))
	headline.add_theme_color_override("font_color", Color("fff0ab") if phase == 3 or loading else [Color("8fe8ff"), Color("b6f477"), Color("ffce66")][phase])
	headline.size = Vector2(size.x, 200)
	headline.position = Vector2(0, size.y * 0.5 - 130)
	headline.pivot_offset = headline.size * 0.5
	var pop := 1.0 + sin(progress * PI * 3.0) * 0.16 * (1.0 - progress)
	headline.scale = Vector2(pop, 2.0 - pop)
	headline.rotation = sin(progress * TAU) * 0.06 * (1.0 - progress)
	caption.text = "WARMING UP THE FLOCK..." if loading else ("LET THE FEATHERS FLY!" if phase == 3 else "READY, LITTLE FIGHTERS?")
	caption.position = Vector2(0, size.y * 0.5 + 72)
	caption.size = Vector2(size.x, 44)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.16, 0.20, 0.60))
	var center := size * 0.5 - Vector2(0, 24)
	var pulse := fmod(elapsed, BEAT) / BEAT
	for i in 12:
		var angle := i * TAU / 12.0 + elapsed * 0.12
		var direction := Vector2.from_angle(angle)
		draw_line(center + direction * 104, center + direction * (125 + pulse * 38), Color("ffe8a1"), 6, true)
		if not preparing:
			var dot := center + Vector2.from_angle(angle + 0.1) * (145 + pulse * 36)
			draw_circle(dot, 4, [Color("8fe8ff"), Color("ffcd64"), Color("b6f477")][i % 3])
