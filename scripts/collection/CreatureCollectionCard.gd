class_name CreatureCollectionCard
extends Button

signal entry_selected(entry: Dictionary)

const INK := Color("2b211a")

var entry: Dictionary = {}
var unlocked := false
var owned_count := 0

@onready var creature_image: TextureRect = $CreatureImage
@onready var sparkle: Label = $Sparkle
@onready var tier_label: Label = $TierLabel
@onready var name_label: Label = $NameLabel
@onready var status_label: Label = $StatusLabel
@onready var locked_overlay: ColorRect = $LockedOverlay
@onready var locked_label: Label = $LockedOverlay/LockedLabel

func _ready() -> void:
	pressed.connect(func(): entry_selected.emit(entry))
	focus_mode = Control.FOCUS_NONE
	pivot_offset = size * 0.5

func setup(value: Dictionary) -> void:
	entry = value
	tooltip_text = "Tap to view details"
	if is_node_ready():
		_refresh_visuals()

func update_state(is_unlocked: bool, count: int) -> void:
	unlocked = is_unlocked
	owned_count = count
	if is_node_ready():
		_refresh_visuals()

func _refresh_visuals() -> void:
	if entry.is_empty():
		return
	var species_id: String = entry.species_id
	var tier: int = entry.tier
	var rare: bool = entry.rare
	var species_index := Game.species_index(species_id)
	var species: Dictionary = Game.SPECIES[species_index]
	var preview := {"species_id": species_id, "tier": tier, "rarity": "rare" if rare else "normal"}
	creature_image.texture = Game.creature_texture(preview)
	creature_image.modulate = Game.creature_color(preview) if unlocked else Color("403b43")
	sparkle.visible = rare and unlocked
	tier_label.text = "T%d" % tier
	name_label.text = Game.display_name({"species_id": species_id, "tier": tier, "rarity": "rare" if rare else "normal"}) if unlocked else "???"
	status_label.text = "OWNED: %d" % owned_count if unlocked else "UNDISCOVERED"
	locked_overlay.visible = not unlocked
	locked_label.text = "?"
	_set_card_style(rare, bool(entry.hybrid), unlocked)

func _creature_color(species: Dictionary, tier: int, rare: bool) -> Color:
	if rare:
		return Color.from_hsv(float(Game.RARE_HUE_BY_TIER.get(tier, 45.0)) / 360.0, 0.7, 1.0)
	var hue: float = float(species.hue)
	return Color.from_hsv(hue / 360.0, 0.55, 1.0) if hue >= 0.0 else Color.WHITE

func _set_card_style(rare: bool, hybrid: bool, is_unlocked: bool) -> void:
	var fill := Color("fff8df") if is_unlocked else Color("d8d3c7")
	var border := Color("f0bd35") if rare and is_unlocked else (Color("9a4ee5") if hybrid and is_unlocked else INK)
	var normal := _style(fill, border, 3)
	var hover := _style(fill.lightened(0.06), border.lightened(0.12), 4)
	var pressed_style := _style(fill.darkened(0.05), border, 4)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", hover)

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(16)
	return style
