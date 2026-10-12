extends Control
## Read-only odds view. Uses the same data as the shop's actual hatch roll.
signal closed

const RATES = preload("res://scripts/config/EggDropRateConfig.gd")
const FRAME = preload("res://assets/ui/egg-upgrade/egg-upgrade-panel-v2.png")
const CLOSE = preload("res://assets/ui/egg-upgrade/egg-upgrade-close.svg")
const BOLD = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-Bold.ttf")

var panel: Control
var title: Label
var egg_image: TextureRect
var egg_label: Label
var planet_label: Label
var close_button: TextureButton
var done_button: Button
var rows: Array[Dictionary] = []
var closing := false
var egg_level := 1

func _ready() -> void:
	name = "EggDropRatePopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.028, 0.05, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = Control.new()
	panel.name = "Panel"
	panel.size = Vector2(650, 860)
	add_child(panel)
	var frame := TextureRect.new()
	frame.texture = FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = _label("POSSIBLE DROPS", Vector2(120, 58), Vector2(410, 76), 36)
	egg_image = TextureRect.new()
	egg_image.position = Vector2(95, 152)
	egg_image.size = Vector2(108, 112)
	egg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	egg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	egg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(egg_image)
	egg_label = _label("", Vector2(220, 148), Vector2(325, 44), 30)
	planet_label = _label("", Vector2(220, 192), Vector2(325, 34), 22)
	_label("One chicken per egg", Vector2(220, 228), Vector2(325, 34), 21)
	for tier in range(1, 11):
		var row := Panel.new()
		row.name = "Tier%d" % tier
		row.position = Vector2(72, 286 + (tier - 1) * 40)
		row.size = Vector2(506, 36)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _rounded(Color("fff8e6") if tier % 2 else Color("f6e8c8")))
		panel.add_child(row)
		var tier_name := _label("TIER %d" % tier, Vector2(12, 0), Vector2(136, 36), 22, row)
		tier_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var bar := ProgressBar.new()
		bar.position = Vector2(158, 10)
		bar.size = Vector2(226, 16)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _rounded(Color("e7d4ad")))
		bar.add_theme_stylebox_override("fill", _rounded(Color("80c746")))
		row.add_child(bar)
		var chance := _label("", Vector2(392, 0), Vector2(100, 36), 23, row)
		rows.append({"card": row, "tier": tier_name, "bar": bar, "chance": chance})
	_label("Higher tiers are not guaranteed.", Vector2(72, 690), Vector2(506, 34), 22)
	done_button = Button.new()
	done_button.name = "Done"
	done_button.text = "GOT IT"
	done_button.position = Vector2(200, 730)
	done_button.size = Vector2(250, 88)
	done_button.pressed.connect(close)
	panel.add_child(done_button)
	# Added last, kept inside the viewport, and fully scaled (never atlas-cropped).
	close_button = TextureButton.new()
	close_button.name = "Close"
	close_button.texture_normal = CLOSE
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_button.position = Vector2(550, 58)
	close_button.size = Vector2(88, 88)
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(close)
	panel.add_child(close_button)
	resized.connect(_layout)
	_layout()

func _label(text: String, at: Vector2, bounds: Vector2, font_size: int, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = bounds
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BOLD)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("4d301d"))
	(parent if parent != null else panel).add_child(label)
	return label

func _rounded(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(8)
	return style

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var factor := minf(1.0, minf((size.x - 24.0) / 650.0, (size.y - 32.0) / 860.0))
	panel.scale = Vector2.ONE * maxf(0.1, factor)
	panel.position = (size - panel.size * panel.scale) * 0.5

func show_rates(level: int, map_name: String, texture: Texture2D) -> void:
	if closing:
		return
	egg_level = clampi(level, 1, 10)
	egg_label.text = "EGG Lv.%d" % egg_level
	planet_label.text = "%s chickens only" % map_name
	egg_image.texture = texture
	var rates: Dictionary = RATES.rates(egg_level)
	for index in rows.size():
		var chance := float(rates.get(index + 1, 0.0))
		rows[index].chance.text = "%.0f%%" % chance
		rows[index].bar.value = chance
		rows[index].card.modulate = Color.WHITE if chance > 0.0 else Color("b6ac99")
	_layout()
	show()

func close() -> void:
	if closing or not visible:
		return
	closing = true
	# Retain the input shield through the release and emulated mouse event.
	var delay := create_tween()
	delay.tween_interval(0.16)
	delay.tween_callback(func():
		hide()
		closing = false
		closed.emit()
	)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
