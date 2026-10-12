class_name BattleScreen
extends Control

signal battle_requested(opponent_title: String, opponent_power: int)
signal offline_match_requested(snapshot: Dictionary)
const PICKER_CARD_SCENE := preload("res://scenes/battle/BattleCreaturePickerCard.tscn")
const INK := Color("2b211a")
const SKILLS = preload("res://scripts/battle/BattleSkillCatalog.gd")
const OFFLINE = preload("res://scripts/battle/OfflineOpponent.gd")
const SKIN = preload("res://scripts/battle/BattleUI.gd")
const OPPONENT_NAMES := ["MutantKing", "UFO Farmer", "ShinyHunter", "FarmMaster42", "Cosmic Rancher"]
const TITLE_FONT = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf")

@onready var capacity_label: Label = $Header/Capacity
@onready var capacity_bar: ProgressBar = $Header/CapacityBar
@onready var power_label: Label = $Header/Power
@onready var opponent_name: Label = $Opponent/Name
@onready var opponent_power_label: Label = $Opponent/Power
@onready var slots: GridContainer = $TeamBoard/Slots
@onready var find_button: Button = $Actions/FindOpponent
@onready var ready_button: Button = $Actions/Ready
@onready var status_label: Label = $Status
@onready var picker: Control = $CreaturePicker
@onready var picker_list: GridContainer = $CreaturePicker/Dim/Panel/Scroll/List
@onready var picker_close: Button = $CreaturePicker/Dim/Panel/Close
@onready var result_popup: Control = $ResultPopup
@onready var result_title: Label = $ResultPopup/Dim/Panel/Title
@onready var result_detail: Label = $ResultPopup/Dim/Panel/Detail
@onready var result_close: Button = $ResultPopup/Dim/Panel/Close

var opponent_power := 0
var opponent_title := ""
var difficulty := 1
var match_seed := 1
var match_snapshot: Dictionary = {}
var roster_signature := ""
var difficulty_button: Button
var preview: HBoxContainer
var can_interact: Callable

func _ready() -> void:
	for i in slots.get_child_count():
		var slot := slots.get_child(i) as Button
		slot.pressed.connect(func(): _slot_pressed(i))
	find_button.pressed.connect(_find_opponent)
	ready_button.pressed.connect(_start_battle)
	picker_close.pressed.connect(func(): picker.visible = false)
	result_close.pressed.connect(func(): result_popup.visible = false)
	picker.visible = false
	result_popup.visible = false
	$Header/Title.text = "CHICKEN BATTLE"
	$Header/Title.add_theme_font_override("font", TITLE_FONT)
	$Header/Title.add_theme_font_size_override("font_size", 34)
	$Header/Title.add_theme_color_override("font_color", Color("fff4c9"))
	$Header/Title.add_theme_color_override("font_outline_color", Color("714127"))
	$Header/Title.add_theme_constant_override("outline_size", 5)
	$Background.color = Color("fff5d9")
	$Header.add_theme_stylebox_override("panel", _panel_style(Color("e89b47"), Color("8a4c27"), 5, 24, 10))
	$TeamBoard.add_theme_stylebox_override("panel", _panel_style(Color("fff2cd"), Color("8db758"), 4, 22, 8))
	$Opponent.add_theme_stylebox_override("panel", _panel_style(Color("fff8e8"), Color("d79055"), 3, 18, 5))
	$Status.add_theme_stylebox_override("normal", _panel_style(Color("fff0be"), Color("d7ae55"), 2, 14, 3))
	for label in [$Header/Capacity, $Header/Power]:
		label.add_theme_font_override("font", SKIN.FONT)
		label.add_theme_color_override("font_color", Color("fff4c9"))
	$Opponent/Name.add_theme_font_override("font", SKIN.FONT)
	$Opponent/Power.add_theme_font_override("font", SKIN.FONT)
	find_button.text = "NEW AI TEAM"
	ready_button.text = "START BATTLE"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$TeamBoard/BoardTitle.text = "YOUR FLOCK  ·  TAP + TO ADD"
	$TeamBoard/BoardTitle.add_theme_font_override("font", SKIN.FONT)
	$TeamBoard/BoardTitle.add_theme_font_size_override("font_size", 19)
	$TeamBoard/BoardTitle.add_theme_color_override("font_color", Color("4b3525"))
	$TeamBoard.offset_top = 320
	$TeamBoard/Slots.offset_top = 48
	for slot in slots.get_children():
		SKIN.button(slot, Color("fff9e9"))
		slot.clip_text = true
		slot.custom_minimum_size = Vector2(182, 68)
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots.anchor_bottom = 1.0
	slots.offset_bottom = -12
	preview = HBoxContainer.new()
	preview.position = Vector2(26, 230)
	preview.size = Vector2(340, 58)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	difficulty_button = Button.new()
	difficulty_button.position = Vector2(402, 220)
	difficulty_button.size = Vector2(202, 88)
	difficulty_button.text = "NORMAL"
	difficulty_button.pressed.connect(func():
		if can_interact.is_valid() and not can_interact.call(): return
		difficulty = (difficulty + 1) % 3
		difficulty_button.text = OFFLINE.MODES[difficulty]
		_find_opponent())
	add_child(difficulty_button)
	SKIN.button(difficulty_button, Color("e8f4ff"))
	SKIN.button(find_button, Color("ffc65c"))
	SKIN.button(ready_button, Color("78d34d"))
	SKIN.button(picker_close, Color("cfab85"))
	SKIN.button(result_close, Color("83c844"))
	find_button.custom_minimum_size.y = 88
	ready_button.custom_minimum_size.y = 88
	picker_close.size.y = 88
	_find_opponent()
	refresh()

