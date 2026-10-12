extends CanvasLayer
signal closed
const SKIN = preload("res://scripts/battle/BattleUI.gd")
const FONT = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-Bold.ttf")
const TITLE_FONT = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf")
var can_open: Callable
var overlay: ColorRect
var panel: PanelContainer
var sliders: Dictionary = {}
var values: Dictionary = {}
var mute_button: Button
var done_button: Button
var status: Label
var title_label: Label
var subtitle_label: Label
var language_label: Label
var language_select: OptionButton
const COPY := {
	"en": ["SETTINGS", "Your farm, your sound!", "LANGUAGE", "MUSIC", "SOUND EFFECTS", "HOW TO PLAY", "DONE", "Replay the tutorial and learn the controls"],
	"es": ["AJUSTES", "¡Tu granja, tu sonido!", "IDIOMA", "MÚSICA", "EFECTOS DE SONIDO", "CÓMO JUGAR", "LISTO", "Repite el tutorial y aprende los controles"],
	"pt": ["CONFIGURAÇÕES", "Sua fazenda, seu som!", "IDIOMA", "MÚSICA", "EFEITOS SONOROS", "COMO JOGAR", "CONCLUÍDO", "Repita o tutorial e aprenda os controles"],
	"fr": ["PARAMÈTRES", "Votre ferme, votre son !", "LANGUE", "MUSIQUE", "EFFETS SONORES", "COMMENT JOUER", "TERMINÉ", "Rejouez le tutoriel et apprenez les commandes"],
	"de": ["EINSTELLUNGEN", "Deine Farm, dein Sound!", "SPRACHE", "MUSIK", "SOUNDEFFEKTE", "SPIELHILFE", "FERTIG", "Tutorial wiederholen und Steuerung lernen"],
	"ja": ["設定", "農場とサウンドを楽しもう！", "言語", "音楽", "効果音", "遊び方", "完了", "チュートリアルと操作方法を確認"],
	"ko": ["설정", "나만의 농장과 사운드!", "언어", "음악", "효과음", "게임 방법", "완료", "튜토리얼과 조작 방법 다시 보기"],
	"zh": ["设置", "你的农场，你的声音！", "语言", "音乐", "音效", "游戏玩法", "完成", "重玩教程并学习操作"],
}

