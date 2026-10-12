class_name CollectionScreen
extends Control

const CARD_SCENE := preload("res://scenes/collection/CreatureCollectionCard.tscn")
const FILTER_FONT := preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-Bold.ttf")
const INK := Color("2b211a")
const ACTIVE := Color("69bd55")
const CREAM := Color("fff6dc")
const GOLD := Color("e8b94c")

@onready var count_label: Label = $Header/CollectionCount
@onready var progress: ProgressBar = $Header/CollectionProgress
@onready var grid: GridContainer = $CreatureScroll/GridMargin/CreatureGrid
@onready var empty_label: Label = $CreatureScroll/EmptyLabel
@onready var species_filter: OptionButton = $FilterPanel/SpeciesFilter
@onready var tier_filter: OptionButton = $FilterPanel/TierFilter
@onready var popup: Control = $CreatureDetailPopup

var cards: Array[Control] = []
var active_filter := "all"
var selected_species := ""
var selected_tier := 0
var built := false

func _ready() -> void:
	_bind_filter_button($FilterPanel/Filters/All, "all")
	_bind_filter_button($FilterPanel/Filters/Owned, "owned")
	_bind_filter_button($FilterPanel/Filters/Normal, "normal")
	_bind_filter_button($FilterPanel/Filters/Shiny, "shiny")
	_bind_filter_button($FilterPanel/Filters/Hybrid, "hybrid")
	_setup_option_filters()
	_update_filter_button_styles()

func refresh() -> void:
	if not built:
		_build_cards()
	var discovered_count := 0
	for card in cards:
		var entry: Dictionary = card.entry
		var unlocked: bool = Game.discovered.has(entry.id)
		var owned_count := _owned_count(entry)
		card.update_state(unlocked, owned_count)
		if unlocked:
			discovered_count += 1
	var total := cards.size()
	count_label.text = "%d / %d DISCOVERED" % [discovered_count, total]
	progress.max_value = max(1, total)
	progress.value = discovered_count
	_apply_filters()

func _build_cards() -> void:
	for species in Game.SPECIES:
		for tier in range(1, Game.MAX_TIER + 1):
			for rare in [false, true]:
				var entry := {
					"id": Game.rare_type_id(species.id, tier) if rare else Game.type_id(species.id, tier),
					"species_id": species.id,
					"tier": tier,
					"rare": rare,
					"hybrid": str(species.id).begins_with("hybrid_"),
				}
				var card: Control = CARD_SCENE.instantiate()
				grid.add_child(card)
				card.setup(entry)
				card.entry_selected.connect(_open_entry)
				cards.append(card)
	built = true

func _owned_count(entry: Dictionary) -> int:
	var count := 0
	var rarity := "rare" if entry.rare else "normal"
	for animal in Game.animals:
		if animal.species_id == entry.species_id and int(animal.tier) == int(entry.tier) and animal.rarity == rarity:
			count += 1
	return count

func _bind_filter_button(button: Button, filter_name: String) -> void:
	button.pressed.connect(func():
		active_filter = filter_name
		_update_filter_button_styles()
		_apply_filters()
	)

func _setup_option_filters() -> void:
	species_filter.clear()
	species_filter.add_item("All Species")
	species_filter.set_item_metadata(0, "")
	for species in Game.SPECIES:
		species_filter.add_item(str(species.label))
		species_filter.set_item_metadata(species_filter.item_count - 1, str(species.id))
	species_filter.item_selected.connect(func(index: int):
		selected_species = str(species_filter.get_item_metadata(index))
		_apply_filters()
	)
	tier_filter.clear()
	tier_filter.add_item("All Tiers")
	tier_filter.set_item_metadata(0, 0)
	for tier in range(1, Game.MAX_TIER + 1):
		tier_filter.add_item("Tier %d" % tier)
		tier_filter.set_item_metadata(tier_filter.item_count - 1, tier)
	tier_filter.item_selected.connect(func(index: int):
		selected_tier = int(tier_filter.get_item_metadata(index))
		_apply_filters()
	)
	_style_option_filter(species_filter)
	_style_option_filter(tier_filter)

