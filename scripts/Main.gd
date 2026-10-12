extends Control
## Builds the whole UI in code: persistent TopBar + BottomNav (6 tabs, like
## the HTML prototype's bottom-nav), and 6 swappable screens (Home / Farm /
## Mutations / Battle / Adventure / Shop). Also drives the game loop:
## wandering AI, drag-to-merge input (Farm screen only), passive income,
## HUD refresh, save/load.

const CritterScene := preload("res://scenes/Critter.tscn")
const ChunkyIconScript := preload("res://scripts/ChunkyIcon.gd")
const ICON_MUTATIONS := preload("res://assets/icons/skills_icon_128px.png")
const ICON_BATTLE := preload("res://assets/icons/sword_icon_128px.png")
const ICON_ADVENTURE := preload("res://assets/icons/adventure_icon_128px.png")
const ICON_SHOP := preload("res://assets/icons/shop_icon_128px.png")
const ICON_COLLECTION := preload("res://assets/icons/chestRuby_icon_128px.png")

const FONT_BALOO := preload("res://assets/fonts/Baloo2.ttf")

const GROUND_MIN := Vector2(4, 6)
const GROUND_MAX := Vector2(96, 94)
const WALK_SPEED_PCT := 16.0  # percent of farm size per second
const BASE_SIZE := 130.0  # must match Critter.gd's TARGET_PX (hit-test radius = visual size)
const CARD_BG := Color(0.99, 0.98, 0.94)
const INK_SOFT := Color(0.42, 0.36, 0.3)
const INK_BLACK := Color(0.14, 0.1, 0.08)
const BORDER_W := 4

# "Chunky cartoon" palette — thick black outlines, flat candy colors,
# matching the reference notebook-style merge-farm UI the user provided.
const COL_PAPER := Color(0.99, 0.95, 0.72)
const COL_GREEN := Color(0.55, 0.82, 0.31)
const COL_GREEN_DARK := Color(0.28, 0.58, 0.16)
const COL_RED := Color(0.95, 0.32, 0.34)
const COL_ORANGE := Color(0.98, 0.68, 0.22)
const COL_ORANGE_DARK := Color(0.83, 0.5, 0.08)

## Thick-border rounded StyleBoxFlat — the single shared building block for
## every panel/button in the "chunky cartoon" look.
func _chunky_style(fill: Color, border: Color = INK_BLACK, radius: int = 20, border_w: int = BORDER_W) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_right = border_w
	s.border_width_top = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.shadow_color = Color(0, 0, 0, 0.16)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 3)
	return s

## Green rounded-pill screen-title tab, matching the reference's
## "ANIMAL SHOP" / tab-style headers.
func _screen_title_tab(text: String) -> Control:
	var wrap := HBoxContainer.new()
	var panel := PanelContainer.new()
	var style := _chunky_style(COL_GREEN, INK_BLACK, 999, 3)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", INK_BLACK)
	label.add_theme_constant_override("outline_size", 3)
	panel.add_child(label)
	wrap.add_child(panel)
	return wrap

## A bold rounded "pill" button: colored fill, black border, dark-shade
## bottom edge (fake 3D chunky-button look), white bold label.
func _chunky_button(text: String, fill: Color, dark: Color, on_press: Callable, font_size: int = 16) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", INK_BLACK)
	btn.add_theme_constant_override("outline_size", 3)

	var normal := _chunky_style(fill, INK_BLACK, 14)
	normal.border_width_bottom = BORDER_W + 3
	normal.bg_color = fill
	var hover := _chunky_style(fill.lightened(0.08), INK_BLACK, 14)
	hover.border_width_bottom = BORDER_W + 3
	var pressed := _chunky_style(dark, INK_BLACK, 14)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(on_press)
	return btn

var coin_label: Label
var gem_label: Label
var dna_label: Label
var level_label: Label
var xp_bar: ProgressBar
var toast_layer: VBoxContainer

var screens_root: Control
var screens := {}  # name -> Control
var nav_buttons := {}  # name -> Button
var current_screen := "home"

# Farm screen
var farm_area: Control
var debug_label: Label
var farm_node: Node2D
var critter_views := {}  # animal_id -> Node2D

# Home screen
var home_farm_preview: HBoxContainer
var home_farm_level_label: Label
var home_animal_count_label: Label
var home_coin_rate_label: Label
var home_battle_preview: HBoxContainer
var home_team_cap_label: Label
var home_team_power_label: Label
var home_collection_count_label: Label
var home_collection_fill: ProgressBar

