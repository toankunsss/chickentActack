extends Node2D
## Farm view for one animal. Each lineage/tier resolves to one of the 100
## generated chickens and plays its own transparent bounce sheet.

const BASE_SIZE := 80.0  # scene-first Farm board: keeps several chickens readable without covering the ground
const GLOW_COLOR := Color(1.4, 1.25, 0.6)  # additive-ish warm highlight while touched

var animal_id: String = ""
var highlighted: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var name_tag: Label = $NameTag
@onready var rare_badge: Label = $RareBadge

func setup(id: String) -> void:
	animal_id = id
	var a = Game.find_animal(id)
	if a.is_empty():
		return
	_apply_tint(a)
	_update_identity(a)
	queue_redraw()

func _draw() -> void:
	var a = Game.find_animal(animal_id)
	if a.is_empty():
		return
	if a.rarity == "rare" or highlighted or a.get("dragging", false):
		var hue: float = Game.RARE_HUE_BY_TIER.get(a.tier, 45.0) / 360.0
		var glow := Color.from_hsv(hue, 0.55, 1.0, 0.28)
		draw_circle(Vector2.ZERO, 47.0, glow)
		draw_arc(Vector2.ZERO, 47.0, 0.0, TAU, 48, glow.lightened(0.25), 3.0)

func _update_identity(a: Dictionary) -> void:
	name_tag.text = "T%d · #%03d" % [a.tier, Game.creature_asset_id(a)]
	name_tag.tooltip_text = Game.display_name(a)
	rare_badge.visible = a.rarity == "rare"

func _apply_tint(a: Dictionary) -> void:
	sprite.modulate = Game.creature_color(a)

func _process(_delta: float) -> void:
	var a = Game.find_animal(animal_id)
	if a.is_empty():
		return

	position = Vector2(a.x / 100.0 * Game.farm_size.x, a.y / 100.0 * Game.farm_size.y)

	sprite.texture = Game.creature_animation_texture(a, "bounce", Time.get_ticks_msec())

	sprite.flip_h = a.facing < 0

	var scale_mult: float = Game.TIER_SCALE[a.tier - 1] if a.tier - 1 < Game.TIER_SCALE.size() else 1.0
	if highlighted:
		scale_mult *= 1.18
	if a.get("dragging", false):
		scale_mult *= 1.12
	var target_px := BASE_SIZE * scale_mult
	var tex_size: Vector2 = sprite.texture.get_size()
	var s: float = target_px / maxf(tex_size.x, tex_size.y)
	sprite.scale = Vector2(s, s)

	_apply_tint(a)
	_update_identity(a)
	if a.get("dragging", false):
		sprite.modulate = sprite.modulate.lerp(GLOW_COLOR, 0.65)
	queue_redraw()

	z_index = int(a.y)
