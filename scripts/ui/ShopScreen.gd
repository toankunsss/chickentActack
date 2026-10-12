extends Control
## The shop owns presentation only; App/Game remain the transaction authority.
signal egg_requested(level: int)
signal item_requested(item_id: String)
signal rates_requested(level: int)
signal tab_selected(category: String)
signal chicken_requested(offer_id: String, day: int)

const SHOP = preload("res://scripts/config/EggShopConfig.gd")
const BOLD = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-Bold.ttf")
const CHUNKY = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf")
const COIN = preload("res://assets/icons/coin_icon_128px.png")
const GEM = preload("res://assets/icons/gem_icon_128px.png")
const HEADER = preload("res://assets/ui/shop/shop-awning-v1.png")
const CARD = preload("res://assets/ui/shop/shop-card-v1.png")
const FEED = preload("res://assets/ui/shop/shop-feed-v1.png")
const INK := Color("51321e")
const TAB_HINTS := {
	"eggs": "Eggs hatch instantly. Check the odds before buying.",
	"chickens": "Tier 1 starters from this planet's two evolution lines.",
	"items": "One-time purchases with Gold. Rewards apply instantly.",
}

@onready var list: GridContainer = $Scroll/ShopList
@onready var scroll: ScrollContainer = $Scroll
@onready var feedback: Label = $Feedback
var cards: Array[Dictionary] = []
var selected_tab := "eggs"
var roster_planet := ""
var roster_day := -1
var daily_offers: Dictionary = {}
var daily_elapsed := 0.0
var destination_name := "Earth"
var card_texture: Texture2D
var notice_until := 0
var can_interact: Callable
var trimmed_textures: Dictionary = {}

func _ready() -> void:
	$Background.add_theme_stylebox_override("panel", _box(Color("f1dfb3"), Color("97613a"), 0, 0))
	$Header.texture = _trimmed_texture(HEADER)
	card_texture = _trimmed_texture(CARD)
	$Header/Title.add_theme_font_override("font", CHUNKY)
	$Header/Title.add_theme_font_size_override("font_size", 38)
	$Header/Title.add_theme_color_override("font_color", Color("fff5d2"))
	$Header/Title.add_theme_color_override("font_outline_color", Color("6f3516"))
	$Header/Title.add_theme_constant_override("outline_size", 5)
	for label in [$Context, feedback]:
		label.add_theme_font_override("font", BOLD)
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_color", INK)
	$Context.add_theme_stylebox_override("normal", _box(Color("e0efbf"), Color("779352"), 14, 2))
	for tab in $Tabs.get_children():
		_skin_button(tab, Color("e8c992"), INK)
		tab.add_theme_font_size_override("font_size", 27)
		tab.pressed.connect(select_tab.bind(str(tab.name).to_lower()))
	for item in SHOP.ITEMS:
		var level := int(item.level)
		var card := _make_card("EggLv%d" % level, "eggs", "EGG Lv.%d" % level,
			Game.egg_texture(level), "Tier 1 only" if level == 1 else "Random Tier 1–%d" % level, int(item.price))
		card.buy.set_meta("egg_price", int(item.price))
		card["egg_level"] = level
		card.buy.add_to_group("egg_shop_buy")
		card.buy.pressed.connect(func():
			if _purchase_context_valid(): egg_requested.emit(level))
		card.secondary.text = "DROP RATE"
		card.secondary.pressed.connect(func(): rates_requested.emit(level))
	var food := _make_card("Food", "items", "CHICKEN FEED", _trimmed_texture(FEED),
		"+%d XP  /  +%d Gold" % [Game.FOOD_XP, Game.FOOD_COIN_BONUS], Game.FOOD_COST)
	food.buy.pressed.connect(func(): item_requested.emit("food"))
	food.secondary.hide()
	food.footer.text = "Instant farm reward"
	var gems := _make_card("Gems", "items", "GEM POUCH", GEM, "+%d Gems" % Game.GEM_POUCH_AMOUNT, Game.GEM_POUCH_COST)
	gems.buy.pressed.connect(func(): item_requested.emit("gems"))
	gems.secondary.hide()
	gems.footer.text = "Adds to your wallet"
	refresh("Earth")
	select_tab("eggs")