# Mutations screen
var mutations_grid: GridContainer
var mutations_count_label: Label

var merge_overlay: Control
var merge_slot_a: Control
var merge_slot_b: Control
var merge_slot_result: Control
var merge_status: Label

var drag_id: String = ""
var drag_offset := Vector2.ZERO
var drag_moved := false
var drag_start := Vector2.ZERO
var highlight_id: String = ""
var wander_paused := false

var income_accum := 0.0
var save_accum := 0.0

func _ready() -> void:
	var loaded := Game.load_game()
	Game.init_demo_data()

	var app_theme := Theme.new()
	app_theme.default_font = FONT_BALOO
	app_theme.default_font_size = 16
	theme = app_theme

	_build_ui()
	_sync_critters()
	_update_hud()
	_show_screen("home")

	if loaded:
		_toast("👋 Welcome back to the farm!")

# ==================== UI SHELL ====================

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = COL_PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	vbox.add_child(_build_top_bar())

	screens_root = Control.new()
	screens_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screens_root.clip_contents = true
	screens_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(screens_root)

	screens["home"] = _build_home_screen()
	screens["farm"] = _build_farm_screen()
	screens["mutations"] = _build_mutations_screen()
	screens["battle"] = _build_placeholder_screen("⚔️ ARENA", "The Arena is under development.\nCheck back later!")
	screens["adventure"] = _build_placeholder_screen("🗺️ ADVENTURE", "The chapter-based Adventure map and bosses are under development.")
	screens["shop"] = _build_shop_screen()

	for key in screens.keys():
		var s: Control = screens[key]
		s.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.visible = false
		screens_root.add_child(s)

	vbox.add_child(_build_bottom_nav())

	merge_overlay = _build_merge_overlay()
	add_child(merge_overlay)

	toast_layer = VBoxContainer.new()
	toast_layer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_layer.position -= Vector2(90, 220)
	toast_layer.custom_minimum_size = Vector2(180, 0)
	toast_layer.alignment = BoxContainer.ALIGNMENT_END
	add_child(toast_layer)

func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = INK_BLACK
	style.border_width_bottom = BORDER_W
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)

	coin_label = _currency_pill(row, "coin", Color(1, 0.79, 0.25), Color(0.64, 0.41, 0.04))
	gem_label = _currency_pill(row, "gem", Color(0.42, 0.78, 0.98), Color(0.08, 0.4, 0.65))
	dna_label = _currency_pill(row, "bolt", Color(0.72, 0.52, 0.98), Color(0.42, 0.24, 0.7))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var coll_btn := TextureButton.new()
	coll_btn.texture_normal = ICON_COLLECTION
	coll_btn.ignore_texture_size = true
	coll_btn.custom_minimum_size = Vector2(34, 34)
	coll_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	coll_btn.pressed.connect(func(): _show_screen("mutations"))
	row.add_child(coll_btn)

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 10)
	col.add_child(xp_row)

	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", INK_SOFT)
	xp_row.add_child(level_label)

	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 14)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_child(xp_bar)

	return panel

func _currency_pill(row: HBoxContainer, kind: String, fill: Color, color: Color) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(34, 34)
	badge.add_theme_stylebox_override("panel", _chunky_style(Color.WHITE, INK_BLACK, 17, 3))
	box.add_child(badge)

	var icon := Control.new()
	icon.set_script(ChunkyIconScript)
	icon.kind = kind
	icon.fill = fill
	icon.custom_minimum_size = Vector2(22, 22)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(icon)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK_BLACK)
	label.add_theme_constant_override("outline_size", 3)
	box.add_child(label)
	return label

func _build_bottom_nav() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = INK_BLACK
	style.border_width_top = BORDER_W
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 8
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)

	row.add_child(_nav_button("home", "🏠", null, "Home"))
	row.add_child(_nav_button("farm", "🏡", null, "Farm"))
	row.add_child(_nav_button("mutations", "", ICON_MUTATIONS, "Mutations"))
	row.add_child(_nav_button("battle", "", ICON_BATTLE, "Battle"))
	row.add_child(_nav_button("adventure", "", ICON_ADVENTURE, "Adventure"))
	row.add_child(_nav_button("shop", "", ICON_SHOP, "Shop"))

	return panel

