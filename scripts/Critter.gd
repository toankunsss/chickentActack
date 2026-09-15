extends Node2D
## Pure view for one animal in Game.animals. Lightweight by design: one
## shared Sprite2D swapping between the same 3 doodle frames (idle-a /
## idle-b / walk) for every pet, tinted per species by hue — instead of a
## heavier multi-part composite. Glows while the pet is actively being
## touched/dragged (Main.gd sets Game animal `dragging = true` the instant
## a touch/click hits it), both as a nice touch and as an at-a-glance signal
## that input reached the pet at all.

const TEX_IDLE_A := preload("res://assets/sprites/sit_1.png")
const TEX_IDLE_B := preload("res://assets/sprites/sit_4.png")
const TEX_WALK := preload("res://assets/sprites/tall_1.png")

const BASE_SIZE := 130.0  # must match Main.gd's BASE_SIZE (hit-test radius = visual size)
const BLINK_MS := 550
const GLOW_COLOR := Color(1.4, 1.25, 0.6)  # additive-ish warm highlight while touched

var animal_id: String = ""
var highlighted: bool = false

@onready var sprite: Sprite2D = $Sprite

func setup(id: String) -> void:
	animal_id = id
	var a = Game.find_animal(id)
	if a.is_empty():
		return
	_apply_tint(a)

func _apply_tint(a: Dictionary) -> void:
	var sp = Game.SPECIES[Game.species_index(a.species_id)]
	var hue: float = sp.hue
	if a.rarity == "rare":
		var rh: float = Game.RARE_HUE_BY_TIER.get(a.tier, 0.0)
		sprite.modulate = Color.from_hsv(rh / 360.0, 0.7, 1.0)
	elif hue >= 0.0:
		sprite.modulate = Color.from_hsv(hue / 360.0, 0.55, 1.0)
	else:
		sprite.modulate = Color.WHITE

func _process(_delta: float) -> void:
	var a = Game.find_animal(animal_id)
	if a.is_empty():
		return

	position = Vector2(a.x / 100.0 * Game.farm_size.x, a.y / 100.0 * Game.farm_size.y)

	var blink_on := (Time.get_ticks_msec() % (BLINK_MS * 2)) >= BLINK_MS
	if a.walking:
		sprite.texture = TEX_WALK
	else:
		sprite.texture = TEX_IDLE_B if blink_on else TEX_IDLE_A

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
	if a.get("dragging", false):
		sprite.modulate = sprite.modulate.lerp(GLOW_COLOR, 0.65)

	z_index = int(a.y)