func refresh() -> void:
	Game.battle_team = Game.battle_team.filter(func(id): return not Game.find_animal(str(id)).is_empty())
	if Game.battle_team.size() > mini(15, Game.team_capacity):
		Game.battle_team.resize(mini(15, Game.team_capacity))
	var signature := JSON.stringify(Game.battle_team.map(func(id):
		var animal := Game.find_animal(str(id))
		return [id, animal.get("species_id", ""), animal.get("tier", 1), animal.get("rarity", "normal")]))
	if signature != roster_signature:
		roster_signature = signature
		_rebuild_opponent()
	var team_power := _team_power()
	capacity_label.text = "TEAM  %d / %d" % [Game.battle_team.size(), Game.team_capacity]
	capacity_bar.max_value = Game.team_capacity
	capacity_bar.value = Game.battle_team.size()
	power_label.text = "TEAM POWER: %d" % team_power
	for i in slots.get_child_count():
		var slot := slots.get_child(i) as Button
		if i < Game.battle_team.size():
			var animal := Game.find_animal(str(Game.battle_team[i]))
			slot.icon = Game.creature_texture(animal)
			slot.expand_icon = true
			slot.add_theme_constant_override("icon_max_width", 56)
			slot.add_theme_color_override("icon_normal_color", Game.creature_color(animal))
			slot.add_theme_color_override("icon_hover_color", Game.creature_color(animal).lightened(0.08))
			slot.text = "T%d\n%s" % [animal.tier, Game.display_name(animal).replace(" Chicken", "").replace(" Chick", "")]
			var skill := SKILLS.for_id(Game.creature_asset_id(animal))
			slot.tooltip_text = "%s\n%s\nTap to remove from team" % [skill.name, skill.description]
			slot.add_theme_stylebox_override("normal", _panel_style(Color("fffaf0"), Color("79b955"), 3, 14, 4))
			slot.add_theme_stylebox_override("hover", _panel_style(Color("f2ffd9"), Color("5ba942"), 3, 14, 4))
		else:
			slot.icon = null
			slot.text = "+"
			slot.tooltip_text = "Tap to select a creature"
			slot.add_theme_color_override("font_color", Color("78956b"))
			slot.add_theme_stylebox_override("normal", _panel_style(Color("edf6d9"), Color("b7cc8e"), 2, 14, 2))
			slot.add_theme_stylebox_override("hover", _panel_style(Color("e1f5bd"), Color("82b85d"), 3, 14, 3))
	refresh_energy()
	if opponent_power > 0:
		opponent_power_label.text = "POWER %d" % opponent_power