func _nav_button(screen_name: String, emoji: String, icon: Texture2D, label_text: String) -> Control:
	var btn := Button.new()
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56)
	btn.pressed.connect(func(): _show_screen(screen_name))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	btn.add_child(col)

	if icon:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.custom_minimum_size = Vector2(22, 22)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(tex)
	else:
		var e := Label.new()
		e.text = emoji
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.add_theme_font_size_override("font_size", 20)
		col.add_child(e)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.name = "NavLabel"
	col.add_child(lbl)

	nav_buttons[screen_name] = btn
	return btn

func _show_screen(name: String) -> void:
	if not screens.has(name):
		return
	current_screen = name
	for key in screens.keys():
		screens[key].visible = (key == name)
	for key in nav_buttons.keys():
		var btn: Button = nav_buttons[key]
		var lbl := btn.find_child("NavLabel", true, false) as Label
		if lbl:
			lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1) if key == name else INK_SOFT)

	if name == "home":
		_refresh_home()
	elif name == "mutations":
		_refresh_mutations()
	_update_hud()

# ==================== HOME SCREEN ====================

func _build_home_screen() -> Control:
	# Plain full-rect column with expanding spacers above/below the card
	# stack, so the 3 cards sit vertically centered instead of stuck to the
	# top with a big dead void below (a ScrollContainer here won't stretch
	# its child to the viewport, so it can't center — this can — and 3
	# cards comfortably fit without needing to scroll).
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(top_spacer)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.add_child(col)
	outer.add_child(margin)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(bottom_spacer)

	var greet_title := Label.new()
	greet_title.text = "👋 Welcome back!"
	greet_title.add_theme_font_size_override("font_size", 24)
	greet_title.add_theme_color_override("font_color", INK_BLACK)
	col.add_child(greet_title)

	var greet_sub := Label.new()
	greet_sub.text = "Your farm is still running. Choose an area below to begin."
	greet_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	greet_sub.add_theme_font_size_override("font_size", 14)
	greet_sub.add_theme_color_override("font_color", INK_SOFT)
	col.add_child(greet_sub)

	# ---- Farm card ----
	var farm_card := _card_panel(Color(0.89, 0.97, 0.85))
	col.add_child(farm_card)
	var farm_col: VBoxContainer = farm_card.get_child(0)
	farm_col.add_child(_card_header("🌾", "Farm"))
	home_farm_preview = HBoxContainer.new()
	home_farm_preview.add_theme_constant_override("separation", 4)
	home_farm_preview.custom_minimum_size = Vector2(0, 32)
	farm_col.add_child(home_farm_preview)
	home_farm_level_label = _stat_line(farm_col, "Farm level")
	home_animal_count_label = _stat_line(farm_col, "creatures raised")
	home_coin_rate_label = _stat_line(farm_col, "🪙/harvest cycle")
	farm_col.add_child(_card_button("Enter Farm →", func(): _show_screen("farm")))

	# ---- Battle card ----
	var battle_card := _card_panel(Color(0.99, 0.88, 0.88))
	col.add_child(battle_card)
	var battle_col: VBoxContainer = battle_card.get_child(0)
	battle_col.add_child(_card_header("⚔️", "Arena"))
	home_battle_preview = HBoxContainer.new()
	home_battle_preview.add_theme_constant_override("separation", 4)
	home_battle_preview.custom_minimum_size = Vector2(0, 32)
	battle_col.add_child(home_battle_preview)
	home_team_cap_label = _stat_line(battle_col, "team capacity")
	home_team_power_label = _stat_line(battle_col, "team power")
	battle_col.add_child(_card_button("Enter Arena →", func(): _show_screen("battle")))

	# ---- Collection card ----
	var coll_card := _card_panel(Color(0.92, 0.89, 0.98))
	col.add_child(coll_card)
	var coll_col: VBoxContainer = coll_card.get_child(0)
	coll_col.add_child(_card_header("📖", "Collection"))
	home_collection_count_label = Label.new()
	home_collection_count_label.add_theme_font_size_override("font_size", 13)
	home_collection_count_label.add_theme_color_override("font_color", INK_SOFT)
	coll_col.add_child(home_collection_count_label)
	home_collection_fill = ProgressBar.new()
	home_collection_fill.show_percentage = false
	home_collection_fill.custom_minimum_size = Vector2(0, 10)
	coll_col.add_child(home_collection_fill)
	coll_col.add_child(_card_button("View Full Collection →", func(): _show_screen("mutations")))

	return outer

