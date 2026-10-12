class_name BattleCreaturePickerCard
extends Button

signal animal_selected(animal_id: String)

const INK := Color("2b211a")
const SKILLS = preload("res://scripts/battle/BattleSkillCatalog.gd")

var animal_id := ""

@onready var image: TextureRect = $CreatureImage
@onready var name_label: Label = $Name
@onready var power_label: Label = $Power
@onready var selected_badge: Label = $SelectedBadge
@onready var shiny: Label = $Shiny

func _ready() -> void:
	pressed.connect(func(): animal_selected.emit(animal_id))
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS

func setup(animal: Dictionary, is_selected: bool) -> void:
	animal_id = str(animal.id)
	image.texture = Game.creature_texture(animal)
	image.modulate = Game.creature_color(animal)
	name_label.text = "%s\nT%d%s" % [Game.display_name(animal), animal.tier, " · SHINY" if animal.rarity == "rare" else ""]
	power_label.text = "⚡ %d" % Game.animal_power(animal)
	selected_badge.visible = is_selected
	shiny.visible = animal.rarity == "rare"
	disabled = is_selected
	tooltip_text = "Already on the team" if is_selected else "Select this creature"
	var skill := SKILLS.for_id(Game.creature_asset_id(animal))
	$SkillName.text = skill.name
	$SkillDescription.text = skill.description
	$SkillName.add_theme_color_override("font_color", Color(skill.color).darkened(0.5))
	tooltip_text += "\n" + skill.name + "\n" + skill.description
	_set_style(is_selected, animal.rarity == "rare")

func _set_style(is_selected: bool, is_shiny: bool) -> void:
	var fill := Color("d8d3c7") if is_selected else Color("fff8df")
	var border := Color("72be5d") if is_selected else (Color("f0bd35") if is_shiny else INK)
	add_theme_stylebox_override("normal", _style(fill, border, 3))
	add_theme_stylebox_override("disabled", _style(fill, border, 3))
	add_theme_stylebox_override("hover", _style(fill.lightened(0.05), border.lightened(0.12), 4))
	add_theme_stylebox_override("pressed", _style(fill.darkened(0.05), border, 4))

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	return style