func _style_option_filter(option: OptionButton) -> void:
	option.fit_to_longest_item = false
	option.add_theme_font_override("font", FILTER_FONT)
	option.add_theme_font_size_override("font_size", 19)
	option.add_theme_color_override("font_color", INK)
	option.add_theme_color_override("font_hover_color", INK)
	option.add_theme_color_override("font_pressed_color", INK)
	option.add_theme_color_override("font_focus_color", INK)
	option.add_theme_stylebox_override("normal", _option_style(CREAM, Color("9b6931"), 2))
	option.add_theme_stylebox_override("hover", _option_style(Color("fffbea"), GOLD, 3))
	option.add_theme_stylebox_override("pressed", _option_style(Color("f7df9e"), Color("895426"), 3))
	option.add_theme_stylebox_override("focus", _option_style(Color.TRANSPARENT, GOLD, 3))
	var menu := option.get_popup()
	menu.transparent_bg = true
	menu.add_theme_font_override("font", FILTER_FONT)
	menu.add_theme_font_size_override("font_size", 18)
	menu.add_theme_color_override("font_color", INK)
	menu.add_theme_color_override("font_hover_color", Color("fff9dc"))
	menu.add_theme_color_override("font_outline_color", Color("4d2e19"))
	menu.add_theme_constant_override("outline_size", 0)
	menu.add_theme_constant_override("v_separation", 9)
	menu.add_theme_stylebox_override("panel", _popup_style())
	menu.add_theme_stylebox_override("hover", _popup_hover_style())
	menu.about_to_popup.connect(func():
		menu.max_size = Vector2i(roundi(option.size.x), roundi(get_viewport_rect().size.y * 0.58))
	)

func _option_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 34
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0.24, 0.12, 0.04, 0.16)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style

func _popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff3d2")
	style.border_color = Color("8b562a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.12, 0.06, 0.02, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style

func _popup_hover_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACTIVE
	style.set_corner_radius_all(10)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _apply_filters() -> void:
	if not built:
		return
	var visible_count := 0
	for card in cards:
		var entry: Dictionary = card.entry
		var show := true
		match active_filter:
			"owned": show = card.unlocked
			"normal": show = not bool(entry.rare)
			"shiny": show = bool(entry.rare)
			"hybrid": show = bool(entry.hybrid)
		show = show and (selected_species.is_empty() or entry.species_id == selected_species)
		show = show and (selected_tier == 0 or int(entry.tier) == selected_tier)
		card.visible = show
		if show:
			visible_count += 1
	empty_label.visible = visible_count == 0

func _update_filter_button_styles() -> void:
	for button in $FilterPanel/Filters.get_children():
		var selected := str(button.get_meta("filter")) == active_filter
		button.add_theme_font_override("font", FILTER_FONT)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("normal", _button_style(ACTIVE if selected else CREAM, Color("39752f") if selected else Color("9b6931"), selected))
		button.add_theme_stylebox_override("hover", _button_style(Color("83d36d") if selected else Color("fffbea"), GOLD, true))
		button.add_theme_stylebox_override("pressed", _button_style(Color("4f9f42") if selected else Color("f4d486"), Color("704321"), false))
		button.add_theme_stylebox_override("focus", _button_style(Color.TRANSPARENT, GOLD, false))
		button.add_theme_color_override("font_color", Color("fffbe9") if selected else INK)
		button.add_theme_color_override("font_hover_color", Color.WHITE if selected else INK)
		button.add_theme_color_override("font_pressed_color", Color.WHITE if selected else INK)
		button.add_theme_color_override("font_outline_color", Color("315c29") if selected else Color.TRANSPARENT)
		button.add_theme_constant_override("outline_size", 2 if selected else 0)

func _button_style(fill: Color, border: Color, raised: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_bottom = 5 if raised else 2
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 7
	style.shadow_color = Color(0.2, 0.1, 0.03, 0.18)
	style.shadow_size = 3 if raised else 1
	style.shadow_offset = Vector2(0, 2)
	return style

func _open_entry(base_entry: Dictionary) -> void:
	var entry := base_entry.duplicate()
	entry["unlocked"] = Game.discovered.has(entry.id)
	entry["owned_count"] = _owned_count(entry)
	popup.show_entry(entry)