func _card_panel(bg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _chunky_style(bg_color, INK_BLACK, 20)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	return panel

func _card_header(emoji: String, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var e := Label.new()
	e.text = emoji
	e.add_theme_font_size_override("font_size", 22)
	row.add_child(e)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", INK_BLACK)
	row.add_child(t)
	return row

func _stat_line(parent: VBoxContainer, suffix: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", INK_BLACK)
	row.add_child(value)
	var s := Label.new()
	s.text = suffix
	s.add_theme_font_size_override("font_size", 14)
	s.add_theme_color_override("font_color", INK_SOFT)
	row.add_child(s)
	parent.add_child(row)
	return value

func _card_button(text: String, on_press: Callable) -> Button:
	return _chunky_button(text, COL_GREEN, COL_GREEN_DARK, on_press, 15)

func _mini_preview_row(container: HBoxContainer, entries: Array, empty_text: String) -> void:
	for c in container.get_children():
		c.queue_free()
	if entries.is_empty():
		var e := Label.new()
		e.text = empty_text
		e.add_theme_font_size_override("font_size", 12)
		e.add_theme_color_override("font_color", INK_SOFT)
		container.add_child(e)
		return
	for a in entries.slice(0, 8):
		container.add_child(_species_icon(a.species_id, Vector2(30, 30)))

func _refresh_home() -> void:
	_mini_preview_row(home_farm_preview, Game.animals, "— The farm is empty —")
	home_farm_level_label.text = str(Game.farm_level)
	home_animal_count_label.text = str(Game.animals.size())
	home_coin_rate_label.text = "+%d" % Game.passive_income()

	var team: Array = []
	for id in Game.battle_team:
		var a = Game.find_animal(id)
		if not a.is_empty():
			team.append(a)
	_mini_preview_row(home_battle_preview, team, "— No team selected —")
	home_team_cap_label.text = "%d/%d" % [team.size(), Game.team_capacity]
	home_team_power_label.text = "0"

	var total := Game.MAX_TIER * Game.SPECIES.size() * 2
	home_collection_count_label.text = "%d/%d UNLOCKED" % [Game.discovered.size(), total]
	home_collection_fill.max_value = total
	home_collection_fill.value = Game.discovered.size()

# ==================== FARM SCREEN ====================

func _build_farm_screen() -> Control:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hint := Label.new()
	hint.text = "✋ Same species = guaranteed merge ✨ · Different species = risky fusion 🎲"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", INK_SOFT)
	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 14)
	hint_margin.add_theme_constant_override("margin_right", 14)
	hint_margin.add_theme_constant_override("margin_top", 8)
	hint_margin.add_theme_constant_override("margin_bottom", 4)
	hint_margin.add_child(hint)
	col.add_child(hint_margin)

	debug_label = Label.new()
	debug_label.text = "debug: (no action yet)"
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	debug_label.add_theme_font_size_override("font_size", 11)
	debug_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	var debug_margin := MarginContainer.new()
	debug_margin.add_theme_constant_override("margin_left", 14)
	debug_margin.add_theme_constant_override("margin_right", 14)
	debug_margin.add_child(debug_label)
	col.add_child(debug_margin)

	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sky := ColorRect.new()
	sky.color = Color(0.75, 0.91, 1.0)
	sky.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sky.anchor_bottom = 0.38
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(sky)

	var grass := ColorRect.new()
	grass.color = Color(0.42, 0.78, 0.33)
	grass.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grass.anchor_top = 0.38
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(grass)

	farm_node = Node2D.new()
	holder.add_child(farm_node)
	farm_area = holder
	col.add_child(holder)

	return col

# ==================== MUTATIONS SCREEN ====================

func _build_mutations_screen() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	var head_col := VBoxContainer.new()
	margin.add_child(head_col)
	col.add_child(margin)

	head_col.add_child(_screen_title_tab("🧬 CREATURE COLLECTION"))

	mutations_count_label = Label.new()
	mutations_count_label.add_theme_font_size_override("font_size", 13)
	mutations_count_label.add_theme_color_override("font_color", INK_SOFT)
	head_col.add_child(mutations_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 16)
	grid_margin.add_theme_constant_override("margin_right", 16)
	grid_margin.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(grid_margin)

	mutations_grid = GridContainer.new()
	mutations_grid.columns = 4
	mutations_grid.add_theme_constant_override("h_separation", 8)
	mutations_grid.add_theme_constant_override("v_separation", 8)
	grid_margin.add_child(mutations_grid)

	return col

func _refresh_mutations() -> void:
	for c in mutations_grid.get_children():
		c.queue_free()

	var total := 0
	var unlocked := 0
	for tier in range(1, Game.MAX_TIER + 1):
		for sp in Game.SPECIES:
			for rare in [false, true]:
				total += 1
				var tid = Game.rare_type_id(sp.id, tier) if rare else Game.type_id(sp.id, tier)
				var is_unlocked = Game.discovered.has(tid)
				if is_unlocked:
					unlocked += 1
				mutations_grid.add_child(_collection_cell(sp.id, tier, rare, is_unlocked))

	mutations_count_label.text = "%d/%d UNLOCKED" % [unlocked, total]

func _collection_cell(species_id: String, tier: int, rare: bool, unlocked: bool) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(0, 76)
	var fill := Color(1, 0.93, 0.6) if (unlocked and rare) else (Color(1, 1, 1) if unlocked else Color(0.82, 0.79, 0.72))
	var border := COL_ORANGE_DARK if (unlocked and rare) else INK_BLACK
	cell.add_theme_stylebox_override("panel", _chunky_style(fill, border, 14, 3))

	if unlocked:
		var icon := _species_icon(species_id, Vector2(44, 44))
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.position -= icon.custom_minimum_size / 2.0
		cell.add_child(icon)
		if rare:
			var sparkle := Label.new()
			sparkle.text = "✨"
			sparkle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			sparkle.position += Vector2(-20, 2)
			cell.add_child(sparkle)
	else:
		var label := Label.new()
		label.text = "❔"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 30)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.modulate = Color(0.6, 0.6, 0.6)
		cell.add_child(label)

	var tag := Label.new()
	tag.text = "T%d" % tier
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", INK_BLACK)
	tag.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tag.position -= Vector2(24, 18)
	cell.add_child(tag)

	return cell

# ==================== PLACEHOLDER SCREENS (Battle / Adventure) ====================

func _build_placeholder_screen(title: String, body: String) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)

	var tab := _screen_title_tab(title)
	tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tab)

	var b := Label.new()
	b.text = body
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", INK_SOFT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(b)

	return col