func _trimmed_texture(source: Texture2D) -> Texture2D:
	# Crop transparent padding at render time, keeping the generated PNG intact.
	if trimmed_textures.has(source):
		return trimmed_textures[source]
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = source.get_image().get_used_rect()
	trimmed_textures[source] = texture
	return texture

func _make_card(node_name: String, kind: String, caption: String, art: Texture2D, detail: String, price: int) -> Dictionary:
	var panel := Control.new()
	panel.name = node_name
	panel.custom_minimum_size = Vector2(0, 524)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	list.add_child(panel)
	var frame := TextureRect.new()
	frame.texture = card_texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_label := _label(panel, caption, 24, 44, 44, 27)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = caption
	name_label.add_theme_font_override("font", CHUNKY)
	var image := TextureRect.new()
	image.texture = _trimmed_texture(art)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(image)
	image.anchor_left = 0.5
	image.anchor_right = 0.5
	image.offset_left = -80
	image.offset_right = 80
	image.offset_top = 94
	image.offset_bottom = 198
	var description := _label(panel, detail, 24, 200, 34, 22)
	var destination := _label(panel, "", 24, 236, 30, 22)
	destination.add_theme_color_override("font_color", Color("315d50"))
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(price_row)
	price_row.anchor_right = 1.0
	price_row.offset_left = 24
	price_row.offset_right = -24
	price_row.offset_top = 272
	price_row.offset_bottom = 308
	var coin := TextureRect.new()
	coin.texture = COIN
	coin.custom_minimum_size = Vector2(32, 32)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(coin)
	var price_label := Label.new()
	price_label.text = _number(price)
	price_label.add_theme_font_override("font", CHUNKY)
	price_label.add_theme_font_size_override("font_size", 28)
	price_label.add_theme_color_override("font_color", Color("905411"))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(price_label)
	var buy := _button(panel, "Buy", "BUY", 314, Color("83c844"), Color("254c16"))
	var secondary := _button(panel, "DropRate", "", 412, Color("d5ebf1"), Color("295267"))
	secondary.add_theme_font_size_override("font_size", 24)
	var footer := _label(panel, "", 24, 428, 54, 22)
	var result := {"panel": panel, "kind": kind, "name": name_label, "image": image,
		"description": description, "destination": destination, "price": price, "price_label": price_label,
		"buy": buy, "secondary": secondary, "footer": footer}
	cards.append(result)
	return result

func _label(parent: Control, text: String, inset: float, top: float, height: float, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BOLD)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.anchor_right = 1.0
	label.offset_left = inset
	label.offset_right = -inset
	label.offset_top = top
	label.offset_bottom = top + height
	return label