func _ready() -> void:
	layer = 110
	overlay = ColorRect.new()
	overlay.color = Color(0.13, 0.09, 0.06, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("fff3d6")
	frame.border_color = Color("a96832")
	frame.set_border_width_all(5)
	frame.border_width_bottom = 12
	frame.set_corner_radius_all(30)
	frame.shadow_size = 12
	frame.shadow_color = Color(0.1, 0.05, 0.02, 0.35)
	for side in ["left", "right", "top", "bottom"]: frame.set_content_margin(side_to_index(side), 28)
	panel.add_theme_stylebox_override("panel", frame)
	overlay.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	panel.add_child(stack)
	title_label = _label(stack, "SETTINGS", 46)
	title_label.add_theme_font_override("font", TITLE_FONT)
	title_label.add_theme_color_override("font_color", Color("fff4d4"))
	title_label.add_theme_color_override("font_outline_color", Color("975523"))
	title_label.add_theme_constant_override("outline_size", 7)
	subtitle_label = _label(stack, "Your farm, your sound!", 24)
	for bus in ["Music", "SFX"]: _slider_row(stack, bus)
	language_label = _label(stack, "LANGUAGE", 24)
	language_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	language_select = OptionButton.new()
	language_select.name = "Language"
	language_select.custom_minimum_size = Vector2(0, 72)
	language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in Audio.LANGUAGES.size():
		language_select.add_item(Audio.LANGUAGES[index].name, index)
	language_select.add_theme_font_override("font", FONT)
	language_select.add_theme_font_size_override("font_size", 25)
	language_select.add_theme_color_override("font_color", Color("51321e"))
	language_select.add_theme_color_override("font_hover_color", Color("3d2418"))
	language_select.add_theme_stylebox_override("normal", _dropdown_box(Color("b9e4f3"), Color("704022")))
	language_select.add_theme_stylebox_override("hover", _dropdown_box(Color("d5f3fb"), Color("9b5729")))
	language_select.add_theme_stylebox_override("pressed", _dropdown_box(Color("8fcde5"), Color("704022")))
	language_select.add_theme_stylebox_override("focus", _dropdown_box(Color.TRANSPARENT, Color("ffbd45"), 4))
	stack.add_child(language_select)
	var menu := language_select.get_popup()
	menu.add_theme_font_override("font", FONT)
	menu.add_theme_font_size_override("font_size", 24)
	menu.add_theme_color_override("font_color", Color("51321e"))
	menu.add_theme_color_override("font_hover_color", Color("3d2418"))
	menu.add_theme_stylebox_override("panel", _dropdown_box(Color("fff3d6"), Color("a96832"), 4))
	language_select.item_selected.connect(func(index: int): Audio.set_language(Audio.LANGUAGES[index].code))
	mute_button = _button(stack, "", Color("e5c79d"))
	mute_button.pressed.connect(func(): Audio.set_muted(not Audio.muted))
	status = _label(stack, "", 21)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 64
	done_button = _button(stack, "DONE", Color("8bd15a"))
	done_button.pressed.connect(close)
	Audio.preferences_changed.connect(refresh)
	get_viewport().size_changed.connect(_layout)
	panel.resized.connect(_center)
	panel.minimum_size_changed.connect(func(): call_deferred("_fit_height"))
	hide()
	refresh()
	_layout()

func side_to_index(side: String) -> int:
	return ["left", "top", "right", "bottom"].find(side)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("51321e"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, fill: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 88
	SKIN.button(button, fill)
	button.add_theme_font_size_override("font_size", 27)
	parent.add_child(button)
	return button

func _dropdown_box(fill: Color, border: Color, width := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(16)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _slider_row(parent: Node, bus: String) -> void:
	var column := VBoxContainer.new()
	parent.add_child(column)
	values[bus] = _label(column, "", 27)
	var slider := HSlider.new()
	slider.name = bus + "Volume"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size.y = 72
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("dcc8a0")
	rail.set_corner_radius_all(8)
	rail.content_margin_top = 8
	rail.content_margin_bottom = 8
	slider.add_theme_stylebox_override("slider", rail)
	var fill := rail.duplicate() as StyleBoxFlat
	fill.bg_color = Color("86c957")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	# A round, finger-visible knob; no platform-default tiny slider handle.
	var knob := GradientTexture2D.new()
	knob.width = 40
	knob.height = 40
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(0.5, 0.5)
	knob.fill_to = Vector2(1, 0.5)
	knob.gradient = Gradient.new()
	knob.gradient.offsets = PackedFloat32Array([0, 0.68, 0.72, 0.9, 0.94, 1])
	knob.gradient.colors = PackedColorArray([Color("fff5b1"), Color("ffc85c"), Color("99612e"), Color("99612e"), Color.TRANSPARENT, Color.TRANSPARENT])
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	column.add_child(slider)
	sliders[bus] = slider
	slider.value_changed.connect(func(value): Audio.set_volume(bus, value / 100.0))
	slider.drag_ended.connect(func(changed):
		Audio.save_preferences()
		if changed and bus == "SFX": Audio.play_sfx("click"))

func open() -> void:
	if visible or (can_open.is_valid() and not can_open.call()): return
	refresh()
	show()
	_layout()
	Audio.play_sfx("open")
	done_button.grab_focus()

func close() -> void:
	if not visible: return
	Audio.save_preferences()
	hide()
	Audio.play_sfx("close")
	closed.emit()

func refresh() -> void:
	var copy: Array = COPY.get(Audio.language, COPY.en)
	title_label.text = copy[0]
	subtitle_label.text = copy[1]
	language_label.text = copy[2]
	var selected_index := 0
	for index in Audio.LANGUAGES.size():
		if Audio.LANGUAGES[index].code == Audio.language: selected_index = index
	language_select.select(selected_index)
	for bus in sliders:
		var value: float = Audio.music_volume if bus == "Music" else Audio.sfx_volume
		sliders[bus].set_value_no_signal(roundi(value * 100))
		var bus_name: String = copy[3] if bus == "Music" else copy[4]
		values[bus].text = bus_name + "   %d%%" % roundi(value * 100)
	mute_button.text = "SOUND: OFF · TAP TO UNMUTE" if Audio.muted else "SOUND: ON · TAP TO MUTE"
	done_button.text = copy[6]
	status.text = "Saved on this device.\nSet a slider to 0 to turn it off." if Audio.save_error == OK else "Could not save settings. Please try again."

func _layout() -> void:
	if not is_instance_valid(panel): return
	panel.size.x = minf(600, get_viewport().get_visible_rect().size.x - 48)
	call_deferred("_fit_height")

func _fit_height() -> void:
	# Autowrapped text initially measures at zero width. Shrink that provisional
	# height again after the container has assigned the actual phone width.
	panel.size.y = panel.get_combined_minimum_size().y
	_center()

func _center() -> void:
	panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible: close()