# ==================== SHOP SCREEN ====================

func _build_shop_screen() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_child(_screen_title_tab("🛒 ANIMAL SHOP"))
	col.add_child(margin)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 16)
	grid_margin.add_theme_constant_override("margin_right", 16)
	col.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid_margin.add_child(grid)

	for sp in Game.SPECIES:
		grid.add_child(_shop_item_card(sp.id, "Chick " + sp.label))
	grid.add_child(_shop_action_card("🍚", "Food", "+15 XP · +60 Coin", "🪙 %d" % Game.FOOD_COST, func(): _buy_food()))
	grid.add_child(_shop_action_card("💎", "Gem Pouch", "+%d Gems" % Game.GEM_POUCH_AMOUNT, "🪙 %d" % Game.GEM_POUCH_COST, func(): _buy_gem_pouch()))
	grid.add_child(_shop_action_card("🥚", "Mystery Egg", "T1 70% · T2 30% · Rare 3%", "💎 %d" % Game.MYSTERY_EGG_COST, func(): _hatch_mystery_egg()))

	var note := Label.new()
	note.text = "Each species has its own line: merge matching species to tier up, or fuse different species for a risky result."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", INK_SOFT)
	var note_margin := MarginContainer.new()
	note_margin.add_theme_constant_override("margin_left", 16)
	note_margin.add_theme_constant_override("margin_right", 16)
	note_margin.add_child(note)
	col.add_child(note_margin)

	return col

