class_name CreatureDetailPopup
extends Control

const FARM_CONFIG: FarmConfig = preload("res://data/farm_config.tres")
var closing := false

@onready var panel: Panel = $Dim/Panel
@onready var creature_image: TextureRect = $Dim/Panel/CreatureImage
@onready var sparkle: Label = $Dim/Panel/Sparkle
@onready var title_label: Label = $Dim/Panel/Title
@onready var rarity_label: Label = $Dim/Panel/Rarity
@onready var detail_label: Label = $Dim/Panel/Details
@onready var close_button: Button = $Dim/Panel/Close

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close)
	resized.connect(_center_panel)
	call_deferred("_center_panel")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size.y = 64
	close_button.position.y = 526
	close_button.size.y = 72

func _center_panel() -> void:
	panel.position = (size - panel.size) * 0.5

func show_entry(entry: Dictionary) -> void:
	var unlocked: bool = entry.unlocked
	var species_id: String = entry.species_id
	var tier: int = entry.tier
	var rare: bool = entry.rare
	var creature := {"species_id": species_id, "tier": tier, "rarity": "rare" if rare else "normal"}
	creature_image.texture = Game.creature_texture(creature)
	creature_image.modulate = Game.creature_color(creature) if unlocked else Color.BLACK
	closing = false
	_center_panel()
	sparkle.visible = rare and unlocked
	title_label.text = Game.display_name({"species_id": species_id, "tier": tier, "rarity": "rare" if rare else "normal"}) if unlocked else "UNDISCOVERED"
	rarity_label.text = ("✨ SHINY" if rare else ("🧬 HYBRID" if entry.hybrid else "NORMAL")) if unlocked else "🔒 LOCKED"
	var tier_data: Dictionary = Game.tier_data(tier)
	var income := FARM_CONFIG.base_income_per_tier * tier * (FARM_CONFIG.shiny_income_multiplier if rare else 1.0)
	detail_label.text = ("Tier: %d\nOwned: %d\nIncome: %.1f coin / cycle\nATK: %d   HP: %d   SPD: %d" % [tier, entry.owned_count, income, tier_data.atk, tier_data.hp, tier_data.speed]) if unlocked else "Open eggs or fuse creatures to discover this one."
	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.88, 0.88)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)

func close() -> void:
	if not visible or closing:
		return
	closing = true
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_property(panel, "scale", Vector2(0.92, 0.92), 0.12)
	# Keep the input shield through the touch-release/emulated mouse event.
	tween.chain().tween_interval(0.14)
	tween.chain().tween_callback(func(): visible = false)
