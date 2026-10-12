extends CanvasLayer
signal leave_requested
signal rematch_requested
signal retry_reward_requested
const SKIN = preload("res://scripts/battle/BattleUI.gd")
const FONT = preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf")
@onready var panel: PanelContainer = $Overlay/Panel
@onready var title: Label = $Overlay/Panel/Margin/Content/Title
@onready var subtitle: Label = $Overlay/Panel/Margin/Content/Subtitle
@onready var reward: Label = $Overlay/Panel/Margin/Content/Reward
@onready var stats: Label = $Overlay/Panel/Margin/Content/Stats
@onready var leave_button: Button = $Overlay/Panel/Margin/Content/Leave
@onready var rematch_button: Button = $Overlay/Panel/Margin/Content/Rematch
var input_guard_until := 0
var entrance: Tween
var reward_pending := false

func _ready() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("fff0cd")
	frame.border_color = Color("a15c2c")
	frame.set_border_width_all(6)
	frame.border_width_bottom = 10
	frame.set_corner_radius_all(28)
	frame.shadow_color = Color(0.1, 0.05, 0.02, 0.35)
	frame.shadow_size = 14
	panel.add_theme_stylebox_override("panel", frame)
	for label in [title, subtitle, reward, stats]:
		label.add_theme_font_override("font", SKIN.FONT)
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color("51321e"))
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_outline_color", Color("51321e"))
	title.add_theme_constant_override("outline_size", 5)
	reward.add_theme_font_override("font", FONT)
	reward.add_theme_font_size_override("font_size", 30)
	reward.add_theme_color_override("font_color", Color("97600f"))
	SKIN.button(leave_button, Color("88ce54"))
	SKIN.button(rematch_button, Color("e4c99e"))
	leave_button.pressed.connect(func(): _request_exit(false))
	rematch_button.pressed.connect(func(): _request_exit(true))

func show_result(outcome: String, gold: int, xp: int, totals: Dictionary) -> void:
	reward_pending = false
	leave_button.disabled = false
	rematch_button.text = "REMATCH · %d ENERGY" % Game.PlayProgress.BATTLE_COST
	title.text = {"victory": "VICTORY!", "defeat": "DEFEAT", "draw": "DRAW"}.get(outcome, "BATTLE OVER")
	title.add_theme_color_override("font_color", {"victory": Color("b1ed69"), "defeat": Color("ffb195"), "draw": Color("b1e9ff")}.get(outcome, Color.WHITE))
	subtitle.text = {"victory": "Your flock won the battle!", "defeat": "A brave fight! Try a new team.", "draw": "Evenly matched! Try another combo."}.get(outcome, "Battle complete.")
	if outcome == "victory":
		reward.text = "+%d GOLD   +%d FARM XP\nFARM LV.%d  ·  %d/%d XP" % [gold, xp, Game.farm_level, roundi(Game.xp), roundi(Game.xp_to_next)]
		reward.tooltip_text = "Farm XP raises Farm Level. Each level adds +1%% passive Gold income. Current bonus: +%d%%." % roundi((Game.farm_income_multiplier() - 1.0) * 100.0)
	else:
		reward.text = "NO REWARD THIS ROUND"
		reward.tooltip_text = ""
	stats.text = "SKILLS: %d  /  KOs: %d\nDAMAGE: %d" % [totals.casts, totals.kills, roundi(totals.damage)]
	input_guard_until = Time.get_ticks_msec() + 350
	show()
	if entrance and entrance.is_valid(): entrance.kill()
	panel.modulate.a = 0.0
	entrance = create_tween()
	entrance.tween_property(panel, "modulate:a", 1.0, 0.2)
	leave_button.grab_focus()

func show_pending_reward(gold: int, xp: int, totals: Dictionary) -> void:
	show_result("victory", gold, xp, totals)
	reward_pending = true
	subtitle.text = "Reward not saved. Retry before leaving."
	reward.text = "PENDING: %d GOLD / %d XP" % [gold, xp]
	leave_button.disabled = true
	rematch_button.text = "RETRY SAVE"
	rematch_button.grab_focus()

func _request_exit(rematch: bool) -> void:
	if not visible or Time.get_ticks_msec() < input_guard_until: return
	if reward_pending:
		if rematch: retry_reward_requested.emit()
		return
	hide()
	if rematch: rematch_requested.emit()
	else: leave_requested.emit()