func _shop_item_card(species_id: String, title: String) -> Control:
	var card := _card_panel(Color.WHITE)
	var col: VBoxContainer = card.get_child(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := _species_icon(species_id, Vector2(64, 64))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", INK_BLACK)
	col.add_child(t)

	col.add_child(_chunky_button("🪙 %d" % Game.BUY_STARTER_COST, COL_ORANGE, COL_ORANGE_DARK, func(): _buy_starter(species_id), 15))

	return card

func _shop_action_card(emoji: String, title: String, description: String, cost: String, on_press: Callable) -> Control:
	var card := _card_panel(Color.WHITE)
	var col: VBoxContainer = card.get_child(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := Label.new()
	icon.text = emoji
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 42)
	col.add_child(icon)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", INK_BLACK)
	col.add_child(heading)
	var detail := Label.new()
	detail.text = description
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	col.add_child(detail)
	col.add_child(_chunky_button(cost, COL_ORANGE, COL_ORANGE_DARK, on_press, 14))
	return card

# ==================== MERGE OVERLAY ====================

func _build_merge_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.03, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position -= Vector2(140, 80)
	col.add_theme_constant_override("separation", 16)
	overlay.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	merge_slot_a = Control.new()
	merge_slot_a.custom_minimum_size = Vector2(64, 64)
	row.add_child(merge_slot_a)

	merge_slot_result = Control.new()
	merge_slot_result.custom_minimum_size = Vector2(88, 88)
	merge_slot_result.visible = false
	row.add_child(merge_slot_result)

	merge_slot_b = Control.new()
	merge_slot_b.custom_minimum_size = Vector2(64, 64)
	row.add_child(merge_slot_b)

	merge_status = Label.new()
	merge_status.add_theme_font_size_override("font_size", 22)
	merge_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merge_status.add_theme_color_override("font_color", Color.WHITE)
	merge_status.add_theme_color_override("font_outline_color", INK_BLACK)
	merge_status.add_theme_constant_override("outline_size", 4)
	col.add_child(merge_status)

	return overlay

# ==================== HUD / TOAST ====================

func _update_hud() -> void:
	coin_label.text = "%s" % [int(Game.coins)]
	gem_label.text = "%s" % [Game.gems]
	dna_label.text = "%s" % [Game.dna]
	level_label.text = "Farm LV.%d" % Game.farm_level
	xp_bar.max_value = Game.xp_to_next
	xp_bar.value = Game.xp

func _toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.06, 0.9)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	toast_layer.add_child(panel)

	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(func():
		if is_instance_valid(panel):
			panel.queue_free()
	)

# ==================== CRITTERS / SHOP ACTIONS ====================

func _sync_critters() -> void:
	var live_ids := {}
	for a in Game.animals:
		live_ids[a.id] = true

	for id in critter_views.keys().duplicate():
		if not live_ids.has(id):
			critter_views[id].queue_free()
			critter_views.erase(id)

	for a in Game.animals:
		if not critter_views.has(a.id):
			var view = CritterScene.instantiate()
			farm_node.add_child(view)
			view.setup(a.id)
			critter_views[a.id] = view

func _buy_starter(species_id: String) -> void:
	if Game.coins < Game.BUY_STARTER_COST:
		_toast("NOT ENOUGH COIN")
		return
	if Game.animals.size() >= Game.MAX_ANIMALS:
		_toast("FARM FULL")
		return
	Game.coins -= Game.BUY_STARTER_COST
	var x = GROUND_MIN.x + randf() * (GROUND_MAX.x - GROUND_MIN.x)
	var y = GROUND_MIN.y + randf() * (GROUND_MAX.y - GROUND_MIN.y)
	var result = Game.create_animal(species_id, 1, {"x": x, "y": y})
	_sync_critters()
	_update_hud()
	_toast("✨ A rare creature appeared!" if result.is_rare else "Added to the farm!")
	Game.save_game()

func _buy_food() -> void:
	var result := Game.buy_food()
	if not result.ok:
		_toast("NOT ENOUGH COIN")
		return
	_apply_level_ups()
	_update_hud()
	_toast("🍚 +%d XP · +%d COIN" % [result.xp, result.coins])
	Game.save_game()

func _buy_gem_pouch() -> void:
	var result := Game.buy_gem_pouch()
	if not result.ok:
		_toast("NOT ENOUGH COIN")
		return
	_update_hud()
	_toast("💎 +%d GEMS" % result.gems)
	Game.save_game()

func _hatch_mystery_egg() -> void:
	var result := Game.hatch_mystery_egg({"x": 50.0, "y": 50.0})
	if not result.ok:
		_toast("FARM FULL" if result.reason == "farm_full" else "NOT ENOUGH GEMS")
		return
	_sync_critters()
	_update_hud()
	var animal: Dictionary = result.animal
	_toast("✨ Egg hatched: %s (T%d)" % [Game.display_name(animal), animal.tier])
	Game.save_game()

# ==================== MAIN LOOP ====================

func _process(delta: float) -> void:
	if is_instance_valid(farm_area):
		Game.farm_size = farm_area.size

	if not wander_paused:
		for a in Game.animals:
			if a.dragging:
				continue
			_step_wander(a, delta)

	for id in critter_views.keys():
		critter_views[id].highlighted = (id == highlight_id)

	income_accum += delta
	if income_accum >= 2.2:
		income_accum = fmod(income_accum, 2.2)
		_tick_income()

	save_accum += delta
	if save_accum >= 8.0:
		save_accum = 0.0
		Game.save_game()