func refresh_energy() -> void:
	var energy := Game.energy_balance()
	ready_button.text = "BATTLE · %d ENERGY" % Game.PlayProgress.BATTLE_COST if energy >= Game.PlayProgress.BATTLE_COST else "NEED ENERGY"
	ready_button.disabled = Game.battle_team.is_empty() or energy < Game.PlayProgress.BATTLE_COST
	ready_button.tooltip_text = "%d / %d Energy · Refill from optional ads" % [energy, Game.PlayProgress.ENERGY_CAP]

func _slot_pressed(index: int) -> void:
	if can_interact.is_valid() and not can_interact.call(): return
	if index < Game.battle_team.size():
		Game.battle_team.remove_at(index)
		status_label.text = "Creature removed from team"
		Game.save_game()
		refresh()
		return
	_open_picker()

func _open_picker() -> void:
	if can_interact.is_valid() and not can_interact.call(): return
	for child in picker_list.get_children():
		child.free()
	var available := Game.animals.duplicate()
	available.sort_custom(func(a, b): return Game.animal_power(a) > Game.animal_power(b))
	if available.is_empty():
		var empty := Label.new()
		empty.text = "There are no creatures on this farm."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 90)
		picker_list.add_child(empty)
	for animal in available:
		var selected := Game.battle_team.has(animal.id)
		var card: Control = PICKER_CARD_SCENE.instantiate()
		picker_list.add_child(card)
		card.setup(animal, selected)
		card.animal_selected.connect(_add_to_team)
	picker.visible = true

func _add_to_team(animal_id: String) -> void:
	if Game.battle_team.size() >= mini(15, Game.team_capacity) or Game.battle_team.has(animal_id) or Game.find_animal(animal_id).is_empty():
		return
	Game.battle_team.append(animal_id)
	picker.visible = false
	status_label.text = "Creature added to team"
	Game.save_game()
	refresh()

func _team_power() -> int:
	var total := 0
	for id in Game.battle_team:
		var animal := Game.find_animal(str(id))
		if not animal.is_empty():
			total += Game.animal_power(animal)
	return total

func _find_opponent() -> void:
	if can_interact.is_valid() and not can_interact.call(): return
	match_seed = Time.get_ticks_usec()
	_rebuild_opponent()
	status_label.text = "30s · %d Energy after countdown\nWIN: %d Gold + %d per tile · +%d XP" % [Game.PlayProgress.BATTLE_COST, Game.PlayProgress.WIN_GOLD, Game.PlayProgress.WIN_GOLD_PER_CELL, Game.PlayProgress.WIN_XP]

func _rebuild_opponent() -> void:
	match_snapshot = OFFLINE.build(Game, difficulty, match_seed)
	opponent_title = match_snapshot.opponent
	opponent_power = match_snapshot.opponent_power
	opponent_name.text = opponent_title
	opponent_power_label.text = "POWER %d" % opponent_power
	if not is_instance_valid(preview): return
	for child in preview.get_children(): child.free()
	for combatant in match_snapshot.enemies.slice(0, 5):
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(52, 52)
		image.texture = Game.creature_texture(combatant.animal)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(image)
	if match_snapshot.enemies.size() > 5:
		var more := Label.new()
		more.text = "+%d" % (match_snapshot.enemies.size() - 5)
		more.add_theme_color_override("font_color", INK)
		preview.add_child(more)

func _start_battle() -> void:
	if can_interact.is_valid() and not can_interact.call(): return
	if Game.energy_balance() < Game.PlayProgress.BATTLE_COST:
		status_label.text = "Not enough Energy. Watch an optional Energy ad on the Farm."
		return
	var team_power := _team_power()
	if team_power <= 0:
		status_label.text = "Select at least one creature"
		return
	refresh()
	_rebuild_opponent()
	offline_match_requested.emit(match_snapshot.duplicate(true))

func _slot_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

func _panel_style(fill: Color, border: Color, width: int, radius: int, shadow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.24, 0.13, 0.06, 0.20)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, maxf(1.0, shadow * 0.45))
	return style