func _button(parent: Control, node_name: String, caption: String, top: float, color: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	# Let touch drags reach the enclosing ScrollContainer. A released tap still
	# activates the button; a swipe is cancelled by SCROLL_BEGIN notification.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	_skin_button(button, color, text_color)
	parent.add_child(button)
	button.anchor_right = 1.0
	button.offset_left = 32
	button.offset_right = -32
	button.offset_top = top
	button.offset_bottom = top + 88
	return button

func _skin_button(button: Button, fill: Color, text_color: Color) -> void:
	button.add_theme_font_override("font", CHUNKY)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_hover_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color("746858"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := fill
		if state == "hover": color = fill.lightened(0.12)
		if state == "pressed": color = fill.darkened(0.1)
		if state == "disabled": color = Color("d5c9b6")
		var style := _box(color, color.darkened(0.4), 18, 3)
		style.border_width_bottom = 6 if state != "pressed" else 2
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state, style)
	var focus := _box(Color.TRANSPARENT, Color("f8ab28"), 18, 3)
	button.add_theme_stylebox_override("focus", focus)

func _box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(width)
	return style

func _number(value: int) -> String:
	var raw := str(value)
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result

func select_tab(category: String) -> void:
	if not TAB_HINTS.has(category) or (can_interact.is_valid() and not can_interact.call()):
		return
	selected_tab = category
	for card in cards:
		card.panel.visible = card.kind == category and bool(card.get("daily_active", true))
	for tab in $Tabs.get_children():
		var selected := str(tab.name).to_lower() == category
		tab.set_pressed_no_signal(selected)
		_skin_button(tab, Color("ffbf50") if selected else Color("e5c995"), INK)
		# Toggle buttons use the pressed style for the selected category.
		if selected:
			tab.add_theme_stylebox_override("pressed", _box(Color("ffbf50"), Color("9b5b25"), 18, 4))
	scroll.scroll_vertical = 0
	notice_until = 0
	feedback.text = TAB_HINTS[category]
	feedback.add_theme_color_override("font_color", INK)
	tab_selected.emit(category)

func tutorial_first_chicken_buy_button() -> Button:
	for card in cards:
		if str(card.get("kind", "")) == "chickens" and is_instance_valid(card.get("buy")):
			return card.buy as Button
	return null

func refresh(_map_name: String) -> void:
	if not is_node_ready(): return
	# Read the same authority used by transactions, never a stale display argument.
	destination_name = Game.current_planet.capitalize()
	daily_offers = Game.daily_shop()
	var next_day := int(daily_offers.get("day", -1))
	if roster_planet != Game.current_planet or roster_day != next_day:
		roster_planet = Game.current_planet
		roster_day = next_day
		for index in range(cards.size() - 1, -1, -1):
			if cards[index].kind == "chickens":
				var old: Control = cards[index].panel
				list.remove_child(old)
				old.queue_free()
				cards.remove_at(index)
		for offer in daily_offers.get("chickens", []):
			var creature := {"species_id": offer.species, "tier": offer.tier, "rarity": "normal"}
			var card := _make_card("Daily_" + str(offer.id).replace(":", "_"), "chickens", Game.display_name(creature),
				Game.creature_texture(creature), "Tier %d · %s" % [offer.tier, "Starter" if offer.tier == 1 else "Daily pick"], offer.price)
			card["tier"] = offer.tier
			card.image.modulate = Game.creature_color(creature)
			var offer_day := roster_day
			card.buy.pressed.connect(func():
				if _purchase_context_valid(): chicken_requested.emit(str(offer.id), offer_day))
			card.secondary.hide()
			card.footer.text = "Joins %s Farm" % destination_name
			card.panel.visible = selected_tab == "chickens"
	var count := Game.animals_for_map().size()
	$Header/Title.text = "%s SHOP" % destination_name.to_upper()
	$Context.text = "BUYING FOR: %s · %d / %d CHICKENS\nDAILY PICKS · Reset 00:00 (UTC+7)" % [destination_name.to_upper(), count, Game.MAX_ANIMALS]
	for card in cards:
		card["daily_active"] = card.kind != "eggs" or daily_offers.get("eggs", []).has(card.get("egg_level", 0))
		card.panel.visible = card.kind == selected_tab and card.daily_active
		card.destination.text = "TO %s FARM" % destination_name.to_upper() if card.kind != "items" else "SHARED REWARDS"
		var full: bool = card.kind != "items" and count >= Game.MAX_ANIMALS
		var affordable: bool = Game.coins >= card.price
		card.buy.disabled = full or not affordable or daily_offers.is_empty()
		card.buy.text = "FARM FULL" if full else ("BUY" if affordable else "NEED GOLD")
		card.price_label.add_theme_color_override("font_color", Color("905411") if affordable else Color("b84732"))

func _purchase_context_valid() -> bool:
	if can_interact.is_valid() and not can_interact.call(): return false
	if roster_planet != Game.current_planet:
		refresh(Game.current_planet.capitalize())
		show_notice("Planet changed. Check the destination and tap BUY again.", false)
		return false
	var latest := Game.daily_shop()
	if latest.is_empty() or int(latest.day) != roster_day:
		refresh(Game.current_planet.capitalize())
		show_notice("Daily picks changed. Check the offer and tap BUY again.", false)
		return false
	return true

func show_notice(message: String, success := true) -> void:
	feedback.text = message
	feedback.add_theme_color_override("font_color", Color("286928") if success else Color("b34229"))
	notice_until = Time.get_ticks_msec() + 4500

func _process(_delta: float) -> void:
	daily_elapsed += _delta
	if daily_elapsed >= 1.0 and is_visible_in_tree():
		daily_elapsed = 0.0
		if not can_interact.is_valid() or can_interact.call():
			if Game.PlayProgress.day_at(int(Time.get_unix_time_from_system())) > roster_day: refresh(destination_name)
	if notice_until > 0 and Time.get_ticks_msec() >= notice_until:
		notice_until = 0
		feedback.text = TAB_HINTS[selected_tab]
		feedback.add_theme_color_override("font_color", INK)