func _tick_income() -> void:
	if Game.animals.is_empty():
		return
	var income := Game.passive_income_after_damage()
	Game.coins += income
	Game.xp += max(1, int(round(income / 20.0)))
	_apply_level_ups()
	_update_hud()

func _apply_level_ups() -> void:
	while Game.xp >= Game.xp_to_next:
		Game.xp -= Game.xp_to_next
		Game.farm_level += 1
		Game.xp_to_next = round(Game.xp_to_next * 1.18)
		_toast("🎉 Farm reached level %d!" % Game.farm_level)

func _step_wander(a: Dictionary, delta: float) -> void:
	if a.walking:
		var dx = a.target_x - a.x
		var dy = a.target_y - a.y
		var dist = Vector2(dx, dy).length()
		var step = WALK_SPEED_PCT * delta
		if dist <= step or dist < 0.4:
			a.x = a.target_x
			a.y = a.target_y
			a.walking = false
			a.idle_until = Time.get_ticks_msec() + 1200 + randi() % 2600
		else:
			a.x += dx / dist * step
			a.y += dy / dist * step
			a.facing = -1 if dx < 0 else 1
	elif Time.get_ticks_msec() >= a.idle_until:
		a.target_x = clamp(GROUND_MIN.x + randf() * (GROUND_MAX.x - GROUND_MIN.x), 2, 98)
		a.target_y = clamp(GROUND_MIN.y + randf() * (GROUND_MAX.y - GROUND_MIN.y), 4, 96)
		a.walking = true

# ==================== DRAG INPUT (Farm screen only) ====================

func _input(event: InputEvent) -> void:
	# Unconditional, decoupled-from-any-UI diagnostic: proves whether ANY
	# input reaches this script at all, regardless of screen/Control state.
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		get_window().title = "GOT INPUT: %s @ %s (screen=%s)" % [event.get_class(), event.position, current_screen]

	if current_screen != "farm":
		return
	# Real devices deliver touch (emulate_touch_from_mouse converts desktop
	# mouse input too) — but handle raw mouse directly as well so dragging
	# works even if that emulation setting doesn't fire in a given context.
	if event is InputEventScreenTouch:
		_debug_log("touch pressed=%s pos=%s" % [event.pressed, event.position])
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_debug_log("mouse pressed=%s pos=%s" % [event.pressed, event.position])
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drag(event.position)

func _debug_log(msg: String) -> void:
	if debug_label:
		debug_label.text = "debug: " + msg

func _to_farm_local(screen_pos: Vector2) -> Vector2:
	return screen_pos - farm_area.global_position

func _animal_at_px(px: Vector2, exclude_id: String) -> Dictionary:
	var best := {}
	var best_dist := INF
	for a in Game.animals_for_map():
		if a.id == exclude_id:
			continue
		var apx = Vector2(a.x / 100.0 * Game.farm_size.x, a.y / 100.0 * Game.farm_size.y)
		var scale_mult = Game.TIER_SCALE[a.tier - 1] if a.tier - 1 < Game.TIER_SCALE.size() else 1.0
		var radius = BASE_SIZE * scale_mult * 0.5
		var d = apx.distance_to(px)
		if d < radius and d < best_dist:
			best = a
			best_dist = d
	return best

func _begin_drag(screen_pos: Vector2) -> void:
	if wander_paused:
		return
	var local = _to_farm_local(screen_pos)
	var hit = _animal_at_px(local, "")
	_debug_log("begin_drag screen=%s local=%s farm_pos=%s farm_size=%s hit=%s" % [screen_pos, local, farm_area.global_position, Game.farm_size, (hit.id if not hit.is_empty() else "NONE")])
	if hit.is_empty():
		return
	drag_id = hit.id
	drag_moved = false
	drag_start = screen_pos
	var hit_px = Vector2(hit.x / 100.0 * Game.farm_size.x, hit.y / 100.0 * Game.farm_size.y)
	drag_offset = hit_px - local
	hit.dragging = true
	hit.walking = false

func _update_drag(screen_pos: Vector2) -> void:
	if drag_id == "":
		return
	if not drag_moved and screen_pos.distance_to(drag_start) > 8:
		drag_moved = true
	if not drag_moved:
		return
	var a = Game.find_animal(drag_id)
	if a.is_empty():
		return
	var local = _to_farm_local(screen_pos) + drag_offset
	var px = clamp(local.x / max(1.0, Game.farm_size.x) * 100.0, 1, 99)
	var py = clamp(local.y / max(1.0, Game.farm_size.y) * 100.0, 2, 98)
	a.x = px
	a.y = py

	var target = _animal_at_px(Vector2(px / 100.0 * Game.farm_size.x, py / 100.0 * Game.farm_size.y), drag_id)
	highlight_id = target.id if not target.is_empty() else ""

func _end_drag(screen_pos: Vector2) -> void:
	if drag_id == "":
		return
	var a = Game.find_animal(drag_id)
	var id_snapshot = drag_id
	drag_id = ""
	highlight_id = ""
	if a.is_empty():
		return
	a.dragging = false

	if not drag_moved:
		_toast("Tier %d · %s" % [a.tier, Game.display_name(a)])
		return

	var px = Vector2(a.x / 100.0 * Game.farm_size.x, a.y / 100.0 * Game.farm_size.y)
	var target = _animal_at_px(px, id_snapshot)
	var kind = Game.pairing_kind(a, target)

	if kind == "merge" or kind == "crossbreed":
		_run_merge(a.duplicate(), target.duplicate(), kind)
	elif not target.is_empty() and target.tier != a.tier:
		_toast("Only creatures of the same tier can be combined.")
		a.idle_until = Time.get_ticks_msec() + 700
	elif not target.is_empty():
		_toast("This creature is already at max tier.")
		a.idle_until = Time.get_ticks_msec() + 700
	else:
		a.idle_until = Time.get_ticks_msec() + 700

## Small real-art icon for a species (head art if present, else body) —
## used everywhere a single "species icon" is needed instead of emoji.
const ICON_PET_TEX := preload("res://assets/prototype/sprites/sit_4.png")

func _species_tint(species_id: String) -> Color:
	var sp = Game.SPECIES[Game.species_index(species_id)]
	var hue: float = sp.hue
	if hue < 0.0:
		return Color.WHITE
	return Color.from_hsv(hue / 360.0, 0.55, 1.0)

func _species_icon(species_id: String, box_size: Vector2) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = box_size
	var tex := TextureRect.new()
	tex.texture = ICON_PET_TEX
	tex.modulate = _species_tint(species_id)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(tex)
	return wrap

## Clears an existing slot Control and fills it with a species icon sized
## to the slot's own custom_minimum_size (used by the merge overlay).
func _fill_slot(slot: Control, species_id: String) -> void:
	for c in slot.get_children():
		c.queue_free()
	var icon := _species_icon(species_id, slot.custom_minimum_size)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(icon)

func _run_merge(a: Dictionary, b: Dictionary, kind: String) -> void:
	wander_paused = true
	if critter_views.has(a.id):
		critter_views[a.id].visible = false
	if critter_views.has(b.id):
		critter_views[b.id].visible = false

	_fill_slot(merge_slot_a, a.species_id)
	_fill_slot(merge_slot_b, b.species_id)
	merge_slot_result.visible = false
	merge_status.text = ""
	merge_overlay.visible = true

	await get_tree().create_timer(0.6).timeout

	var result: Dictionary
	if kind == "merge":
		result = Game.merge_animals(a.id, b.id)
	else:
		result = Game.crossbreed_animals(a.id, b.id)

	_sync_critters()

	if result.has("animal"):
		var animal = result.animal
		_fill_slot(merge_slot_result, animal.species_id)
		merge_slot_result.visible = true
		if result.is_rare:
			merge_status.text = "✨ NEW MUTATION! ✨\nTier %d — %s" % [animal.tier, Game.display_name(animal)]
		elif kind == "crossbreed":
			merge_status.text = "🎉 FUSION SUCCESS!\nTier %d — %s" % [animal.tier, Game.display_name(animal)]
		else:
			merge_status.text = "MERGED\nTier %d — %s" % [animal.tier, Game.display_name(animal)]
	else:
		for c in merge_slot_result.get_children():
			c.queue_free()
		var poof := Label.new()
		poof.text = "💨"
		poof.add_theme_font_size_override("font_size", 48)
		poof.set_anchors_preset(Control.PRESET_FULL_RECT)
		poof.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		merge_slot_result.add_child(poof)
		merge_slot_result.visible = true
		merge_status.text = "😢 FUSION FAILED"

	await get_tree().create_timer(1.3).timeout

	merge_overlay.visible = false
	wander_paused = false
	_update_hud()
	Game.save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_game()
