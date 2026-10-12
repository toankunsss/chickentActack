extends Control
## Scene-first application controller. Layout belongs to Game.tscn; this
## script only binds live Game data, creates repeated data cards and handles
## interaction. It is intentionally separate from the legacy code-built UI.

const CritterScene := preload("res://scenes/Critter.tscn")
const MergeBurstScene := preload("res://scripts/farm/MergeBurst.gd")
const NewDiscoveryVFXScene := preload("res://scripts/farm/NewDiscoveryVFX.gd")
const RaidCannonVisualScene := preload("res://scripts/farm/RaidCannonVisual.gd")
const TutorialOverlayScene := preload("res://scenes/ui/TutorialOverlay.tscn")
const FARM_CONFIG: FarmConfig = preload("res://data/farm_config.tres")
const EggUpgrade = preload("res://scripts/config/EggUpgradeConfig.gd")
const EggDropRates = preload("res://scripts/config/EggDropRateConfig.gd")
const EggShop = preload("res://scripts/config/EggShopConfig.gd")
const FONT_BALOO := preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-SemiBold.ttf")
const FONT_BALOO_BOLD := preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-Bold.ttf")
const FONT_BALOO_EXTRA_BOLD := preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf")
const EGG_UPGRADE_PANEL_TEXTURE := preload("res://assets/ui/egg-upgrade/egg-upgrade-panel-v2.png")
const UPGRADE_SUCCESS_RAYS := preload("res://assets/ui/egg-upgrade/upgrade-success-rays.png")
const BUTTON_PLATE_TEXTURE := preload("res://assets/ui/egg-upgrade/button-plate-neutral.png")
const FUSION_PANEL_TEXTURE := preload("res://assets/ui/fusion/fusion-panel-frame.png")
const RAID_LAUNCH_DECK_TEXTURE := preload("res://assets/ui/raid-launch-deck.png")
const INK := Color("241a14")
const GREEN := Color("7ed36b")
const ORANGE := Color("ffb238")
const RED := Color("ef7373")
const PLANETS := {
	"volcano": {"name": "Volcano", "sky": Color("3d0910"), "ground": Color("20191a")},
	"earth": {"name": "Earth", "sky": Color("87cff8"), "ground": Color("75bd68")},
	"saturn": {"name": "Saturn", "sky": Color("26104d"), "ground": Color("4c2f72")},
	"mars": {"name": "Mars", "sky": Color("9d3f27"), "ground": Color("713624")},
	"ice": {"name": "Ice", "sky": Color("d9f2ff"), "ground": Color("b6dfef")},
}
const MAP_ORDER := ["earth", "mars", "volcano", "ice", "saturn"]
const MAP_GROUND_COLORS := {
	"earth": Color("b8f03f"), "mars": Color("e58a50"),
	"volcano": Color("353138"), "ice": Color("d8f3fb"), "saturn": Color("8358b7"),
}
const MAP_BORDER_COLORS := {
	"earth": Color("241a14"), "mars": Color("713923"),
	"volcano": Color("160f14"), "ice": Color("315f82"), "saturn": Color("35204f"),
}
const MAP_SCENES := {
	"earth": preload("res://scenes/farm/FarmMap.tscn"),
	"mars": preload("res://scenes/farm/FarmMapMars.tscn"),
	"volcano": preload("res://scenes/farm/FarmMapVolcano.tscn"),
	"ice": preload("res://scenes/farm/FarmMapIce.tscn"),
	"saturn": preload("res://scenes/farm/FarmMapSaturn.tscn"),
}

@onready var coin_label: Label = %CoinValue
@onready var gem_label: Label = %GemValue
@onready var dna_label: Label = %DnaValue
@onready var level_label: Label = %LevelValue
@onready var xp_bar: ProgressBar = get_node_or_null("%XpBar") as ProgressBar
@onready var farm_screen: Control = $UI/FarmScreen
@onready var farm_map: Node2D = $UI/FarmScreen/MapSlot/FarmMap
@onready var farm_ground: Panel = $UI/FarmScreen/MapSlot/FarmMap/FarmGround
@onready var farm_layer: Node2D = $UI/FarmScreen/MapSlot/FarmMap/MouseLayer/FarmCritterLayer
@onready var farm_overlay: Control = $UI/FarmScreen/OverlayLayer
@onready var collection_screen: Control = $CollectionScreen
@onready var battle_screen: Control = $BattleScreen
@onready var battle_arena_screen: BattleArenaScreen = $BattleArenaScreen
@onready var toast_panel: Panel = $UI/FarmScreen/NotificationTicker
@onready var toast_label: Label = $UI/FarmScreen/NotificationTicker/ToastLabel

var screens: Dictionary = {}
var critter_views: Dictionary = {}
var current_screen := "farm"
var income_elapsed := 0.0
var save_elapsed := 0.0
var toast_elapsed := 0.0
var toast_tween: Tween
var toast_queue: Array[Dictionary] = []
var toast_running := false
var screen_transition: Tween
var drag_id := ""
var drag_planet := ""
var selected_animal_id := ""
var drag_start := Vector2.ZERO
var drag_moved := false
var current_planet := "earth"
var farm_manager: FarmManager
var creature_ai := CreatureAI.new()
var egg_views: Dictionary = {}
var friendly_ufo_in_flight := false
var delivery_status_label: Label
var delivery_progress_bar: ProgressBar
var upgrade_menu: Panel
var delivery_upgrade_label: Label
var cannon_upgrade_label: Label
var cannon_upgrade_button: Button
var egg_upgrade_summary: Label
var egg_upgrade_rates: Control
var egg_upgrade_rate_rows: Array[Dictionary] = []
var egg_upgrade_button: Button
var egg_upgrade_busy := false
var egg_upgrade_closing := false
var egg_upgrade_feedback_until := 0
var egg_upgrade_modal_layer: Control
var egg_upgrade_canvas: CanvasLayer
var egg_upgrade_dim: ColorRect
var egg_upgrade_close_button: TextureButton
var egg_upgrade_close_base_position := Vector2(590.0, 205.0)
var egg_upgrade_feedback: Label
var egg_upgrade_success_panel: Control
var egg_upgrade_success_levels: Label
var egg_upgrade_success_rows: Array[Dictionary] = []
var egg_upgrade_confirm_chance: Label
var egg_upgrade_confirm_failure: Label
var egg_upgrade_confirm_panel: Control
var egg_upgrade_confirm_levels: Label
var egg_upgrade_confirm_cost: Label
var egg_upgrade_confirm_rows: Array[Dictionary] = []
var egg_rate_dialog: Control
var shop_view: Control
var raid_button: Button
var raid_status_label: Label
var raid_hp_bar: ProgressBar
var raid_hp_label: Label
var raid_boss_group: Control
var raid_boss_visual: TextureRect
var raid_canvas: CanvasLayer
var raid_overlay: Control
var raid_blocker: Panel
var raid_cannon_visual: Control
var raid_fire_button: Button
var raid_entrance_played := false
var raid_hit_flash_timer := 0.0
var raid_warning_cooldown := 0.0
var raid_warning_label: Label
var map_switch_button: Button
var fusion_canvas: CanvasLayer
var fusion_modal_layer: Control
var fusion_panel: Control
var fusion_left_image: TextureRect
var fusion_right_image: TextureRect
var fusion_pair_label: Label
var fusion_chance_label: RichTextLabel
var fusion_left_name: Label
var fusion_right_name: Label
var discovery_overlay: Control
var collection_canvas: CanvasLayer
var modal_input_guard_until := 0
var fusion_closing := false
var fusion_resolving := false
var fusion_result_showing := false
var fusion_result: Dictionary = {}
var fusion_result_content: Control
var fusion_result_image: TextureRect
var fusion_result_mark: Label
var fusion_result_message: Label
var pending_fusion: Array[String] = []
var pending_fusion_planet := ""
# Legacy development helpers below are deliberately unreachable in production.
# These nullable references keep old editor-only helper bodies parse-safe while
# no DEV control is created, laid out, or exposed by the release runtime.
var dev_panel: Panel
var dev_toggle_button: Button
var dev_scroll: ScrollContainer
var dev_button_list: VBoxContainer
var dev_reset_dialog: ConfirmationDialog
var dev_pending_reset := "empty"
var effects_layer: Node2D
var tutorial: TutorialController
var tutorial_bootstrap_requested := false
var rewards_hub: CanvasLayer
var settings_popup: CanvasLayer
var settings_button: Button
var energy_refresh_elapsed := 0.0

func _ready() -> void:
	_organize_scene_layers()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")
	_ensure_farm_runtime_layers()
	var app_theme := Theme.new()
	app_theme.default_font = FONT_BALOO
	app_theme.default_font_size = 22
	app_theme.set_font("font", "Button", FONT_BALOO_BOLD)
	app_theme.set_font_size("font_size", "Button", 22)
	app_theme.set_font("normal_font", "RichTextLabel", FONT_BALOO)
	app_theme.set_font("bold_font", "RichTextLabel", FONT_BALOO_BOLD)
	app_theme.set_color("font_color", "Label", INK)
	app_theme.set_color("font_outline_color", "Label", Color.TRANSPARENT)
	self.theme = app_theme
	collection_canvas = CanvasLayer.new()
	collection_canvas.name = "CollectionDetailCanvas"
	collection_canvas.layer = 100
	add_child(collection_canvas)
	collection_screen.popup.reparent(collection_canvas)
	collection_screen.popup.theme = app_theme
	collection_screen.popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style_fusion_action_button(collection_screen.popup.close_button, Color("78c43b"), INK)
	screens = {
		"farm": farm_screen, "mutations": collection_screen,
		"battle": battle_screen, "battle_match": battle_arena_screen,
		"adventure": %AdventureScreen, "shop": %ShopScreen,
	}
	battle_screen.battle_requested.connect(_open_battle_match)
	battle_screen.offline_match_requested.connect(func(snapshot):
		_show_screen("battle_match")
		if current_screen == "battle_match": battle_arena_screen.start_snapshot(snapshot))
	battle_screen.can_interact = func(): return not _has_blocking_modal()
	battle_screen.picker.visibility_changed.connect(func():
		if not battle_screen.picker.visible: modal_input_guard_until = Time.get_ticks_msec() + 180)
	battle_arena_screen.battle_finished.connect(func():
		_apply_level_ups()
		_refresh_all()
		Game.save_game())
	battle_arena_screen.exit_requested.connect(func(): _show_screen("battle"))
	for node in get_tree().get_nodes_in_group("screen_nav"):
		node.pressed.connect(func(): _show_screen(node.get_meta("screen_name")))
	for button in get_tree().get_nodes_in_group("shop_buy"):
		button.pressed.connect(func(): _buy_item(button.get_meta("item_id")))
		button.add_theme_stylebox_override("normal", _card_style(Color("a9d92f")))
		button.add_theme_stylebox_override("hover", _card_style(Color("bcea3e")))
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color.WHITE)
	_connect_optional_button("UI/FarmScreen/MapSlot/FarmMap/Decorations/Elements/Fire", func(): _switch_planet("volcano"))
	_connect_optional_button("UI/FarmScreen/MapSlot/FarmMap/Decorations/Elements/Nature", func(): _switch_planet("earth"))
	_connect_optional_button("UI/FarmScreen/MapSlot/FarmMap/Decorations/Elements/Stone", func(): _switch_planet("saturn"))
	_connect_optional_button("UI/FarmScreen/MapSlot/FarmMap/Decorations/Elements/Ice", func(): _switch_planet("ice"))
	Game.load_game()
	_build_egg_shop()
	_replace_farm_map(str(Game.current_planet), false)
	_setup_farm_system()
	rewards_hub = preload("res://scripts/ui/RewardsHub.gd").new()
	add_child(rewards_hub)
	rewards_hub.attach_shortcuts(farm_screen)
	rewards_hub.can_open = func(): return current_screen == "farm" and not _has_blocking_modal() and not farm_manager.raids.active and not (is_instance_valid(tutorial) and tutorial.visible)
	rewards_hub.wallet_changed.connect(_refresh_all)
	rewards_hub.closed.connect(func(): modal_input_guard_until = Time.get_ticks_msec() + 180)
	if Game.save_load_status == "invalid":
		_toast("Save could not be loaded. Your existing files are preserved; autosave is disabled.", 8.0)
	elif Game.save_load_status == "recovered":
		_toast("Progress restored from your last valid backup.", 5.0)
	_sync_critters()
	_sync_egg_views()
	_refresh_all()
	_show_screen(_startup_screen())
	_setup_tutorial()
	_setup_settings()

func _connect_optional_button(path: NodePath, action: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null:
		button.pressed.connect(action)

func _setup_tutorial() -> void:
	tutorial = TutorialOverlayScene.instantiate() as TutorialController
	add_child(tutorial)
	tutorial.bootstrap_egg_requested.connect(_tutorial_bootstrap_egg)
	tutorial.setup(self)
	var help := get_node_or_null("UI/TopHUD/TopBar/Help") as Button
	if help != null:
		help.pressed.connect(func(): tutorial.replay())
	if is_instance_valid(shop_view):
		shop_view.tab_selected.connect(func(category: String):
			if category == "chickens": tutorial.accept_event("tab_chickens")
		)

func _tutorial_bootstrap_egg() -> void:
	if tutorial_bootstrap_requested or tutorial == null or tutorial.replay_mode:
		return
	if not Game.unopened_eggs.filter(func(egg): return str(egg.get("map_id", "earth")) == current_planet).is_empty():
		return
	if farm_manager != null and farm_manager.eggs.can_receive():
		tutorial_bootstrap_requested = true
		farm_manager.eggs.deliver()
		Game.save_game()

func tutorial_has_merge_pair() -> bool:
	return tutorial_merge_pair().size() == 2

func tutorial_merge_pair() -> Array[String]:
	var animals := Game.animals_for_map(current_planet)
	for i in range(animals.size()):
		for j in range(i + 1, animals.size()):
			if Game.pairing_kind(animals[i], animals[j]) == "merge":
				return [str(animals[i].id), str(animals[j].id)]
	return []

func tutorial_pair_buy_button() -> Button:
	if is_instance_valid(shop_view) and shop_view.has_method("tutorial_first_chicken_buy_button"):
		return shop_view.tutorial_first_chicken_buy_button()
	return null

func tutorial_merge_target() -> Control:
	return farm_screen if tutorial_has_merge_pair() else null

func tutorial_merge_rect() -> Rect2:
	var pair := tutorial_merge_pair()
	if pair.size() != 2:
		return Rect2()
	var first: Node2D = critter_views.get(pair[0]) as Node2D
	var second: Node2D = critter_views.get(pair[1]) as Node2D
	if not is_instance_valid(first) or not is_instance_valid(second):
		return Rect2()
	var first_rect := Rect2(first.global_position - Vector2(52, 52), Vector2(104, 104))
	var second_rect := Rect2(second.global_position - Vector2(52, 52), Vector2(104, 104))
	return first_rect.merge(second_rect)

func tutorial_egg_target() -> Control:
	for egg_id in egg_views:
		var view: Control = egg_views[egg_id] as Control
		if is_instance_valid(view) and view.visible:
			return view
	return null

func _ensure_farm_runtime_layers() -> void:
	effects_layer = farm_map.get_node_or_null("Effects") as Node2D
	if effects_layer == null:
		effects_layer = Node2D.new()
		effects_layer.name = "Effects"
		effects_layer.z_index = 900
		farm_map.add_child(effects_layer)

func _setup_farm_system() -> void:
	farm_manager = FarmManager.new()
	add_child(farm_manager)
	farm_manager.setup(FARM_CONFIG)
	farm_manager.eggs.egg_added.connect(_on_egg_added)
	farm_manager.eggs.egg_hatched.connect(_on_egg_hatched)
	farm_manager.eggs.capacity_full.connect(func(): _toast("The hatchery is full! Open an egg so the UFO can continue."))
	farm_manager.delivery.delivery_started.connect(_play_friendly_ufo)
	farm_manager.income.income_collected.connect(_on_income_collected)
	farm_manager.raids.raid_started.connect(_on_raid_started)
	farm_manager.raids.raid_updated.connect(_on_raid_updated)
	farm_manager.raids.raid_defeated.connect(_on_raid_defeated)
	farm_manager.raids.creature_abducted.connect(_on_creature_abducted)
	_bind_farm_hud()

func _qa_show_upgrade_success() -> void:
	egg_upgrade_modal_layer.visible = true
	_show_upgrade_success(5, 6)
	assert(egg_upgrade_success_panel.visible and egg_upgrade_close_button.visible, "Image close control must remain visible on the success modal")

func _qa_show_upgrade_warning() -> void:
	egg_upgrade_modal_layer.visible = true
	egg_upgrade_close_button.visible = true
	egg_upgrade_close_button.disabled = false
	_show_egg_upgrade_confirmation()
	assert(egg_upgrade_confirm_panel.visible and egg_upgrade_close_button.visible, "Image close control must remain visible on the warning modal")

func _qa_show_fusion_modal() -> void:
	var species: Array = Game.species_ids_for_map()
	var left := {"species_id": str(species[0]), "tier": 2, "rarity": "normal"}
	var right := {"species_id": str(species[1]), "tier": 2, "rarity": "normal"}
	_show_fusion_modal(left, right, 0.62)

func _qa_test_upgrade_modal() -> void:
	assert(egg_upgrade_rate_rows.size() == 5, "Egg Upgrade must render five visual egg rows")
	assert(egg_upgrade_modal_layer.mouse_filter == Control.MOUSE_FILTER_STOP, "Modal layer must block clicks from reaching the farm")
	assert(egg_upgrade_canvas.layer > 0, "Egg Upgrade modal must use a dedicated top CanvasLayer")
	var close := egg_upgrade_close_button
	assert(close.get_parent() == egg_upgrade_modal_layer and close.texture_normal != null, "Close button must be a scene-authored image node in the shared modal layer")
	assert(close.mouse_filter == Control.MOUSE_FILTER_STOP, "Close button must own its pointer input")
	assert(close.pressed.is_connected(_close_upgrade_menu), "Close icon must be connected to the modal close action")
	_toggle_upgrade_menu()
	await get_tree().create_timer(0.35).timeout
	assert(egg_upgrade_modal_layer.visible and upgrade_menu.visible, "Upgrade modal must open")
	assert(egg_upgrade_dim.mouse_filter == Control.MOUSE_FILTER_STOP and egg_upgrade_dim.size == egg_upgrade_modal_layer.size, "Full-screen dim must block every click to screens behind it")
	var close_rect := close.get_global_rect()
	assert(close_rect.size.x >= 64.0 and close_rect.size.y >= 64.0, "Close icon must have a finger-friendly hit area")
	assert(close_rect.position.distance_to(egg_upgrade_close_base_position) < 1.0, "Close icon must use the position authored in the FarmScreen scene")
	var planet_before_blocked_click := current_planet
	_cycle_farm_map()
	assert(current_planet == planet_before_blocked_click, "Map switch must be ignored while Egg Upgrade is open")
	close.pressed.emit()
	await get_tree().create_timer(0.40).timeout
	assert(not egg_upgrade_modal_layer.visible and not upgrade_menu.visible, "Close button flow must fully hide the modal")
	assert($UI/PopupLayer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Closed modal must restore normal screen input")
	print("EGG_UPGRADE_MODAL_QA_OK")

## TEMPORARY DEVELOPMENT UI. Remove this method call and the methods prefixed
## `_dev_` before release; no production gameplay depends on this panel.
func _build_dev_mode() -> void:
	dev_toggle_button = Button.new()
	dev_toggle_button.name = "DevModeToggle"
	dev_toggle_button.text = "DEV"
	dev_toggle_button.size = Vector2(92, 48)
	dev_toggle_button.add_theme_font_size_override("font_size", 18)
	dev_toggle_button.add_theme_color_override("font_color", Color("fff4ce"))
	dev_toggle_button.add_theme_stylebox_override("normal", _card_style(Color("55417b"), Color("f4c64e")))
	dev_toggle_button.add_theme_stylebox_override("hover", _card_style(Color("70559e"), Color("fff0a0")))
	$UI/PopupLayer.add_child(dev_toggle_button)
	dev_panel = Panel.new()
	dev_panel.name = "DevModePanel"
	dev_panel.visible = false
	dev_panel.z_index = 500
	dev_panel.size = Vector2(380, 744)
	dev_panel.add_theme_stylebox_override("panel", _card_style(Color("30263f"), Color("f4c64e")))
	$UI/PopupLayer.add_child(dev_panel)
	dev_toggle_button.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)
	var title := Label.new()
	title.text = "🛠 DEV TEST LAB"
	title.position = Vector2(14, 10)
	title.size = Vector2(352, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color.WHITE)
	dev_panel.add_child(title)
	dev_scroll = ScrollContainer.new()
	dev_scroll.position = Vector2(12, 52)
	dev_scroll.size = Vector2(356, 680)
	dev_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dev_panel.add_child(dev_scroll)
	dev_button_list = VBoxContainer.new()
	dev_button_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_button_list.add_theme_constant_override("separation", 7)
	dev_scroll.add_child(dev_button_list)
	_add_dev_button("CALL UFO + DROP EGG", _dev_deliver_egg)
	_add_dev_button("START ENEMY RAID", _dev_start_raid)
	_add_dev_button("DEFEAT UFO NOW", func(): farm_manager.raids.debug_defeat())
	_add_dev_button("TEST ABDUCTION", func(): farm_manager.raids.debug_abduct())
	_add_dev_button("SPAWN NORMAL CREATURE", func(): _dev_spawn_creature(false))
	_add_dev_button("SPAWN SHINY CREATURE", func(): _dev_spawn_creature(true))
	_add_dev_button("+10,000 COINS", _dev_add_coins)
	_add_dev_button("TEST FARM DAMAGE", _dev_damage_farm)
	_add_dev_button("TEST MERGE + REVEAL", _dev_test_merge_vfx)
	_add_dev_button("PREVIEW FUSION MODAL", _qa_show_fusion_modal)
	_add_dev_button("PREVIEW UPGRADE WARNING", _qa_show_upgrade_warning)
	_add_dev_button("PREVIEW UPGRADE SUCCESS", _qa_show_upgrade_success)
	_add_dev_button("TEST NOTIFICATION STYLES", _dev_test_notifications)
	_add_dev_button("RESTORE STARTER CREATURES", _request_starter_roster_reset)
	_add_dev_button("RESET TO EMPTY FARM", _request_empty_farm_reset)
	dev_reset_dialog = ConfirmationDialog.new()
	dev_reset_dialog.title = "Reset test farm?"
	dev_reset_dialog.ok_button_text = "RESET"
	dev_reset_dialog.cancel_button_text = "CANCEL"
	dev_reset_dialog.confirmed.connect(_confirm_dev_reset)
	$UI/PopupLayer.add_child(dev_reset_dialog)
	_layout_dev_mode()

func _add_dev_button(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	dev_button_list.add_child(button)

func _layout_dev_mode() -> void:
	if dev_panel == null or dev_toggle_button == null:
		return
	var viewport_size := get_viewport_rect().size
	var panel_width := minf(380.0, viewport_size.x - 24.0)
	var panel_height := minf(744.0, viewport_size.y - 208.0)
	dev_panel.size = Vector2(panel_width, panel_height)
	dev_panel.position = Vector2(viewport_size.x - panel_width - 12.0, viewport_size.y - panel_height - 194.0)
	dev_scroll.position = Vector2(12.0, 52.0)
	dev_scroll.size = Vector2(panel_width - 24.0, panel_height - 64.0)
	dev_toggle_button.position = Vector2(viewport_size.x - 104.0, viewport_size.y - 184.0)

func _dev_test_notifications() -> void:
	dev_panel.visible = false
	_toast("DEV INFO · This is an information notification", 2.4)
	_toast("✅ DEV SUCCESS · Action completed", 2.4)
	_toast("⚠️ DEV WARNING · Check this situation", 2.4)
	_toast("❌ DEV ERROR · Example failure notification", 2.8)

func _request_starter_roster_reset() -> void:
	dev_pending_reset = "starter"
	dev_reset_dialog.dialog_text = "Replace farm creatures and eggs with the original starter roster? Your coins, upgrades, and collection discoveries will stay."
	dev_reset_dialog.popup_centered(Vector2i(500, 230))

func _request_empty_farm_reset() -> void:
	dev_pending_reset = "empty"
	dev_reset_dialog.dialog_text = "Remove all active creatures across maps and all unopened eggs? Coins, upgrades, and collection discoveries will stay."
	dev_reset_dialog.popup_centered(Vector2i(500, 230))

func _confirm_dev_reset() -> void:
	dev_panel.visible = false
	_clear_dev_farm_contents()
	if dev_pending_reset == "starter" and current_planet != "earth":
		_replace_farm_map("earth", false)
	if dev_pending_reset == "starter":
		Game.init_demo_data()
		_toast("DEV: Starter creature roster restored", 3.0)
	else:
		_toast("DEV: Farm creatures and eggs cleared", 3.0)
	_sync_critters()
	_refresh_all()
	_update_farm_hud()
	Game.save_game()

func _clear_dev_farm_contents() -> void:
	Game.animals.clear()
	Game.unopened_eggs.clear()
	Game.battle_team.clear()
	Game.farm_defense_damaged_until = 0
	Game.set_delivery_remaining(FARM_CONFIG.delivery_interval(Game.delivery_level_for()))
	drag_id = ""
	selected_animal_id = ""
	pending_fusion.clear()
	for view in critter_views.values():
		if is_instance_valid(view):
			view.queue_free()
	critter_views.clear()
	for view in egg_views.values():
		if is_instance_valid(view):
			view.queue_free()
	egg_views.clear()
	if farm_manager != null and farm_manager.raids != null:
		farm_manager.raids.active = false
		farm_manager.raids.next_raid = randf_range(FARM_CONFIG.raid_interval_min, FARM_CONFIG.raid_interval_max)
		raid_button.visible = false
		raid_overlay.visible = false

func _dev_deliver_egg() -> void:
	if not farm_manager.eggs.can_receive():
		_toast("The hatchery is full")
		return
	_play_friendly_ufo()
	farm_manager.eggs.deliver()
	Game.set_delivery_remaining(FARM_CONFIG.delivery_interval(Game.delivery_level_for()))

func _qa_test_ufo_delivery() -> void:
	if not farm_manager.eggs.can_receive() and not Game.unopened_eggs.is_empty():
		Game.unopened_eggs.pop_back()
		_sync_egg_views()
	_dev_deliver_egg()

func _dev_start_raid() -> void:
	dev_panel.visible = false
	farm_manager.raids.start_raid()

func _dev_spawn_creature(shiny: bool) -> void:
	var result := farm_manager.creatures.create_tier_one(shiny)
	if result.is_empty():
		_toast("The farm is full")
		return
	_sync_critters()
	_refresh_all()
	_toast("Spawned %s" % Game.display_name(result.animal))

func _dev_add_coins() -> void:
	Game.coins += 10000
	_refresh_all()
	_toast("DEV: +10.000 Coin")

func _dev_damage_farm() -> void:
	dev_panel.visible = false
	Game.farm_defense_damaged_until = int(Time.get_unix_time_from_system()) + FARM_CONFIG.farm_damage_duration_seconds
	_toast("DEV: Farm damage active for 10 minutes")

func _dev_reset_farm() -> void:
	_request_empty_farm_reset()

func _dev_test_merge_vfx() -> void:
	dev_panel.visible = false
	if current_planet != "earth":
		_replace_farm_map("earth", false)
	Game.discovered.erase(Game.type_id("ga_ta_vang", 2))
	var first := Game.create_animal("ga_ta_vang", 1, {"x": 50.0, "y": 52.0, "force_normal": true})
	var second := Game.create_animal("ga_ta_vang", 1, {"x": 50.0, "y": 52.0, "force_normal": true})
	_sync_critters()
	var result := farm_manager.merge.merge(first.animal.id, second.animal.id)
	_sync_critters()
	_play_merge_reveal(result, false)
	_show_merge_success(result, false)

func _bind_farm_hud() -> void:
	farm_overlay.visible = true
	delivery_status_label = $UI/FarmScreen/DeliveryStatus/DeliveryStatusLabel
	delivery_progress_bar = $UI/FarmScreen/DeliveryStatus/DeliveryProgressBar
	upgrade_menu = $UI/FarmScreen/UpgradeShop
	upgrade_menu.visible = false
	toast_panel.visible = false
	delivery_upgrade_label = $UI/FarmScreen/UpgradeShop/DeliveryUpgradeLabel
	_build_egg_upgrade_panel()
	$UI/FarmScreen/OpenUpgradeShop.pressed.connect(func():
		_toggle_upgrade_menu()
	)
	(upgrade_menu.get_node("BuyDelivery") as Button).pressed.connect(_upgrade_delivery)
	map_switch_button = Button.new()
	map_switch_button.position = Vector2(500, 210)
	map_switch_button.size = Vector2(190, 54)
	map_switch_button.z_index = 1000
	map_switch_button.focus_mode = Control.FOCUS_NONE
	map_switch_button.add_theme_font_size_override("font_size", 19)
	map_switch_button.add_theme_color_override("font_color", Color.WHITE)
	map_switch_button.add_theme_stylebox_override("normal", _card_style(Color("6750a4"), Color("241a14")))
	map_switch_button.add_theme_stylebox_override("hover", _card_style(Color("8067be"), Color.WHITE))
	map_switch_button.pressed.connect(_cycle_farm_map)
	farm_overlay.add_child(map_switch_button)
	_update_map_switch_button()
	_build_fusion_modal()
	raid_button = Button.new()
	raid_button.visible = false
	raid_button.text = ""
	raid_button.icon = Game.ufo_texture("boss", 0)
	raid_button.expand_icon = true
	raid_button.position = Vector2(245, 390)
	raid_button.size = Vector2(230, 150)
	raid_button.z_index = 20
	raid_button.focus_mode = Control.FOCUS_NONE
	raid_button.add_theme_font_size_override("font_size", 35)
	raid_button.add_theme_color_override("font_color", Color.WHITE)
	raid_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	raid_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	raid_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	raid_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	raid_button.pressed.connect(_fire_raid_cannon)
	farm_overlay.add_child(raid_button)
	raid_status_label = Label.new()
	raid_status_label.position = Vector2(0, 151)
	raid_status_label.size = Vector2(230, 58)
	raid_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_status_label.add_theme_font_size_override("font_size", 19)
	raid_status_label.add_theme_color_override("font_color", Color("ff355d"))
	raid_status_label.add_theme_color_override("font_outline_color", Color.WHITE)
	raid_status_label.add_theme_constant_override("outline_size", 5)
	raid_button.add_child(raid_status_label)
	_build_raid_combat_ui()
	_refresh_upgrade_shop()
func _build_raid_combat_ui() -> void:
	raid_canvas = CanvasLayer.new()
	raid_canvas.name = "RaidCombatCanvas"
	raid_canvas.layer = 80
	add_child(raid_canvas)
	raid_overlay = Control.new()
	raid_overlay.name = "RaidCombatOverlay"
	raid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_overlay.visible = false
	raid_canvas.add_child(raid_overlay)
	raid_boss_group = Control.new()
	raid_boss_group.name = "RaidBossGroup"
	raid_boss_group.size = Vector2(230.0, 230.0)
	raid_overlay.add_child(raid_boss_group)
	raid_boss_visual = TextureRect.new()
	raid_boss_visual.name = "BossSprite"
	raid_boss_visual.texture = Game.ufo_texture("boss", 0)
	raid_boss_visual.size = Vector2(230.0, 160.0)
	raid_boss_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	raid_boss_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	raid_boss_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_boss_group.add_child(raid_boss_visual)
	raid_button.reparent(raid_boss_group)
	raid_button.icon = null
	raid_button.position = Vector2.ZERO
	raid_button.size = Vector2(230.0, 160.0)
	raid_hp_bar = ProgressBar.new()
	raid_hp_bar.name = "BossHealthBar"
	raid_hp_bar.position = Vector2(15.0, 164.0)
	raid_hp_bar.size = Vector2(200.0, 30.0)
	raid_hp_bar.show_percentage = false
	raid_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_track := StyleBoxFlat.new()
	health_track.bg_color = Color("432f38")
	health_track.border_color = Color("241a20")
	health_track.set_border_width_all(3)
	health_track.set_corner_radius_all(12)
	health_track.content_margin_left = 3.0
	health_track.content_margin_right = 3.0
	health_track.content_margin_top = 3.0
	health_track.content_margin_bottom = 3.0
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color("76cf45")
	health_fill.set_corner_radius_all(9)
	raid_hp_bar.add_theme_stylebox_override("background", health_track)
	raid_hp_bar.add_theme_stylebox_override("fill", health_fill)
	raid_boss_group.add_child(raid_hp_bar)
	raid_hp_label = Label.new()
	raid_hp_label.name = "HealthValue"
	raid_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raid_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	raid_hp_label.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	raid_hp_label.add_theme_font_size_override("font_size", 19)
	raid_hp_label.add_theme_color_override("font_color", Color("fff8e3"))
	raid_hp_label.add_theme_color_override("font_outline_color", Color("30252b"))
	raid_hp_label.add_theme_constant_override("outline_size", 4)
	raid_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_hp_bar.add_child(raid_hp_label)
	raid_status_label.reparent(raid_boss_group)
	raid_status_label.position = Vector2(0.0, 196.0)
	raid_status_label.size = Vector2(230.0, 30.0)
	raid_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	raid_status_label.add_theme_font_size_override("font_size", 18)
	raid_status_label.add_theme_color_override("font_color", Color("fff0c9"))
	raid_status_label.add_theme_color_override("font_outline_color", Color("42231d"))

	# This interactive strip sits above BottomNav; it blocks screen changes while
	# the raid is active, and gives clear feedback when the covered area is tapped.
	raid_blocker = Panel.new()
	raid_blocker.name = "BottomNavRaidBlocker"
	raid_blocker.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	raid_blocker.offset_top = -150.0
	raid_blocker.offset_bottom = 0.0
	raid_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	var blocker_style := StyleBoxFlat.new()
	blocker_style.bg_color = Color("523022")
	blocker_style.border_color = Color("2b1a17")
	blocker_style.set_border_width_all(5)
	blocker_style.border_width_top = 7
	blocker_style.set_corner_radius_all(20)
	blocker_style.shadow_color = Color(0.10, 0.06, 0.04, 0.55)
	blocker_style.shadow_size = 8
	blocker_style.content_margin_top = 7.0
	raid_blocker.add_theme_stylebox_override("panel", blocker_style)
	raid_blocker.gui_input.connect(_on_raid_blocker_input)
	raid_overlay.add_child(raid_blocker)
	var launch_deck := TextureRect.new()
	launch_deck.name = "RaidLaunchDeck"
	launch_deck.texture = RAID_LAUNCH_DECK_TEXTURE
	launch_deck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	launch_deck.stretch_mode = TextureRect.STRETCH_SCALE
	launch_deck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	launch_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_blocker.add_child(launch_deck)

	raid_cannon_visual = RaidCannonVisualScene.new()
	raid_cannon_visual.name = "RaidCannonVisual"
	raid_cannon_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_cannon_visual.size = Vector2(210.0, 210.0)
	raid_overlay.add_child(raid_cannon_visual)
	raid_fire_button = Button.new()
	raid_fire_button.name = "RaidCannonFireButton"
	raid_fire_button.tooltip_text = "Tap to fire at the UFO boss"
	raid_fire_button.focus_mode = Control.FOCUS_NONE
	raid_fire_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	raid_fire_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	raid_fire_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	raid_fire_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	raid_fire_button.pressed.connect(_fire_raid_cannon)
	raid_overlay.add_child(raid_fire_button)

	raid_warning_label = Label.new()
	raid_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	raid_warning_label.add_theme_font_override("font", FONT_BALOO_BOLD)
	raid_warning_label.add_theme_font_size_override("font_size", 21)
	raid_warning_label.add_theme_color_override("font_color", Color("fff2cf"))
	raid_warning_label.add_theme_color_override("font_outline_color", Color("6d291f"))
	raid_warning_label.add_theme_constant_override("outline_size", 5)
	raid_warning_label.visible = false
	raid_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_overlay.add_child(raid_warning_label)
	_apply_raid_combat_layout()

func _apply_raid_combat_layout() -> void:
	if raid_overlay == null:
		return
	var viewport_size := get_viewport_rect().size
	var boss_position := Vector2((viewport_size.x - 230.0) * 0.5, maxf(170.0, viewport_size.y * 0.285))
	if raid_boss_group != null:
		raid_boss_group.position = boss_position
		raid_boss_group.size = Vector2(230.0, 230.0)
	if raid_boss_visual != null:
		raid_boss_visual.position = Vector2.ZERO
		raid_boss_visual.size = Vector2(230.0, 160.0)
	if raid_button != null:
		raid_button.position = Vector2.ZERO
		raid_button.size = Vector2(230.0, 160.0)
		raid_status_label.position = Vector2(0.0, 196.0)
		raid_status_label.size = Vector2(230.0, 30.0)
	# Lower the cannon so its rear mounting foot settles onto the deck's central dock.
	var cannon_target := Vector2((viewport_size.x - 210.0) * 0.5, viewport_size.y - 270.0)
	if raid_cannon_visual != null:
		raid_cannon_visual.position = cannon_target
	if raid_fire_button != null:
		raid_fire_button.position = cannon_target + Vector2(-15.0, -10.0)
		raid_fire_button.size = Vector2(240.0, 210.0)
	if raid_warning_label != null:
		raid_warning_label.position = Vector2(20.0, viewport_size.y - 214.0)
		raid_warning_label.size = Vector2(viewport_size.x - 40.0, 44.0)

func _on_raid_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_warn_raid_screen_switch()
		raid_blocker.accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_warn_raid_screen_switch()
		raid_blocker.accept_event()

func _warn_raid_screen_switch() -> void:
	if raid_warning_cooldown > 0.0:
		return
	raid_warning_cooldown = 0.8
	raid_warning_label.text = "Defeat the UFO boss before changing screens!"
	raid_warning_label.visible = true
	raid_warning_label.modulate.a = 1.0
	var warning_tween := raid_warning_label.create_tween()
	warning_tween.tween_interval(1.2)
	warning_tween.tween_property(raid_warning_label, "modulate:a", 0.0, 0.25)
	warning_tween.tween_callback(func(): raid_warning_label.visible = false)

func _fire_raid_cannon() -> void:
	if farm_manager == null or not farm_manager.raids.active:
		return
	Audio.play_sfx("cannon")
	if raid_cannon_visual != null:
		raid_cannon_visual.set_firing(true)
		var flash_tween := raid_cannon_visual.create_tween()
		flash_tween.tween_interval(0.12)
		flash_tween.tween_callback(func(): raid_cannon_visual.set_firing(false))
	farm_manager.raids.attack(Game.cannon_damage_for())
	if farm_manager.raids.active:
		raid_hit_flash_timer = 0.22
		raid_boss_visual.texture = Game.ufo_texture("boss", 4)
		var original_position := raid_boss_group.position
		var hit_tween := raid_boss_group.create_tween()
		hit_tween.tween_property(raid_boss_group, "position", original_position + Vector2(7.0, 0.0), 0.035)
		hit_tween.tween_property(raid_boss_group, "position", original_position - Vector2(7.0, 0.0), 0.06)
		hit_tween.tween_property(raid_boss_group, "position", original_position, 0.04)
func _refresh_upgrade_shop() -> void:
	if not delivery_upgrade_label:
		return
	var delivery_level := Game.delivery_level_for()
	var delivery_cost := FARM_CONFIG.delivery_upgrade_cost(delivery_level)
	delivery_upgrade_label.text = "🛸 UFO SPEED  Lv.%d\nCost: %d Coin" % [delivery_level + 1, delivery_cost]
	_refresh_cannon_upgrade()
	_refresh_egg_upgrade_panel()

func _refresh_cannon_upgrade() -> void:
	if cannon_upgrade_label == null or cannon_upgrade_button == null: return
	var level := Game.cannon_level_for()
	var damage := Game.cannon_damage_for()
	var maxed := level >= Game.MAX_CANNON_LEVEL
	var next_damage := damage if maxed else roundi(FARM_CONFIG.tap_damage * (1.0 + (level + 1) * 0.5))
	if maxed:
		cannon_upgrade_label.text = "⚡ ENERGY CANNON  Lv.%d\nDamage: %d · MAX LEVEL" % [level + 1, damage]
		cannon_upgrade_button.text = "MAX LEVEL"
		cannon_upgrade_button.disabled = true
	else:
		var cost := Game.cannon_upgrade_cost()
		cannon_upgrade_label.text = "⚡ ENERGY CANNON  Lv.%d\nDamage: %d → %d  ·  Cost: %s" % [level + 1, damage, next_damage, _format_number(cost)]
		cannon_upgrade_button.text = "UPGRADE"
		cannon_upgrade_button.disabled = Game.coins < cost

func _upgrade_cannon() -> void:
	var result: Dictionary = Game.upgrade_cannon()
	if not result.get("ok", false):
		_toast("Not enough Gold to upgrade the cannon" if result.get("reason") == "coins" else "Cannon is already at max level")
		_refresh_cannon_upgrade()
		return
	Audio.play_sfx("success")
	_toast("⚡ CANNON UPGRADED · Lv.%d · %d DAMAGE" % [result.level + 1, result.damage])
	_refresh_all()
	_refresh_upgrade_shop()
	cannon_upgrade_button.pivot_offset = cannon_upgrade_button.size * 0.5
	var bounce := cannon_upgrade_button.create_tween()
	bounce.tween_property(cannon_upgrade_button, "scale", Vector2(1.08, 1.08), 0.10)
	bounce.tween_property(cannon_upgrade_button, "scale", Vector2.ONE, 0.14)

func _build_egg_upgrade_panel() -> void:
	# PopupLayer is above FarmScreen's ticker and effect layers, so no toast or
	# UFO animation can ever cover this modal.
	egg_upgrade_modal_layer = Control.new()
	egg_upgrade_modal_layer.name = "EggUpgradeModalLayer"
	egg_upgrade_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	egg_upgrade_modal_layer.z_index = 100
	egg_upgrade_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	egg_upgrade_modal_layer.visible = false
	egg_upgrade_canvas = CanvasLayer.new()
	egg_upgrade_canvas.name = "EggUpgradeCanvas"
	egg_upgrade_canvas.layer = 100
	add_child(egg_upgrade_canvas)
	egg_upgrade_canvas.add_child(egg_upgrade_modal_layer)
	egg_upgrade_close_button = farm_screen.get_node("EggUpgradeClose") as TextureButton
	egg_upgrade_close_base_position = egg_upgrade_close_button.position
	egg_upgrade_close_button.reparent(egg_upgrade_modal_layer)
	egg_upgrade_close_button.position = egg_upgrade_close_base_position
	egg_upgrade_close_button.z_index = 1000
	egg_upgrade_close_button.ignore_texture_size = true
	egg_upgrade_close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	egg_upgrade_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	egg_upgrade_close_button.visible = false
	egg_upgrade_close_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	egg_upgrade_close_button.pressed.connect(_close_upgrade_menu)
	# Re-apply the full-rect preset after parenting so its hit rectangle always
	# covers the complete viewport, including responsive/tall phone layouts.
	egg_upgrade_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	egg_upgrade_dim = ColorRect.new()
	egg_upgrade_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	egg_upgrade_dim.color = Color(0.055, 0.045, 0.075, 0.72)
	egg_upgrade_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	egg_upgrade_dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_upgrade_menu()
	)
	egg_upgrade_modal_layer.add_child(egg_upgrade_dim)
	egg_upgrade_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_menu.reparent(egg_upgrade_modal_layer)
	upgrade_menu.z_index = 10
	upgrade_menu.size = Vector2(650, 760)
	upgrade_menu.position = Vector2(35, -740)
	upgrade_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var background := TextureRect.new()
	background.name = "GeneratedFrame"
	background.texture = EGG_UPGRADE_PANEL_TEXTURE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	upgrade_menu.add_child(background)
	upgrade_menu.move_child(background, 0)
	var title := upgrade_menu.get_node("Title") as Label
	title.position = Vector2(120, 48)
	title.size = Vector2(410, 62)
	title.text = "FARM UPGRADES"
	_style_modal_title(title)
	delivery_upgrade_label.position = Vector2(55, 115)
	delivery_upgrade_label.size = Vector2(380, 75)
	delivery_upgrade_label.add_theme_color_override("font_color", Color("3b2416"))
	delivery_upgrade_label.add_theme_font_size_override("font_size", 22)
	delivery_upgrade_label.add_theme_font_override("font", FONT_BALOO_BOLD)
	delivery_upgrade_label.add_theme_constant_override("line_spacing", 1)
	var buy_delivery := upgrade_menu.get_node("BuyDelivery") as Button
	buy_delivery.position = Vector2(440, 120)
	buy_delivery.size = Vector2(145, 58)
	buy_delivery.text = "UPGRADE UFO"
	buy_delivery.add_theme_color_override("font_color", Color("3b2416"))
	buy_delivery.add_theme_font_size_override("font_size", 16)
	buy_delivery.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	_apply_generated_button_skin(buy_delivery, Color("ffb832"))
	cannon_upgrade_label = Label.new()
	cannon_upgrade_label.position = Vector2(55, 180)
	cannon_upgrade_label.size = Vector2(380, 72)
	cannon_upgrade_label.add_theme_color_override("font_color", Color("3b2416"))
	cannon_upgrade_label.add_theme_font_size_override("font_size", 21)
	cannon_upgrade_label.add_theme_font_override("font", FONT_BALOO_BOLD)
	upgrade_menu.add_child(cannon_upgrade_label)
	cannon_upgrade_button = Button.new()
	cannon_upgrade_button.position = Vector2(440, 185)
	cannon_upgrade_button.size = Vector2(145, 58)
	cannon_upgrade_button.add_theme_color_override("font_color", Color("26340f"))
	cannon_upgrade_button.add_theme_font_size_override("font_size", 16)
	cannon_upgrade_button.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	_apply_generated_button_skin(cannon_upgrade_button, Color("62d7ef"))
	cannon_upgrade_button.pressed.connect(_upgrade_cannon)
	upgrade_menu.add_child(cannon_upgrade_button)
	var divider := HSeparator.new()
	divider.position = Vector2(55, 260)
	divider.size = Vector2(540, 4)
	upgrade_menu.add_child(divider)
	egg_upgrade_summary = Label.new()
	egg_upgrade_summary.position = Vector2(55, 274)
	egg_upgrade_summary.size = Vector2(540, 75)
	egg_upgrade_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	egg_upgrade_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	egg_upgrade_summary.add_theme_color_override("font_color", Color("3b2416"))
	egg_upgrade_summary.add_theme_font_size_override("font_size", 24)
	egg_upgrade_summary.add_theme_font_override("font", FONT_BALOO_BOLD)
	upgrade_menu.add_child(egg_upgrade_summary)
	egg_upgrade_rates = Control.new()
	egg_upgrade_rates.position = Vector2(65, 352)
	egg_upgrade_rates.size = Vector2(520, 255)
	upgrade_menu.add_child(egg_upgrade_rates)
	var header := Panel.new()
	header.position = Vector2.ZERO
	header.size = Vector2(520, 42)
	header.add_theme_stylebox_override("panel", _card_style(Color("f0d9aa"), Color("8a5930")))
	egg_upgrade_rates.add_child(header)
	var egg_header := Label.new()
	egg_header.position = Vector2(12, 3)
	egg_header.size = Vector2(220, 36)
	egg_header.text = "EGG TYPE"
	egg_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	egg_header.add_theme_color_override("font_color", Color("3b2416"))
	egg_header.add_theme_font_size_override("font_size", 19)
	egg_header.add_theme_font_override("font", FONT_BALOO_BOLD)
	header.add_child(egg_header)
	var current_header := Label.new()
	current_header.position = Vector2(245, 3)
	current_header.size = Vector2(115, 36)
	current_header.text = "CURRENT"
	current_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_header.add_theme_color_override("font_color", Color("3b2416"))
	current_header.add_theme_font_size_override("font_size", 17)
	current_header.add_theme_font_override("font", FONT_BALOO_BOLD)
	header.add_child(current_header)
	var next_header := Label.new()
	next_header.position = Vector2(390, 3)
	next_header.size = Vector2(115, 36)
	next_header.text = "NEXT"
	next_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_header.add_theme_color_override("font_color", Color("3b2416"))
	next_header.add_theme_font_size_override("font_size", 17)
	next_header.add_theme_font_override("font", FONT_BALOO_BOLD)
	header.add_child(next_header)
	for egg_level in range(1, 6):
		var row := Panel.new()
		row.position = Vector2(0, 46 + (egg_level - 1) * 41)
		row.size = Vector2(520, 38)
		row.add_theme_stylebox_override("panel", _card_style(Color("fffaf0") if egg_level % 2 == 1 else Color("f8edcf"), Color("d2b480")))
		egg_upgrade_rates.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Game.egg_texture(egg_level)
		icon.position = Vector2(8, 2)
		icon.size = icon.texture.get_size()
		icon.scale = Vector2(34.0 / icon.size.x, 34.0 / icon.size.y)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var name_label := Label.new()
		name_label.position = Vector2(50, 1)
		name_label.size = Vector2(160, 36)
		name_label.text = "Egg Lv%d" % egg_level
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color("3b2416"))
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_font_override("font", FONT_BALOO_BOLD)
		name_label.clip_text = true
		row.add_child(name_label)
		var current_value := Label.new()
		current_value.position = Vector2(235, 1)
		current_value.size = Vector2(115, 36)
		current_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		current_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		current_value.add_theme_color_override("font_color", Color("3b2416"))
		current_value.add_theme_font_size_override("font_size", 20)
		current_value.add_theme_font_override("font", FONT_BALOO_BOLD)
		row.add_child(current_value)
		var arrow := Label.new()
		arrow.position = Vector2(350, 1)
		arrow.size = Vector2(42, 36)
		arrow.text = "➜"
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.add_theme_color_override("font_color", Color("a16a34"))
		arrow.add_theme_font_size_override("font_size", 18)
		arrow.add_theme_font_override("font", FONT_BALOO_BOLD)
		row.add_child(arrow)
		var next_value := Label.new()
		next_value.position = Vector2(392, 1)
		next_value.size = Vector2(115, 36)
		next_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		next_value.add_theme_font_size_override("font_size", 20)
		next_value.add_theme_font_override("font", FONT_BALOO_BOLD)
		row.add_child(next_value)
		egg_upgrade_rate_rows.append({"current": current_value, "next": next_value, "arrow": arrow})
	egg_upgrade_feedback = Label.new()
	egg_upgrade_feedback.position = Vector2(55, 610)
	egg_upgrade_feedback.size = Vector2(540, 38)
	egg_upgrade_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	egg_upgrade_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	egg_upgrade_feedback.add_theme_color_override("font_color", Color("2f8e38"))
	egg_upgrade_feedback.add_theme_font_size_override("font_size", 22)
	egg_upgrade_feedback.add_theme_font_override("font", FONT_BALOO_BOLD)
	upgrade_menu.add_child(egg_upgrade_feedback)
	egg_upgrade_button = Button.new()
	egg_upgrade_button.position = Vector2(155, 650)
	egg_upgrade_button.size = Vector2(340, 72)
	egg_upgrade_button.add_theme_font_size_override("font_size", 26)
	egg_upgrade_button.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	egg_upgrade_button.add_theme_color_override("font_color", Color("26340f"))
	egg_upgrade_button.add_theme_color_override("font_disabled_color", Color("5d554d"))
	_apply_generated_button_skin(egg_upgrade_button, Color("72d33f"))
	egg_upgrade_button.add_theme_stylebox_override("disabled", _card_style(Color("b9b0a3"), Color("6d6258")))
	egg_upgrade_button.pressed.connect(_upgrade_egg_quality)
	upgrade_menu.add_child(egg_upgrade_button)
	_build_upgrade_success_panel()
	_build_upgrade_confirmation_panel()
	# GUI picking follows sibling order, not z_index. Keep X above the dimmer
	# and all three panels for pointer/touch input as well as drawing.
	egg_upgrade_modal_layer.move_child(egg_upgrade_close_button, -1)

func _apply_generated_button_skin(button: Button, tint: Color) -> void:
	var plate := TextureRect.new()
	plate.name = "GeneratedButtonPlate"
	plate.texture = BUTTON_PLATE_TEXTURE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.modulate = tint
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.show_behind_parent = true
	button.add_child(plate)
	button.move_child(plate, 0)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _build_fusion_modal() -> void:
	fusion_canvas = CanvasLayer.new()
	fusion_canvas.name = "FusionCanvas"
	fusion_canvas.layer = 90
	add_child(fusion_canvas)
	fusion_modal_layer = Control.new()
	fusion_modal_layer.name = "FusionModalLayer"
	fusion_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	fusion_modal_layer.visible = false
	fusion_canvas.add_child(fusion_modal_layer)
	fusion_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.028, 0.05, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	fusion_modal_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fusion_panel = Control.new()
	fusion_panel.name = "FusionPanel"
	fusion_panel.position = Vector2(30, 310)
	fusion_panel.size = Vector2(660, 520)
	fusion_panel.z_index = 10
	fusion_modal_layer.add_child(fusion_panel)
	var frame := TextureRect.new()
	frame.texture = FUSION_PANEL_TEXTURE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fusion_panel.add_child(frame)
	var title := Label.new()
	title.position = Vector2(160, 55)
	title.name = "FusionTitle"
	title.size = Vector2(340, 62)
	title.text = "FUSION"
	_style_modal_title(title)
	fusion_panel.add_child(title)
	fusion_pair_label = Label.new()
	fusion_pair_label.position = Vector2(42, 137)
	fusion_pair_label.size = Vector2(576, 48)
	fusion_pair_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fusion_pair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fusion_pair_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fusion_pair_label.add_theme_color_override("font_color", Color("3b2416"))
	fusion_pair_label.add_theme_font_size_override("font_size", 23)
	fusion_pair_label.add_theme_font_override("font", FONT_BALOO_BOLD)
	fusion_panel.add_child(fusion_pair_label)
	# The artwork's cream content ends before the outer Control bounds. Keep
	# cards AND their glow inside that inset, and parent each image/name to its card.
	var left_card := _build_fusion_creature_card("LeftCreatureCard", Vector2(300, 192))
	var right_card := _build_fusion_creature_card("RightCreatureCard", Vector2(458, 192))
	fusion_left_image = left_card.get_node("Portrait") as TextureRect
	fusion_right_image = right_card.get_node("Portrait") as TextureRect
	fusion_left_name = left_card.get_node("Caption") as Label
	fusion_right_name = right_card.get_node("Caption") as Label
	var plus := Label.new()
	plus.name = "PairPlus"
	plus.position = Vector2(430, 220)
	plus.size = Vector2(28, 64)
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_theme_color_override("font_color", Color("f5a900"))
	plus.add_theme_color_override("font_outline_color", Color("7a3d16"))
	plus.add_theme_constant_override("outline_size", 5)
	plus.add_theme_font_size_override("font_size", 38)
	plus.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	fusion_panel.add_child(plus)
	fusion_chance_label = RichTextLabel.new()
	fusion_chance_label.position = Vector2(54, 199)
	fusion_chance_label.size = Vector2(238, 174)
	fusion_chance_label.bbcode_enabled = true
	fusion_chance_label.fit_content = false
	fusion_chance_label.scroll_active = false
	fusion_chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fusion_chance_label.add_theme_font_size_override("normal_font_size", 21)
	fusion_chance_label.add_theme_font_override("normal_font", FONT_BALOO_BOLD)
	fusion_chance_label.add_theme_font_override("bold_font", FONT_BALOO_EXTRA_BOLD)
	fusion_panel.add_child(fusion_chance_label)
	fusion_result_content = Control.new()
	fusion_result_content.name = "ResultContent"
	fusion_result_content.position = Vector2(60, 185)
	fusion_result_content.size = Vector2(540, 184)
	fusion_result_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fusion_result_content.visible = false
	fusion_panel.add_child(fusion_result_content)
	fusion_result_image = TextureRect.new()
	fusion_result_image.position = Vector2(190, 0)
	fusion_result_image.size = Vector2(160, 128)
	fusion_result_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fusion_result_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fusion_result_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fusion_result_content.add_child(fusion_result_image)
	fusion_result_mark = _new_upgrade_rate_label(Vector2(190, 0), Vector2(160, 128))
	fusion_result_mark.text = "×"
	fusion_result_mark.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	fusion_result_mark.add_theme_font_size_override("font_size", 88)
	fusion_result_mark.add_theme_color_override("font_color", Color("c43f2f"))
	fusion_result_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fusion_result_content.add_child(fusion_result_mark)
	fusion_result_message = _new_upgrade_rate_label(Vector2(20, 136), Vector2(500, 48))
	fusion_result_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fusion_result_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fusion_result_content.add_child(fusion_result_message)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.position = Vector2(70, 378)
	cancel.size = Vector2(235, 76)
	cancel.text = "CANCEL"
	cancel.add_theme_font_size_override("font_size", 28)
	cancel.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	cancel.add_theme_color_override("font_color", Color("fff1da"))
	cancel.add_theme_color_override("font_outline_color", Color("59311f"))
	cancel.add_theme_constant_override("outline_size", 2)
	_style_fusion_action_button(cancel, Color("956044"), Color("fff1da"))
	cancel.pressed.connect(_hide_fusion_modal)
	fusion_panel.add_child(cancel)
	var confirm := Button.new()
	confirm.name = "Confirm"
	confirm.position = Vector2(355, 378)
	confirm.size = Vector2(235, 76)
	confirm.text = "FUSE"
	confirm.add_theme_font_size_override("font_size", 30)
	confirm.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	confirm.add_theme_color_override("font_color", Color("f8ffe9"))
	confirm.add_theme_color_override("font_outline_color", Color("256020"))
	confirm.add_theme_constant_override("outline_size", 2)
	_style_fusion_action_button(confirm, Color("69cb3e"), Color("f8ffe9"))
	confirm.pressed.connect(_confirm_fusion)
	fusion_panel.add_child(confirm)
	var close := Button.new()
	close.name = "Close"
	close.position = Vector2(580, 78)
	close.size = Vector2(70, 70)
	close.z_index = 100
	close.text = ""
	close.add_theme_font_size_override("font_size", 38)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	close.tooltip_text = "Close"
	close.pressed.connect(_hide_fusion_modal)
	fusion_panel.add_child(close)

func _build_fusion_creature_card(card_name: String, card_position: Vector2) -> Panel:
	var card := Panel.new()
	card.name = card_name
	card.position = card_position
	card.size = Vector2(130, 174)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _card_style(Color("fae6b9"), Color("e7c480"))
	style.shadow_color = Color(1.0, 0.78, 0.22, 0.18)
	style.shadow_size = 5
	card.add_theme_stylebox_override("panel", style)
	fusion_panel.add_child(card)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(13, 10)
	portrait.size = Vector2(104, 104)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait)
	var caption := _new_upgrade_rate_label(Vector2(6, 116), Vector2(118, 50))
	caption.name = "Caption"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 16)
	caption.max_lines_visible = 2
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)
	return card

func _style_modal_title(label: Label, font_size: int = 38) -> void:
	# LabelSettings take priority over theme overrides. Both modal headings must
	# use this single style, including scene-authored labels.
	label.label_settings = null
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff5d2"))
	label.add_theme_color_override("font_outline_color", Color("6f3516"))
	label.add_theme_constant_override("outline_size", 5)

func _style_fusion_action_button(button: Button, fill: Color, text_color: Color) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.08))
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.08))
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = fill.darkened(0.48)
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(24)
	normal.shadow_color = Color("321c16")
	normal.shadow_size = 7
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.12)
	hover.shadow_size = 9
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.10)
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _show_fusion_modal(left: Dictionary, right: Dictionary, chance: float) -> void:
	if fusion_resolving or fusion_closing:
		return
	if Game.pairing_kind(left, right) != "crossbreed":
		pending_fusion.clear()
		return
	_reset_fusion_modal_visuals()
	pending_fusion_planet = current_planet
	fusion_pair_label.text = "%s  +  %s" % [Game.display_name(left), Game.display_name(right)]
	fusion_left_name.text = Game.display_name(left)
	fusion_right_name.text = Game.display_name(right)
	fusion_closing = false
	fusion_left_image.texture = Game.creature_texture(left)
	fusion_right_image.texture = Game.creature_texture(right)
	fusion_left_image.modulate = Game.creature_color(left)
	fusion_right_image.modulate = Game.creature_color(right)
	fusion_chance_label.text = "[color=#287f31][font_size=34][b]%d%%[/b][/font_size]\n[b]SUCCESS RATE[/b][/color]\n[color=#c43f2f]Failure may consume a creature[/color]" % roundi(chance * 100.0)
	fusion_modal_layer.visible = true
	fusion_panel.scale = Vector2(0.88, 0.88)
	fusion_panel.pivot_offset = fusion_panel.size * 0.5
	fusion_panel.modulate.a = 0.0
	var reveal := fusion_panel.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(fusion_panel, "scale", Vector2.ONE, 0.24)
	reveal.tween_property(fusion_panel, "modulate:a", 1.0, 0.16)

func _hide_fusion_modal() -> void:
	if fusion_closing or fusion_resolving:
		return
	fusion_closing = true
	var completed := fusion_result.duplicate(true)
	fusion_result.clear()
	fusion_result_showing = false
	modal_input_guard_until = Time.get_ticks_msec() + 200
	await get_tree().create_timer(0.14).timeout
	fusion_modal_layer.visible = false
	fusion_panel.modulate.a = 1.0
	if not pending_fusion.is_empty():
		pending_fusion.clear()
	fusion_closing = false
	if completed.get("success", false):
		_play_merge_reveal(completed, true)
		_show_merge_success(completed, true)

func _reset_fusion_modal_visuals() -> void:
	fusion_result.clear()
	fusion_result_showing = false
	fusion_result_content.visible = false
	fusion_chance_label.visible = true
	(fusion_panel.get_node("PairPlus") as Label).visible = true
	(fusion_panel.get_node("FusionTitle") as Label).text = "FUSION"
	for card_name in ["LeftCreatureCard", "RightCreatureCard"]:
		var card := fusion_panel.get_node(card_name) as Control
		card.position = Vector2(300 if card_name == "LeftCreatureCard" else 458, 192)
		card.scale = Vector2.ONE
		card.modulate = Color.WHITE
		card.visible = true
	for button_name in ["Cancel", "Confirm", "Close"]:
		var button := fusion_panel.get_node(button_name) as Button
		button.disabled = false
		button.visible = true
	var confirm := fusion_panel.get_node("Confirm") as Button
	confirm.position = Vector2(355, 378)
	confirm.text = "FUSE"

func _play_fusion_outcome(result: Dictionary) -> void:
	fusion_result = result
	fusion_pair_label.text = "FUSING..."
	fusion_chance_label.visible = false
	(fusion_panel.get_node("PairPlus") as Label).visible = false
	for button_name in ["Cancel", "Confirm", "Close"]:
		(fusion_panel.get_node(button_name) as Button).disabled = true
	var left := fusion_panel.get_node("LeftCreatureCard") as Control
	var right := fusion_panel.get_node("RightCreatureCard") as Control
	left.position = Vector2(180, 192)
	right.position = Vector2(350, 192)
	var approach := fusion_panel.create_tween().set_parallel(true)
	approach.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for card in [left, right]:
		approach.tween_property(card, "position", Vector2(265, 192), 0.35)
		approach.tween_property(card, "modulate:a", 0.0, 0.35)
	approach.chain().tween_callback(func():
		left.visible = false
		right.visible = false
		_present_fusion_result(result)
	)

func _present_fusion_result(result: Dictionary) -> void:
	var title := fusion_panel.get_node("FusionTitle") as Label
	var succeeded := bool(result.get("success", false))
	Audio.play_sfx("success" if succeeded else "failure")
	title.text = "SUCCESS!" if succeeded else "FAILED!"
	fusion_result_mark.visible = not succeeded and result.get("critical", false)
	fusion_result_image.visible = not fusion_result_mark.visible
	if succeeded:
		var creature: Dictionary = result.animal
		fusion_pair_label.text = "%s · TIER %d" % [Game.display_name(creature), creature.tier]
		fusion_result_image.texture = Game.creature_texture(creature)
		fusion_result_image.modulate = Game.creature_color(creature)
		fusion_result_message.text = "NEW DISCOVERY!" if result.get("is_first", false) else "Your new creature is ready!"
		fusion_result_message.add_theme_color_override("font_color", Color("287f31"))
		var burst := MergeBurstScene.new()
		burst.position = Vector2(270, 65)
		burst.scale = Vector2(0.48, 0.48)
		burst.setup(Color("ffd84d"))
		fusion_result_content.add_child(burst)
		fusion_result_content.move_child(burst, 0)
	elif result.get("critical", false):
		fusion_pair_label.text = "CRITICAL FAILURE"
		fusion_result_message.text = "Both creatures were lost.\nNo new creature was created."
		fusion_result_message.add_theme_color_override("font_color", Color("c43f2f"))
	else:
		var survivor := Game.find_animal(str(result.get("survivor_id", "")))
		fusion_pair_label.text = "ONE CREATURE SAVED"
		fusion_result_image.texture = Game.creature_texture(survivor)
		fusion_result_image.modulate = Game.creature_color(survivor)
		fusion_result_message.text = "%s survived.\nThe other creature was lost." % Game.display_name(survivor)
		fusion_result_message.add_theme_color_override("font_color", Color("9b5432"))
	fusion_result_content.visible = true
	fusion_result_content.pivot_offset = fusion_result_content.size * 0.5
	fusion_result_content.scale = Vector2(0.8, 0.8)
	fusion_result_content.modulate.a = 0.0
	var reveal := fusion_panel.create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(fusion_result_content, "scale", Vector2.ONE, 0.25)
	reveal.tween_property(fusion_result_content, "modulate:a", 1.0, 0.2)
	if not succeeded:
		reveal.tween_property(fusion_result_content, "position:x", 67.0, 0.06)
		reveal.chain().tween_property(fusion_result_content, "position:x", 53.0, 0.06)
		reveal.chain().tween_property(fusion_result_content, "position:x", 60.0, 0.06)
	reveal.chain().tween_callback(func():
		fusion_resolving = false
		fusion_result_showing = true
		(fusion_panel.get_node("Cancel") as Button).visible = false
		var confirm := fusion_panel.get_node("Confirm") as Button
		confirm.text = "CONTINUE"
		confirm.position = Vector2(213, 378)
		confirm.disabled = false
		(fusion_panel.get_node("Close") as Button).disabled = false
	)

func _build_upgrade_success_panel() -> void:
	egg_upgrade_success_panel = Control.new()
	egg_upgrade_success_panel.name = "UpgradeSuccess"
	egg_upgrade_success_panel.position = Vector2(80, 190)
	egg_upgrade_success_panel.size = Vector2(560, 680)
	egg_upgrade_success_panel.pivot_offset = egg_upgrade_success_panel.size * 0.5
	egg_upgrade_success_panel.visible = false
	egg_upgrade_success_panel.z_index = 20
	egg_upgrade_modal_layer.add_child(egg_upgrade_success_panel)
	var frame := TextureRect.new()
	frame.texture = EGG_UPGRADE_PANEL_TEXTURE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg_upgrade_success_panel.add_child(frame)
	var title := Label.new()
	title.position = Vector2(65, 44)
	title.size = Vector2(430, 60)
	title.text = "UPGRADE SUCCESS!"
	_style_modal_title(title, 30)
	egg_upgrade_success_panel.add_child(title)
	egg_upgrade_success_levels = Label.new()
	egg_upgrade_success_levels.position = Vector2(50, 132)
	egg_upgrade_success_levels.size = Vector2(460, 60)
	egg_upgrade_success_levels.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	egg_upgrade_success_levels.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	egg_upgrade_success_levels.add_theme_color_override("font_color", Color("3b2416"))
	egg_upgrade_success_levels.add_theme_font_size_override("font_size", 29)
	egg_upgrade_success_levels.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	egg_upgrade_success_panel.add_child(egg_upgrade_success_levels)
	var subtitle := _new_upgrade_rate_label(Vector2(50, 200), Vector2(460, 40))
	subtitle.text = "NEW UFO DROP RATES"
	subtitle.add_theme_font_size_override("font_size", 23)
	egg_upgrade_success_panel.add_child(subtitle)
	for egg_level in range(1, 6):
		var row := Panel.new()
		row.position = Vector2(64, 250 + (egg_level - 1) * 48)
		row.size = Vector2(432, 43)
		row.add_theme_stylebox_override("panel", _card_style(Color("fff9ea"), Color("d5b779")))
		egg_upgrade_success_panel.add_child(row)
		var icon := TextureRect.new()
		icon.position = Vector2(8, 2)
		icon.size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = Game.egg_texture(egg_level)
		row.add_child(icon)
		var name_label := _new_upgrade_rate_label(Vector2(58, 1), Vector2(180, 40))
		name_label.text = "Egg Lv.%d" % egg_level
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)
		var rate := _new_upgrade_rate_label(Vector2(290, 1), Vector2(124, 40))
		rate.add_theme_font_size_override("font_size", 24)
		rate.add_theme_color_override("font_color", Color("258f38"))
		row.add_child(rate)
		egg_upgrade_success_rows.append({"icon": icon, "rate": rate})
	var ok := Button.new()
	ok.name = "Confirm"
	ok.position = Vector2(160, 555)
	ok.size = Vector2(240, 76)
	ok.text = "OK"
	ok.add_theme_font_size_override("font_size", 30)
	ok.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	ok.add_theme_color_override("font_color", Color("26340f"))
	_apply_generated_button_skin(ok, Color("72d33f"))
	ok.pressed.connect(_close_upgrade_menu)
	egg_upgrade_success_panel.add_child(ok)

func _build_upgrade_confirmation_panel() -> void:
	egg_upgrade_confirm_panel = Control.new()
	egg_upgrade_confirm_panel.name = "EggUpgradeConfirmation"
	egg_upgrade_confirm_panel.position = Vector2(80, 190)
	egg_upgrade_confirm_panel.size = Vector2(560, 720)
	egg_upgrade_confirm_panel.visible = false
	egg_upgrade_confirm_panel.z_index = 500
	egg_upgrade_modal_layer.add_child(egg_upgrade_confirm_panel)
	var frame := TextureRect.new()
	frame.texture = EGG_UPGRADE_PANEL_TEXTURE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg_upgrade_confirm_panel.add_child(frame)
	var title := Label.new()
	title.position = Vector2(65, 44)
	title.size = Vector2(430, 60)
	title.text = "EGG DROP UPGRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("fff5d2"))
	title.add_theme_color_override("font_outline_color", Color("6f3516"))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	egg_upgrade_confirm_panel.add_child(title)
	egg_upgrade_confirm_levels = Label.new()
	egg_upgrade_confirm_levels.position = Vector2(50, 111)
	egg_upgrade_confirm_levels.size = Vector2(460, 42)
	egg_upgrade_confirm_levels.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	egg_upgrade_confirm_levels.add_theme_color_override("font_color", Color("3b2416"))
	egg_upgrade_confirm_levels.add_theme_font_size_override("font_size", 27)
	egg_upgrade_confirm_levels.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	egg_upgrade_confirm_panel.add_child(egg_upgrade_confirm_levels)
	var explanation := Label.new()
	explanation.position = Vector2(42, 151)
	explanation.size = Vector2(476, 38)
	explanation.text = "Improves the egg types your UFO can drop — not one egg."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_color_override("font_color", Color("765034"))
	explanation.add_theme_font_size_override("font_size", 17)
	explanation.add_theme_font_override("font", FONT_BALOO_BOLD)
	egg_upgrade_confirm_panel.add_child(explanation)
	egg_upgrade_confirm_chance = _new_upgrade_rate_label(Vector2(48, 190), Vector2(232, 34))
	egg_upgrade_confirm_chance.add_theme_font_size_override("font_size", 22)
	egg_upgrade_confirm_chance.add_theme_color_override("font_color", Color("258f38"))
	egg_upgrade_confirm_panel.add_child(egg_upgrade_confirm_chance)
	egg_upgrade_confirm_failure = _new_upgrade_rate_label(Vector2(280, 190), Vector2(232, 34))
	egg_upgrade_confirm_failure.add_theme_font_size_override("font_size", 22)
	egg_upgrade_confirm_failure.add_theme_color_override("font_color", Color("c43f2f"))
	egg_upgrade_confirm_panel.add_child(egg_upgrade_confirm_failure)
	for header_data in [
		{"text": "EGG TYPE", "position": Vector2(93, 224), "size": Vector2(118, 30)},
		{"text": "CURRENT", "position": Vector2(232, 224), "size": Vector2(78, 30)},
		{"text": "NEXT", "position": Vector2(369, 224), "size": Vector2(72, 30)},
	]:
		var table_header := Label.new()
		table_header.position = header_data.position
		table_header.size = header_data.size
		table_header.text = header_data.text
		table_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		table_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		table_header.add_theme_color_override("font_color", Color("735035"))
		table_header.add_theme_font_size_override("font_size", 16)
		table_header.add_theme_font_override("font", FONT_BALOO_BOLD)
		egg_upgrade_confirm_panel.add_child(table_header)
	egg_upgrade_confirm_rows.clear()
	for egg_level in range(1, 6):
		var row := Panel.new()
		row.position = Vector2(48, 255 + (egg_level - 1) * 42)
		row.size = Vector2(464, 42)
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("fff9ea") if egg_level % 2 == 1 else Color("f5e7c4")
		row_style.border_color = Color("d5b779")
		row_style.set_border_width_all(2)
		row_style.set_corner_radius_all(12)
		row.add_theme_stylebox_override("panel", row_style)
		egg_upgrade_confirm_panel.add_child(row)
		var icon := TextureRect.new()
		icon.position = Vector2(5, 3)
		icon.size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var name_label := Label.new()
		name_label.position = Vector2(45, 1)
		name_label.size = Vector2(132, 40)
		name_label.text = "Egg Lv.%d" % egg_level
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color("3b2416"))
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_font_override("font", FONT_BALOO_BOLD)
		row.add_child(name_label)
		var current_label := _new_upgrade_rate_label(Vector2(184, 1), Vector2(80, 40))
		row.add_child(current_label)
		var arrow_label := _new_upgrade_rate_label(Vector2(270, 1), Vector2(38, 40))
		arrow_label.text = "→"
		arrow_label.add_theme_color_override("font_color", Color("ae7b37"))
		row.add_child(arrow_label)
		var next_label := _new_upgrade_rate_label(Vector2(314, 1), Vector2(140, 40))
		row.add_child(next_label)
		egg_upgrade_confirm_rows.append({"icon": icon, "current": current_label, "next": next_label})
	var warning := Label.new()
	warning.position = Vector2(45, 463)
	warning.size = Vector2(470, 88)
	warning.text = "⚠  THIS UPGRADE MAY FAIL!\nOn failure, the level stays the same and Gold is not refunded."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color("b83927"))
	warning.add_theme_font_size_override("font_size", 18)
	warning.add_theme_font_override("font", FONT_BALOO_BOLD)
	egg_upgrade_confirm_panel.add_child(warning)
	egg_upgrade_confirm_cost = Label.new()
	egg_upgrade_confirm_cost.position = Vector2(70, 555)
	egg_upgrade_confirm_cost.size = Vector2(420, 48)
	egg_upgrade_confirm_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	egg_upgrade_confirm_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	egg_upgrade_confirm_cost.add_theme_color_override("font_color", Color("8a5500"))
	egg_upgrade_confirm_cost.add_theme_font_size_override("font_size", 24)
	egg_upgrade_confirm_cost.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	egg_upgrade_confirm_panel.add_child(egg_upgrade_confirm_cost)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.position = Vector2(58, 616)
	cancel.size = Vector2(200, 70)
	cancel.text = "CANCEL"
	cancel.add_theme_font_size_override("font_size", 27)
	cancel.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	cancel.add_theme_color_override("font_color", Color("3b2416"))
	_apply_generated_button_skin(cancel, Color("b89778"))
	cancel.pressed.connect(_cancel_egg_upgrade_confirmation)
	egg_upgrade_confirm_panel.add_child(cancel)
	var confirm := Button.new()
	confirm.name = "Confirm"
	confirm.position = Vector2(282, 616)
	confirm.size = Vector2(220, 70)
	confirm.text = "UPGRADE"
	confirm.add_theme_font_size_override("font_size", 25)
	confirm.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	confirm.add_theme_color_override("font_color", Color("5b2e00"))
	_apply_generated_button_skin(confirm, Color("ffad24"))
	confirm.pressed.connect(_confirm_risky_egg_upgrade)
	egg_upgrade_confirm_panel.add_child(confirm)

func _new_upgrade_rate_label(position: Vector2, label_size: Vector2) -> Label:
	var label := Label.new()
	label.position = position
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("3b2416"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_font_override("font", FONT_BALOO_BOLD)
	return label

func _show_egg_upgrade_confirmation() -> void:
	var level := Game.egg_upgrade_level_for()
	var chance := EggUpgrade.success_rate(level)
	var current_rates: Dictionary = EggUpgrade.rates(level)
	var next_rates: Dictionary = EggUpgrade.rates(mini(level + 1, EggUpgrade.MAX_LEVEL))
	upgrade_menu.visible = false
	egg_upgrade_confirm_panel.visible = true
	egg_upgrade_close_button.visible = true
	_place_upgrade_close(egg_upgrade_confirm_panel)
	egg_upgrade_confirm_chance.text = "SUCCESS %.0f%%" % chance
	egg_upgrade_confirm_failure.text = "FAILURE %.0f%%" % (100.0 - chance)
	egg_upgrade_confirm_levels.text = "DROP QUALITY  Lv.%d  ➜  Lv.%d" % [level, level + 1]
	for egg_level in range(1, 6):
		var row_data: Dictionary = egg_upgrade_confirm_rows[egg_level - 1]
		var current_rate := float(current_rates.get(egg_level, 0.0))
		var next_rate := float(next_rates.get(egg_level, 0.0))
		(row_data.icon as TextureRect).texture = Game.egg_texture(egg_level)
		(row_data.current as Label).text = "%.0f%%" % current_rate
		(row_data.next as Label).text = "%.0f%%" % next_rate
		(row_data.next as Label).add_theme_color_override("font_color", Color("258f38") if next_rate > current_rate else (Color("d64932") if next_rate < current_rate else Color("3b2416")))
	egg_upgrade_confirm_cost.text = "🪙  %s GOLD" % _format_number(EggUpgrade.cost(level))
	egg_upgrade_confirm_panel.scale = Vector2(0.86, 0.86)
	egg_upgrade_confirm_panel.pivot_offset = egg_upgrade_confirm_panel.size * 0.5
	egg_upgrade_confirm_panel.modulate.a = 0.0
	var reveal := egg_upgrade_confirm_panel.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(egg_upgrade_confirm_panel, "scale", Vector2.ONE, 0.24)
	reveal.tween_property(egg_upgrade_confirm_panel, "modulate:a", 1.0, 0.16)

func _highest_unlocked_egg(upgrade_level: int) -> int:
	var highest := 1
	for egg_level in range(1, 6):
		if float(EggUpgrade.rates(upgrade_level).get(egg_level, 0.0)) > 0.0:
			highest = egg_level
	return highest

func _cancel_egg_upgrade_confirmation() -> void:
	egg_upgrade_confirm_panel.visible = false
	upgrade_menu.visible = true
	upgrade_menu.position = Vector2(35, 160)
	upgrade_menu.modulate.a = 1.0
	_place_upgrade_close(upgrade_menu)

func _confirm_risky_egg_upgrade() -> void:
	_cancel_egg_upgrade_confirmation()
	_attempt_egg_upgrade()

func _place_upgrade_close(panel: Control) -> void:
	egg_upgrade_close_button.position = panel.position + Vector2(panel.size.x - 95, 45)

func _show_upgrade_success(from_level: int, to_level: int) -> void:
	upgrade_menu.visible = false
	egg_upgrade_confirm_panel.visible = false
	egg_upgrade_success_panel.visible = true
	egg_upgrade_close_button.visible = true
	_place_upgrade_close(egg_upgrade_success_panel)
	var rates: Dictionary = EggUpgrade.rates(to_level)
	egg_upgrade_success_levels.text = "Lv.%d   ➜   Lv.%d" % [from_level, to_level]
	for egg_level in range(1, 6):
		(egg_upgrade_success_rows[egg_level - 1].rate as Label).text = "%.0f%%" % float(rates.get(egg_level, 0.0))
	egg_upgrade_success_panel.scale = Vector2(0.72, 0.72)
	egg_upgrade_success_panel.modulate.a = 0.0
	var reveal := egg_upgrade_success_panel.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(egg_upgrade_success_panel, "scale", Vector2.ONE, 0.30)
	reveal.tween_property(egg_upgrade_success_panel, "modulate:a", 1.0, 0.18)

func _toggle_upgrade_menu() -> void:
	if egg_upgrade_modal_layer.visible:
		_close_upgrade_menu()
	else:
		Audio.play_sfx("open")
		egg_upgrade_closing = false
		egg_upgrade_modal_layer.visible = true
		egg_upgrade_close_button.disabled = false
		egg_upgrade_close_button.modulate.a = 1.0
		egg_upgrade_close_button.visible = true
		egg_upgrade_close_button.position = egg_upgrade_close_base_position + Vector2(0.0, -900.0)
		upgrade_menu.visible = true
		upgrade_menu.position = Vector2(35, -740)
		egg_upgrade_feedback.text = ""
		_refresh_upgrade_shop()
		upgrade_menu.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(upgrade_menu, "position:y", 160.0, 0.28)
		egg_upgrade_close_button.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(egg_upgrade_close_button, "position:y", egg_upgrade_close_base_position.y, 0.28)

func _close_upgrade_menu() -> void:
	if egg_upgrade_modal_layer == null or not egg_upgrade_modal_layer.visible or egg_upgrade_closing:
		return
	Audio.play_sfx("close")
	egg_upgrade_closing = true
	egg_upgrade_close_button.disabled = true
	var target: Control = egg_upgrade_success_panel if egg_upgrade_success_panel.visible else (egg_upgrade_confirm_panel if egg_upgrade_confirm_panel.visible else upgrade_menu)
	var close_tween := target.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	close_tween.tween_property(target, "modulate:a", 0.0, 0.16)
	close_tween.parallel().tween_property(egg_upgrade_close_button, "modulate:a", 0.0, 0.12)
	close_tween.tween_callback(_finish_close_upgrade_menu)

func _finish_close_upgrade_menu() -> void:
	# Keep the blocker alive after release/fade so mobile touch emulation cannot
	# deliver the tail of the same tap to a control behind the modal.
	await get_tree().create_timer(0.14).timeout
	upgrade_menu.visible = false
	egg_upgrade_success_panel.visible = false
	egg_upgrade_confirm_panel.visible = false
	upgrade_menu.modulate.a = 1.0
	egg_upgrade_success_panel.modulate.a = 1.0
	egg_upgrade_confirm_panel.modulate.a = 1.0
	egg_upgrade_modal_layer.visible = false
	await get_tree().process_frame
	egg_upgrade_closing = false

func _refresh_egg_upgrade_panel() -> void:
	if egg_upgrade_summary == null:
		return
	var level := Game.egg_upgrade_level_for()
	var maxed := level >= EggUpgrade.MAX_LEVEL
	var next_level := mini(level + 1, EggUpgrade.MAX_LEVEL)
	egg_upgrade_summary.text = "EGG QUALITY  ·  Lv.%d%s\nGold: %s" % [level, "  ·  MAX LEVEL" if maxed else " → Lv.%d" % next_level, _format_number(int(Game.coins))]
	var current: Dictionary = EggUpgrade.rates(level)
	var next: Dictionary = EggUpgrade.rates(next_level)
	for egg_level in range(1, 6):
		var from_rate := float(current.get(egg_level, 0.0))
		var to_rate := float(next.get(egg_level, 0.0))
		var row_data: Dictionary = egg_upgrade_rate_rows[egg_level - 1]
		(row_data.current as Label).text = "%.0f%%" % from_rate
		(row_data.next as Label).text = "%.0f%%%s" % [to_rate, " ↑" if to_rate > from_rate else (" ↓" if to_rate < from_rate else "")]
		(row_data.next as Label).add_theme_color_override("font_color", Color("238b35") if to_rate > from_rate else (Color("d14b38") if to_rate < from_rate else Color("3b2416")))
		(row_data.arrow as Label).visible = not maxed
	if maxed:
		egg_upgrade_button.text = "MAX LEVEL"
		egg_upgrade_button.disabled = true
		egg_upgrade_feedback.text = "MAX LEVEL REACHED"
	else:
		var cost := EggUpgrade.cost(level)
		egg_upgrade_button.text = "UPGRADE  ·  🪙 %s" % _format_number(cost)
		egg_upgrade_button.disabled = egg_upgrade_busy or Game.coins < cost
		if not egg_upgrade_busy and Time.get_ticks_msec() >= egg_upgrade_feedback_until:
			egg_upgrade_feedback.text = "NOT ENOUGH GOLD" if Game.coins < cost else "READY TO UPGRADE"
			egg_upgrade_feedback.add_theme_color_override("font_color", Color("c94b3d") if Game.coins < cost else Color("2f8e38"))

func _upgrade_egg_quality() -> void:
	if egg_upgrade_busy or Game.egg_upgrade_level_for() >= EggUpgrade.MAX_LEVEL:
		return
	var cost := EggUpgrade.cost(Game.egg_upgrade_level_for())
	if Game.coins < cost:
		_toast("Not enough Gold to upgrade eggs")
		return
	if EggUpgrade.success_rate(Game.egg_upgrade_level_for()) < 100.0:
		_show_egg_upgrade_confirmation()
		return
	_attempt_egg_upgrade()

func _attempt_egg_upgrade(forced_success := -1) -> void:
	if egg_upgrade_busy or Game.egg_upgrade_level_for() >= EggUpgrade.MAX_LEVEL:
		return
	var previous_level := Game.egg_upgrade_level_for()
	var cost := EggUpgrade.cost(previous_level)
	if Game.coins < cost:
		_toast("Not enough Gold to upgrade eggs")
		return
	egg_upgrade_busy = true
	egg_upgrade_button.disabled = true
	Game.coins -= cost
	var chance := EggUpgrade.success_rate(previous_level)
	var succeeded := (randf() * 100.0 < chance) if forced_success < 0 else forced_success == 1
	Audio.play_sfx("success" if succeeded else "failure")
	if succeeded:
		Game.set_egg_upgrade_level(previous_level + 1)
	Game.save_game()
	_refresh_all()
	_refresh_egg_upgrade_panel()
	if not succeeded:
		egg_upgrade_busy = false
		upgrade_menu.visible = true
		egg_upgrade_feedback_until = Time.get_ticks_msec() + 2600
		egg_upgrade_feedback.text = "✕ UPGRADE FAILED · %s GOLD SPENT" % _format_number(cost)
		egg_upgrade_feedback.add_theme_color_override("font_color", Color("d64932"))
		_refresh_all()
		return
	egg_upgrade_feedback.text = "✓ UPGRADE SUCCESS · Lv.%d" % Game.egg_upgrade_level_for()
	egg_upgrade_button.pivot_offset = egg_upgrade_button.size * 0.5
	var bounce := egg_upgrade_button.create_tween()
	bounce.tween_property(egg_upgrade_button, "scale", Vector2(1.07, 1.07), 0.10)
	bounce.tween_property(egg_upgrade_button, "scale", Vector2.ONE, 0.14)
	bounce.tween_callback(func():
		egg_upgrade_busy = false
		_refresh_egg_upgrade_panel()
		_show_upgrade_success(previous_level, Game.egg_upgrade_level_for())
	)

func _update_farm_hud() -> void:
	if not delivery_status_label:
		return
	if farm_manager.eggs.can_receive():
		var delivery_remaining := Game.delivery_remaining_for()
		var delivery_level := Game.delivery_level_for()
		var seconds := maxi(0, ceili(delivery_remaining))
		delivery_status_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		var interval := FARM_CONFIG.delivery_interval(delivery_level)
		delivery_progress_bar.value = clampf((interval - delivery_remaining) / interval * 100.0, 0.0, 100.0)
	else:
		delivery_status_label.text = "FULL"
		delivery_progress_bar.value = 100.0
	_refresh_upgrade_shop()

func _upgrade_delivery() -> void:
	var cost := FARM_CONFIG.delivery_upgrade_cost(Game.delivery_level_for())
	if farm_manager.delivery.upgrade():
		Audio.play_sfx("success")
		_toast("The UFO now delivers eggs faster!")
	else:
		_toast("Requires %d Coin or max level reached" % cost)

func _play_friendly_ufo() -> void:
	if friendly_ufo_in_flight:
		return
	friendly_ufo_in_flight = true
	var ufo := TextureRect.new()
	ufo.texture = Game.ufo_texture("delivery", 0)
	ufo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ufo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ufo.position = Vector2(-220, 235)
	ufo.size = Vector2(220, 180)
	ufo.z_index = 10
	ufo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	farm_overlay.add_child(ufo)
	var tween := ufo.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ufo, "position", Vector2(270, 235), 1.55)
	tween.tween_callback(func(): _animate_ufo_sequence(ufo, "delivery", 8.0))
	tween.tween_property(ufo, "position:y", 224.0, 0.18)
	tween.tween_property(ufo, "position:y", 235.0, 0.18)
	tween.tween_interval(0.65)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(ufo, "position", Vector2(760, 190), 1.5)
	tween.tween_callback(func(): friendly_ufo_in_flight = false)
	tween.tween_callback(ufo.queue_free)

func _animate_ufo_sequence(view: TextureRect, kind: String, fps: float) -> void:
	for frame in Game.UFO_FRAME_COUNT:
		if not is_instance_valid(view):
			return
		view.texture = Game.ufo_texture(kind, frame)
		await get_tree().create_timer(1.0 / fps).timeout

func _on_egg_added(egg: Dictionary) -> void:
	if current_screen == "farm": Audio.play_sfx("egg_drop")
	_create_egg_view(egg, egg_views.size())
	var view: Button = egg_views.get(egg.id)
	if view and friendly_ufo_in_flight:
		view.visible = false
		_animate_delivered_egg(egg.id)
	else:
		_toast("🛸 The UFO delivered a mystery egg!")

func _animate_delivered_egg(egg_id: String) -> void:
	await get_tree().create_timer(1.85).timeout
	if not egg_views.has(egg_id):
		return
	var target: Button = egg_views[egg_id]
	var egg_tier := 1
	for egg in Game.unopened_eggs:
		if str(egg.get("id", "")) == egg_id:
			egg_tier = int(egg.get("tier", 1))
			break
	var falling_egg := TextureRect.new()
	falling_egg.texture = Game.egg_texture(egg_tier)
	falling_egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	falling_egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	falling_egg.position = Vector2(328, 345)
	falling_egg.size = Vector2(104, 104)
	falling_egg.pivot_offset = falling_egg.size * 0.5
	falling_egg.z_index = 11
	falling_egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	farm_overlay.add_child(falling_egg)
	var landing_position := target.global_position
	var drop := falling_egg.create_tween().set_parallel(true)
	drop.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(falling_egg, "position", landing_position, 0.72)
	drop.tween_property(falling_egg, "rotation", TAU, 0.72)
	await drop.finished
	falling_egg.queue_free()
	if not is_instance_valid(target):
		return
	target.visible = true
	target.scale = Vector2(0.55, 0.55)
	var bounce := target.create_tween()
	bounce.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(target, "scale", Vector2(1.18, 1.18), 0.24)
	bounce.tween_property(target, "scale", Vector2.ONE, 0.18)
	if current_screen == "farm":
		_toast("🛸 THE UFO DROPPED A MYSTERY EGG!", 3.0)

func _sync_egg_views() -> void:
	for egg in Game.unopened_eggs:
		if str(egg.get("map_id", "earth")) != current_planet:
			continue
		if not egg_views.has(egg.id):
			_create_egg_view(egg, egg_views.size())

func _create_egg_view(egg: Dictionary, index: int) -> void:
	var button := Button.new()
	button.text = ""
	button.icon = Game.egg_texture(int(egg.get("tier", 1)))
	button.expand_icon = true
	button.tooltip_text = "Tap to open egg"
	button.flat = true
	button.add_theme_font_size_override("font_size", 72)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.size = Vector2(104, 104)
	var egg_position := farm_manager.eggs.ensure_position(egg)
	var egg_layer: Node2D = $UI/FarmScreen/MapSlot/FarmMap/EggLayer
	var center_global := farm_ground.global_position + Vector2(
		farm_ground.size.x * egg_position.x / 100.0,
		farm_ground.size.y * egg_position.y / 100.0
	)
	button.position = egg_layer.to_local(center_global) - button.size * 0.5
	button.pivot_offset = button.size * 0.5
	button.z_index = 100
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): _hatch_egg(egg.id))
	$UI/FarmScreen/MapSlot/FarmMap/EggLayer.add_child(button)
	egg_views[egg.id] = button

func _hatch_egg(egg_id: String) -> void:
	if not egg_views.has(egg_id):
		return
	var view: Button = egg_views[egg_id]
	view.disabled = true
	var tween := view.create_tween()
	for angle in [0.16, -0.16, 0.12, -0.12, 0.0]:
		tween.tween_property(view, "rotation", angle, 0.07)
	tween.tween_callback(func(): _finish_hatch(egg_id))

func _finish_hatch(egg_id: String) -> void:
	if not egg_views.has(egg_id) or not is_instance_valid(egg_views[egg_id]):
		return
	var egg_view: Button = egg_views[egg_id]
	var egg_center_global := egg_view.get_global_rect().get_center()
	var egg_center_local := farm_layer.to_local(egg_center_global)
	var spawn_percent := Vector2(
		egg_center_local.x / maxf(1.0, Game.farm_size.x) * 100.0,
		egg_center_local.y / maxf(1.0, Game.farm_size.y) * 100.0
	)
	var result := farm_manager.eggs.hatch(egg_id, spawn_percent)
	if result.is_empty() and egg_views.has(egg_id):
		egg_views[egg_id].disabled = false
		egg_views[egg_id].rotation = 0.0
		_toast("The creature farm is full")

func _on_egg_hatched(result: Dictionary) -> void:
	if not result.is_empty(): Audio.play_sfx("hatch")
	for id in egg_views.keys():
		if not Game.unopened_eggs.any(func(egg): return egg.id == id):
			egg_views[id].queue_free()
			egg_views.erase(id)
	if result.is_empty():
		_toast("The creature farm is full")
		return
	if is_instance_valid(tutorial):
		tutorial.accept_event("egg_hatched", {"success": true})
	_sync_critters()
	var creature: Dictionary = result.animal
	if result.is_rare:
		_toast("✨ SHINY CREATURE! %s" % Game.display_name(creature))
	else:
		_toast("Egg hatched: %s" % Game.display_name(creature))
	Game.save_game()

func _on_income_collected(amount: int) -> void:
	Game.xp += max(1, roundi(amount / 20.0))
	if current_screen == "farm" and randf() < 0.6:
		_show_income_popup(amount)
	_apply_level_ups()
	_refresh_all()

func _on_raid_started(hp: int, seconds: float) -> void:
	_refresh_audio_context()
	if current_screen == "farm": Audio.play_sfx("warning")
	raid_hp_bar.max_value = maxi(1, farm_manager.raids.max_hp)
	raid_hit_flash_timer = 0.0
	raid_entrance_played = false
	raid_button.visible = current_screen == "farm"
	raid_overlay.visible = current_screen == "farm"
	if raid_overlay.visible:
		_apply_raid_combat_layout()
		_play_raid_entrance()
	if current_screen == "farm":
		_toast("🚨 ENEMY UFO INCOMING! Tap repeatedly to attack!")
	_on_raid_updated(hp, seconds)

func _play_raid_entrance() -> void:
	if raid_entrance_played or raid_overlay == null or not raid_overlay.visible:
		return
	raid_entrance_played = true
	var entrance_duration := 0.58
	var boss_target := raid_boss_group.position
	raid_boss_visual.texture = Game.ufo_texture("boss", 0)
	raid_boss_group.pivot_offset = raid_boss_group.size * 0.5
	raid_boss_group.position.y = boss_target.y - 190.0
	raid_boss_group.scale = Vector2(0.72, 0.72)
	raid_boss_group.modulate.a = 0.0
	var boss_entrance := raid_boss_group.create_tween()
	boss_entrance.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	boss_entrance.tween_property(raid_boss_group, "position", boss_target, entrance_duration)
	boss_entrance.parallel().tween_property(raid_boss_group, "scale", Vector2.ONE, entrance_duration)
	boss_entrance.parallel().set_trans(Tween.TRANS_CUBIC).tween_property(raid_boss_group, "modulate:a", 1.0, entrance_duration * 0.72)

	var cannon_final_position := raid_cannon_visual.position
	var fire_button_final_position := raid_fire_button.position
	raid_cannon_visual.pivot_offset = raid_cannon_visual.size * 0.5
	raid_cannon_visual.position.y = get_viewport_rect().size.y + 190.0
	raid_cannon_visual.scale = Vector2(0.72, 0.72)
	raid_cannon_visual.rotation = deg_to_rad(-3.0)
	raid_cannon_visual.modulate.a = 0.0
	raid_cannon_visual.set_entrance_glow(1.0)
	raid_fire_button.scale = Vector2(0.82, 0.82)
	raid_fire_button.modulate.a = 0.0
	var rise := raid_cannon_visual.create_tween()
	rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(raid_cannon_visual, "position", cannon_final_position, entrance_duration)
	rise.parallel().tween_property(raid_cannon_visual, "scale", Vector2.ONE, entrance_duration)
	rise.parallel().tween_property(raid_cannon_visual, "rotation", 0.0, entrance_duration)
	rise.parallel().set_trans(Tween.TRANS_CUBIC).tween_property(raid_cannon_visual, "modulate:a", 1.0, entrance_duration * 0.72)
	rise.parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(raid_fire_button, "position", fire_button_final_position, entrance_duration)
	rise.parallel().tween_property(raid_fire_button, "scale", Vector2.ONE, entrance_duration)
	rise.parallel().set_trans(Tween.TRANS_CUBIC).tween_property(raid_fire_button, "modulate:a", 1.0, entrance_duration * 0.72)
	var glow_fade := raid_cannon_visual.create_tween()
	glow_fade.tween_method(Callable(raid_cannon_visual, "set_entrance_glow"), 1.0, 0.0, entrance_duration)

func _on_raid_updated(hp: int, seconds: float) -> void:
	if raid_button:
		# Idle UFO artwork only; attack/hurt frames are shown only after a real hit.
		if raid_hit_flash_timer <= 0.0:
			raid_boss_visual.texture = Game.ufo_texture("boss", 0)
	if raid_status_label:
		raid_status_label.text = "ABDUCTION: %.1fs" % seconds
	if raid_hp_bar:
		raid_hp_bar.value = hp
		raid_hp_label.text = "%d / %d HP" % [hp, int(raid_hp_bar.max_value)]
		var fraction := float(hp) / maxf(1.0, raid_hp_bar.max_value)
		var fill := raid_hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = Color("ed654f") if fraction <= 0.25 else (Color("ffbd45") if fraction <= 0.5 else Color("76cf45"))

func _on_raid_defeated(loot: Dictionary) -> void:
	_refresh_audio_context()
	Audio.play_sfx("victory")
	raid_button.visible = false
	raid_overlay.visible = false
	if loot.get("shiny", false) or loot.get("rare", false):
		var rare_drop := farm_manager.creatures.create_tier_one(loot.get("shiny", false))
		_sync_critters()
		_toast("✨ ULTRA RARE DROP: %s" % Game.display_name(rare_drop.animal))
	elif (loot.get("egg", false) or loot.get("rare_egg", false)) and farm_manager.eggs.can_receive():
		farm_manager.eggs.deliver()
		_toast("💥 UFO DOWN! Egg received · +%d Coin" % loot.coins)
	else:
		_toast("💥 UFO DOWN! +%d Coin · +%d materials" % [loot.coins, loot.materials])

func _on_creature_abducted(creature: Dictionary) -> void:
	_refresh_audio_context()
	Audio.play_sfx("failure")
	raid_button.visible = false
	raid_overlay.visible = false
	_sync_critters()
	_toast("The UFO abducted %s! Income is reduced for 10 minutes." % Game.display_name(creature))

## Legacy screens are still moved into the shared CanvasLayer. FarmMap,
## FarmScreen and NotificationTicker are authored directly in their final
## scene hierarchy and require no runtime reparenting.
func _organize_scene_layers() -> void:
	var content_viewport := _ensure_content_viewport()
	# HomeScreen belonged to the removed landing page and is intentionally not
	# registered in `screens`. Keep it disabled before any deferred layout work
	# so it can never render over the farm during startup.
	var retired_home_screen := get_node_or_null("HomeScreen") as Control
	if retired_home_screen != null:
		retired_home_screen.visible = false
	var top_bar := get_node_or_null("TopBar")
	var top_hud := get_node_or_null("UI/TopHUD")
	if top_bar != null and top_hud != null and top_bar.get_parent() != top_hud:
		top_bar.reparent(top_hud, true)
	var bottom_nav := get_node_or_null("BottomNav")
	var bottom_menu := get_node_or_null("UI/BottomMenu")
	if bottom_nav != null and bottom_menu != null and bottom_nav.get_parent() != bottom_menu:
		bottom_nav.reparent(bottom_menu, true)
	for screen_name in ["HomeScreen", "CollectionScreen", "ShopScreen", "BattleScreen", "BattleArenaScreen", "AdventureScreen"]:
		var screen := get_node_or_null(screen_name)
		if screen != null and screen.get_parent() != content_viewport:
			screen.reparent(content_viewport, true)

func _ensure_content_viewport() -> Control:
	var ui := get_node_or_null("UI")
	if ui == null:
		return null
	var content_viewport := ui.get_node_or_null("ContentViewport") as Control
	if content_viewport == null:
		content_viewport = Control.new()
		content_viewport.name = "ContentViewport"
		content_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
		content_viewport.z_index = 100
		ui.add_child(content_viewport)
	content_viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_viewport.offset_left = 0.0
	content_viewport.offset_top = 112.0
	content_viewport.offset_right = 0.0
	content_viewport.offset_bottom = -136.0
	return content_viewport

func _display_safe_insets() -> Vector4:
	# Mobile safe rectangles are reported in physical pixels, while this UI is
	# authored in a stretched virtual viewport. Convert the four insets so camera
	# cutouts, status bars and gesture navigation never cover interactive UI.
	if OS.get_name() not in ["Android", "iOS"]:
		return Vector4.ZERO
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var viewport_size := get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var scale := Vector2(viewport_size.x / screen_size.x, viewport_size.y / screen_size.y)
	return Vector4(
		maxf(0.0, float(safe.position.x) * scale.x),
		maxf(0.0, float(safe.position.y) * scale.y),
		maxf(0.0, float(screen_size.x - safe.end.x) * scale.x),
		maxf(0.0, float(screen_size.y - safe.end.y) * scale.y)
	)

func _apply_responsive_layout() -> void:
	# The authored layout is 720x1280. With stretch/aspect=expand, tall phones
	# expose a taller virtual canvas instead of letterboxing it. Keep HUD at
	# the top, nav at the bottom, and add the extra height to the playable farm.
	var viewport_height := get_viewport_rect().size.y
	var viewport_width := get_viewport_rect().size.x
	var safe := _display_safe_insets()
	var usable_height := viewport_height - safe.y - safe.w
	var extra_height := maxf(0.0, usable_height - 1280.0)
	var content_viewport := _ensure_content_viewport()
	if content_viewport == null:
		push_error("Could not create UI/ContentViewport; check the UI node in Game.tscn")
		return
	content_viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_viewport.offset_left = 0.0
	content_viewport.offset_top = safe.y + 112.0
	content_viewport.offset_right = 0.0
	content_viewport.offset_bottom = -(safe.w + 136.0)
	# FarmScreen owns the UFO delivery bar, notification ticker, reward shortcuts,
	# map and upgrade button.  Inset the whole screen instead of moving only the
	# resource TopBar; otherwise those siblings keep their authored Y positions
	# and overlap one another below a camera cutout.
	farm_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	farm_screen.offset_left = 0.0
	farm_screen.offset_top = safe.y
	farm_screen.offset_right = 0.0
	farm_screen.offset_bottom = -safe.w
	var bottom_nav := get_node_or_null("UI/BottomMenu/BottomNav") as Control
	if bottom_nav != null:
		bottom_nav.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bottom_nav.position = Vector2(safe.x - 18.0, viewport_height - safe.w - 129.0)
		bottom_nav.size = Vector2(viewport_width - safe.x - safe.z + 32.0, 136.0)
		bottom_nav.z_index = 3000
	_apply_raid_combat_layout()
	var top_bar := get_node_or_null("UI/TopHUD/TopBar") as Control
	if top_bar != null:
		top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_KEEP_SIZE)
		top_bar.offset_left = safe.x - 4.0
		top_bar.offset_right = -(safe.z + 4.0)
		top_bar.offset_top = safe.y
		top_bar.offset_bottom = safe.y + 112.0
	for screen_name in ["HomeScreen", "CollectionScreen", "ShopScreen", "BattleScreen", "BattleArenaScreen", "AdventureScreen"]:
		var screen := content_viewport.get_node_or_null(screen_name) as Control
		if screen == null:
			continue
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.offset_left = 0.0 if screen_name in ["ShopScreen", "BattleArenaScreen"] else 60.0
		screen.offset_top = 0.0
		screen.offset_right = 0.0 if screen_name in ["ShopScreen", "BattleArenaScreen"] else -60.0
		screen.offset_bottom = 0.0
	_apply_secondary_screen_layout(maxf(746.0, viewport_height - 248.0))
	_apply_battle_presentation()
	var authored_ground_bottom := 929.0
	farm_ground.offset_bottom = authored_ground_bottom + extra_height
	var ground_style := StyleBoxFlat.new()
	ground_style.bg_color = MAP_GROUND_COLORS.get(current_planet, MAP_GROUND_COLORS.earth)
	ground_style.border_color = MAP_BORDER_COLORS.get(current_planet, MAP_BORDER_COLORS.earth)
	ground_style.set_border_width_all(3)
	ground_style.set_corner_radius_all(16)
	farm_ground.add_theme_stylebox_override("panel", ground_style)
	_resize_ground_tiles(extra_height)
	var upgrade_button := $UI/FarmScreen/OpenUpgradeShop as Control
	upgrade_button.position.y = 1045.0 + extra_height
	upgrade_button.size.x = 220.0
	upgrade_button.position.x = (farm_screen.size.x - upgrade_button.size.x) * 0.5
	if is_instance_valid(rewards_hub): rewards_hub.layout_shortcuts(140.0)
	var background := farm_map.get_node_or_null("Background")
	if background != null:
		for child in background.get_children():
			if child is Node2D and float(child.get_meta("responsive_base_y", -1.0)) < 0.0:
				child.set_meta("responsive_base_y", child.position.y)
			if child is Node2D:
				var base_y := float(child.get_meta("responsive_base_y", child.position.y))
				if base_y >= 900.0:
					child.position.y = base_y + extra_height
				elif base_y > 250.0:
					# Spread decorations through the taller playable area without
					# stretching their sprites or changing their X positions.
					child.position.y = 250.0 + (base_y - 250.0) * ((650.0 + extra_height) / 650.0)
	if farm_map.has_method("apply_theme"):
		farm_map.call("apply_theme")

func _resize_ground_tiles(extra_height: float) -> void:
	var layer := farm_map.get_node_or_null("Background/GroundTileLayer") as TileMapLayer
	if layer == null or layer.tile_set == null:
		return
	var used := layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	if not layer.has_meta("responsive_base_bottom"):
		layer.set_meta("responsive_base_bottom", used.end.y)
		layer.set_meta("responsive_base_left", used.position.x)
		layer.set_meta("responsive_base_right", used.end.x)
	var base_bottom := int(layer.get_meta("responsive_base_bottom"))
	var left := int(layer.get_meta("responsive_base_left"))
	var right := int(layer.get_meta("responsive_base_right"))
	var tile_height := maxi(1, layer.tile_set.tile_size.y)
	var extra_rows := ceili(extra_height / float(tile_height))
	var target_bottom := base_bottom + extra_rows
	# Copy the final authored ground row into any additional screen height.
	for y in range(base_bottom, target_bottom):
		for x in range(left, right):
			var template := Vector2i(x, base_bottom - 1)
			var source_id := layer.get_cell_source_id(template)
			if source_id < 0:
				# Some decorative maps have gaps in the last row; find the
				# nearest valid ground cell in the same column.
				for sample_y in range(base_bottom - 2, used.position.y - 1, -1):
					template = Vector2i(x, sample_y)
					source_id = layer.get_cell_source_id(template)
					if source_id >= 0:
						break
			if source_id >= 0:
				layer.set_cell(Vector2i(x, y), source_id, layer.get_cell_atlas_coords(template), layer.get_cell_alternative_tile(template))
	# Remove only rows created by this responsive routine when returning to
	# a shorter viewport (for example desktop preview after phone testing).
	var current_bottom := layer.get_used_rect().end.y
	for y in range(target_bottom, current_bottom):
		for x in range(left, right):
			layer.erase_cell(Vector2i(x, y))

func _apply_secondary_screen_layout(content_height: float) -> void:
	# Collection: header/filter stay compact; only the card list consumes the
	# remaining space and therefore gets a longer scroll viewport.
	var collection_scroll := get_node_or_null("UI/ContentViewport/CollectionScreen/CreatureScroll") as Control
	if collection_scroll != null:
		collection_scroll.anchor_bottom = 1.0
		collection_scroll.offset_top = 282.0
		collection_scroll.offset_bottom = -8.0

	# Shop: keep title and wallet summary at the top, extend the item list.
	var shop_scroll := get_node_or_null("UI/ContentViewport/ShopScreen/Scroll") as Control
	if shop_scroll != null:
		shop_scroll.anchor_bottom = 1.0
		shop_scroll.offset_top = 112.0
		shop_scroll.offset_bottom = -8.0

	# Team selection: the board background grows while actions remain close
	# to the bottom navigation area.
	var battle := get_node_or_null("UI/ContentViewport/BattleScreen")
	if battle != null:
		var battle_board := battle.get_node_or_null("TeamBoard") as Control
		var battle_actions := battle.get_node_or_null("Actions") as Control
		var battle_status := battle.get_node_or_null("Status") as Control
		if battle_board != null:
			battle_board.offset_bottom = content_height - 214.0
		if battle_actions != null:
			battle_actions.position.y = content_height - 194.0
		if battle_status != null:
			battle_status.position.y = content_height - 96.0
			battle_status.size.y = 84.0
		var picker_panel := battle.get_node_or_null("CreaturePicker/Dim/Panel") as Control
		if picker_panel != null:
			var picker_height := minf(760.0, content_height - 40.0)
			picker_panel.position.y = (content_height - picker_height) * 0.5
			picker_panel.size.y = picker_height
			var picker_scroll := picker_panel.get_node_or_null("Scroll") as Control
			if picker_scroll != null:
				picker_scroll.offset_bottom = picker_height - 116.0
			var picker_close := picker_panel.get_node_or_null("Close") as Control
			if picker_close != null:
				picker_close.position.y = picker_height - 100.0

	# Active battle exposes a dedicated hook because its 11x3 grid needs each
	# row recalculated, not just a taller surrounding panel.
	if battle_arena_screen != null:
		battle_arena_screen.apply_responsive_height(content_height)

func _apply_battle_presentation() -> void:
	# Match, intro and results own the whole canvas. Restore the normal shell on
	# exit; no OS fullscreen/window-mode change is needed on desktop or mobile.
	var in_match := current_screen == "battle_match"
	var content := get_node_or_null("UI/ContentViewport") as Control
	if content == null: return
	var safe := _display_safe_insets()
	content.offset_top = safe.y if in_match else safe.y + 112.0
	content.offset_bottom = -safe.w if in_match else -(safe.w + 136.0)
	$UI/TopHUD.visible = not in_match
	$UI/BottomMenu.visible = not in_match
	if is_instance_valid(battle_arena_screen):
		battle_arena_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		battle_arena_screen.apply_responsive_height(content.size.y)

func _open_battle_match(opponent_title: String, opponent_power: int) -> void:
	_show_screen("battle_match")
	if current_screen == "battle_match":
		battle_arena_screen.start_match(opponent_title, opponent_power)

func _startup_screen() -> String:
	return "farm"

func _setup_settings() -> void:
	settings_popup = preload("res://scripts/ui/SettingsPopup.gd").new()
	add_child(settings_popup)
	settings_popup.can_open = func(): return not _has_blocking_modal() and current_screen != "battle_match" and not farm_manager.raids.active and not (is_instance_valid(tutorial) and tutorial.visible)
	settings_popup.closed.connect(func(): modal_input_guard_until = Time.get_ticks_msec() + 180)
	Audio.preferences_changed.connect(_refresh_language_ui)
	_refresh_language_ui()
	var bar := $UI/TopHUD/TopBar
	# Tutorial replay remains available inside Settings; the duplicate ? button
	# was removed from the compact top HUD.
	dna_label.size.x = 68
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.tooltip_text = "Settings"
	# A separate centered image avoids Button's default left-aligned icon slot.
	var gear := TextureRect.new()
	gear.name = "GearIcon"
	gear.texture = preload("res://assets/ui/settings-gear.svg")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_button.add_child(gear)
	gear.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gear.offset_left = -30
	gear.offset_right = 30
	gear.offset_top = -30
	gear.offset_bottom = 30
	preload("res://scripts/battle/BattleUI.gd").button(settings_button, Color("ffcb67"))
	bar.add_child(settings_button)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -88
	settings_button.offset_right = -8
	settings_button.offset_top = 4
	settings_button.offset_bottom = 84
	settings_button.pressed.connect(func():
		if not _has_blocking_modal(): _cancel_drag()
		settings_popup.open())

func _refresh_language_ui() -> void:
	if is_instance_valid(rewards_hub): rewards_hub.set_language(Audio.language)
	if is_instance_valid(settings_button): settings_button.tooltip_text = "Settings"

func _refresh_audio_context() -> void:
	Audio.set_context("battle" if current_screen == "battle_match" else ("raid" if current_screen == "farm" and farm_manager.raids.active else "farm"))

func _has_blocking_modal() -> bool:
	return Time.get_ticks_msec() < modal_input_guard_until \
		or (is_instance_valid(settings_popup) and settings_popup.visible) \
		or (is_instance_valid(rewards_hub) and rewards_hub.visible) \
		or (is_instance_valid(battle_arena_screen) and is_instance_valid(battle_arena_screen.result_popup) and battle_arena_screen.result_popup.visible) \
		or (is_instance_valid(egg_upgrade_modal_layer) and egg_upgrade_modal_layer.visible) \
		or (is_instance_valid(fusion_modal_layer) and fusion_modal_layer.visible) \
		or is_instance_valid(discovery_overlay) \
		or (is_instance_valid(collection_screen) and is_instance_valid(collection_screen.popup) and collection_screen.popup.visible) \
		or (is_instance_valid(egg_rate_dialog) and egg_rate_dialog.visible) \
		or (is_instance_valid(battle_screen) and (battle_screen.picker.visible or battle_screen.result_popup.visible))

func _show_screen(screen_name: String) -> void:
	if _has_blocking_modal():
		return
	if current_screen == "battle_match" and battle_arena_screen.running and screen_name != "battle_match":
		battle_arena_screen.leave_button.text = "USE LEAVE TO EXIT"
		return
	if farm_manager != null and farm_manager.raids.active and screen_name != "farm":
		_warn_raid_screen_switch()
		return
	if not screens.has(screen_name):
		return
	var target: Control = screens[screen_name]
	var is_change := screen_name != current_screen or not target.visible
	if not is_change and screen_transition != null:
		_refresh_all()
		return
	if screen_name != current_screen and toast_panel.visible:
		toast_panel.visible = false
		toast_elapsed = 0.0
		toast_queue.clear()
		toast_running = false
		if toast_tween and toast_tween.is_valid():
			toast_tween.kill()
	if screen_transition and screen_transition.is_valid():
		screen_transition.kill()
	if screen_name != current_screen:
		_cancel_drag()
		if current_screen == "battle_match":
			battle_arena_screen.abandon_match()
	for key in screens:
		var screen: Control = screens[key]
		screen.visible = key == screen_name
		screen.modulate.a = 1.0
	current_screen = screen_name
	_refresh_audio_context()
	_apply_battle_presentation()
	target.modulate.a = 0.0
	if raid_button:
		raid_button.visible = screen_name == "farm" and farm_manager.raids.active
	if raid_overlay:
		raid_overlay.visible = screen_name == "farm" and farm_manager.raids.active
		if screen_name == "farm" and farm_manager.raids.active and not raid_entrance_played:
			_apply_raid_combat_layout()
			_play_raid_entrance()
	for button in get_tree().get_nodes_in_group("screen_nav"):
		var selected: bool = str(button.get_meta("screen_name")) == screen_name
		button.modulate = Color.WHITE if selected else Color("d8cdb0")
		button.scale = Vector2(1.06, 1.06) if selected else Vector2.ONE
		button.pivot_offset = button.size * 0.5
	_refresh_all()
	screen_transition = target.create_tween()
	screen_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	screen_transition.tween_property(target, "modulate:a", 1.0, 0.18)
	if is_instance_valid(tutorial):
		if screen_name == "shop": tutorial.accept_event("screen_shop")
		elif screen_name == "farm": tutorial.accept_event("screen_farm")
		elif screen_name == "mutations": tutorial.accept_event("screen_collection")

func _refresh_all() -> void:
	coin_label.text = str(int(Game.coins))
	gem_label.text = str(Game.gems)
	dna_label.text = str(Game.energy_balance())
	dna_label.tooltip_text = "ENERGY · %d per battle · refill with optional ads (cap 240)" % Game.PlayProgress.BATTLE_COST
	level_label.text = "FARM LV.%d" % Game.farm_level
	level_label.tooltip_text = "Farm XP: %d/%d · Passive Gold bonus: +%d%%" % [roundi(Game.xp), roundi(Game.xp_to_next), roundi((Game.farm_income_multiplier() - 1.0) * 100.0)]
	# XpBar is optional because the compact farm HUD no longer displays it.
	if xp_bar != null:
		xp_bar.max_value = Game.xp_to_next
		xp_bar.value = Game.xp
	%ShopBalance.text = "Balance: 🪙 %d     💎 %d" % [int(Game.coins), Game.gems]
	if is_instance_valid(shop_view):
		shop_view.refresh(str(PLANETS[current_planet].name))
	if current_screen == "mutations":
		collection_screen.refresh()
	elif current_screen == "battle":
		battle_screen.refresh()

func _card_style(fill: Color, border: Color = INK) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	return style

func _format_number(value: int) -> String:
	var source := str(value)
	var result := ""
	while source.length() > 3:
		result = "." + source.right(3) + result
		source = source.left(source.length() - 3)
	return source + result

func _build_egg_shop() -> void:
	# Keep the old authored nodes available in the project, but replace their
	# presentation with a dedicated, editable Shop scene.
	for legacy in %ShopScreen.get_children():
		if legacy is CanvasItem:
			legacy.hide()
	shop_view = preload("res://scenes/shop/ShopScreen.tscn").instantiate()
	%ShopScreen.add_child(shop_view)
	shop_view.can_interact = func(): return not _has_blocking_modal()
	shop_view.egg_requested.connect(_buy_shop_egg)
	shop_view.chicken_requested.connect(_buy_daily_chicken)
	shop_view.item_requested.connect(_buy_item)
	shop_view.rates_requested.connect(_show_egg_drop_rates)
	var rates_canvas := CanvasLayer.new()
	rates_canvas.name = "EggDropRateCanvas"
	rates_canvas.layer = 100
	add_child(rates_canvas)
	egg_rate_dialog = preload("res://scripts/ui/EggDropRatePopup.gd").new()
	egg_rate_dialog.theme = theme
	rates_canvas.add_child(egg_rate_dialog)
	_style_modal_title(egg_rate_dialog.title, 36)
	_style_fusion_action_button(egg_rate_dialog.done_button, Color("78c43b"), Color("fff5d2"))
	egg_rate_dialog.closed.connect(func(): modal_input_guard_until = Time.get_ticks_msec() + 180)

func _show_egg_drop_rates(egg_level: int) -> void:
	if _has_blocking_modal():
		return
	_cancel_drag()
	egg_rate_dialog.show_rates(egg_level, str(PLANETS[current_planet].name), Game.egg_texture(egg_level))

func _buy_daily_chicken(offer_id: String, day: int) -> void:
	if _has_blocking_modal(): return
	var result := Game.purchase_daily_chicken(offer_id, day)
	if not result.get("ok", false):
		shop_view.show_notice("Purchase unavailable: %s. Nothing charged." % str(result.reason).replace("_", " "), false)
		_refresh_all()
		return
	Audio.play_sfx("reward")
	shop_view.show_notice("%s joined %s Farm!" % [Game.display_name(result.animal), current_planet.capitalize()])
	_sync_critters()
	_refresh_all()
	if is_instance_valid(tutorial) and tutorial_has_merge_pair(): tutorial.accept_event("pair_ready", {"success": true})

func _buy_shop_egg(egg_level: int) -> void:
	if _has_blocking_modal():
		return
	var result := Game.purchase_daily_egg(egg_level, shop_view.roster_day)
	if not result.get("ok", false):
		shop_view.show_notice("Purchase unavailable: %s. Nothing charged." % str(result.reason).replace("_", " "), false)
		_refresh_all()
		return
	_toast("🥚 Egg Lv.%d hatched a Tier %d Chicken!" % [egg_level, int(result.chicken_tier)])
	Audio.play_sfx("hatch")
	shop_view.show_notice("%s FARM: Egg Lv.%d → %s · Tier %d" % [PLANETS[Game.current_planet].name.to_upper(), egg_level, Game.display_name(result.animal), int(result.chicken_tier)])
	_sync_critters()
	_refresh_all()
	Game.save_game()

func _buy_item(item_id: String) -> void:
	if _has_blocking_modal():
		return
	var result: Dictionary = {}
	match item_id:
		"ga_ta_vang", "ga_ac_den", "ga_ri_do", "ga_silk_trang", "hybrid_ta_ac", "hybrid_ta_ri", "hybrid_ac_ri", "ga_comet", "ga_oracle", "ga_chaos":
			if Game.coins < Game.BUY_STARTER_COST:
				_toast("Not enough Coin")
				return
			if Game.animals_for_map().size() >= Game.MAX_ANIMALS:
				_toast("The farm is full")
				return
			var allowed_species := Game.species_ids_for_map()
			if not allowed_species.has(item_id):
				item_id = str(allowed_species.pick_random())
			Game.coins -= Game.BUY_STARTER_COST
			result = Game.create_animal(item_id, 1, {"x": randf_range(10, 90), "y": randf_range(18, 88)})
			_toast("✨ A new chicken arrived at the farm!")
			shop_view.show_notice("%s joined your %s farm!" % [Game.display_name(result.animal), PLANETS[current_planet].name])
		"food":
			result = Game.buy_food()
			if not result.ok:
				_toast("Not enough Coin")
				return
			_apply_level_ups()
			_toast("🍚 +15 XP · +60 Coin")
			shop_view.show_notice("Feed used! +%d XP and +%d Gold." % [Game.FOOD_XP, Game.FOOD_COIN_BONUS])
		"gems":
			result = Game.buy_gem_pouch()
			if not result.ok:
				_toast("Not enough Coin")
				return
			_toast("💎 +15 Gems")
			shop_view.show_notice("+%d Gems added to your wallet!" % Game.GEM_POUCH_AMOUNT)
		"egg":
			result = Game.hatch_mystery_egg({"x": 50.0, "y": 50.0})
			if not result.ok:
				_toast("Not enough Gems or the farm is full")
				return
			_toast("🥚 The egg hatched!")
	if not result.is_empty(): Audio.play_sfx("reward")
	_sync_critters()
	_refresh_all()
	Game.save_game()
	if is_instance_valid(tutorial) and not result.is_empty() and tutorial_has_merge_pair():
		tutorial.accept_event("pair_ready", {"success": true})

func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		Game.save_game()

func _process(delta: float) -> void:
	energy_refresh_elapsed += delta
	if energy_refresh_elapsed >= 1.0:
		energy_refresh_elapsed = 0.0
		dna_label.text = str(Game.energy_balance())
		if current_screen == "battle": battle_screen.refresh_energy()
	if raid_warning_cooldown > 0.0:
		raid_warning_cooldown = maxf(0.0, raid_warning_cooldown - delta)
	if raid_hit_flash_timer > 0.0:
		raid_hit_flash_timer = maxf(0.0, raid_hit_flash_timer - delta)
		if raid_hit_flash_timer == 0.0 and farm_manager != null and farm_manager.raids.active:
			raid_boss_visual.texture = Game.ufo_texture("boss", 0)
	if farm_manager:
		Game.farm_size = farm_ground.size
		if _has_blocking_modal():
			farm_manager.delivery.step(delta)
			farm_manager.income.step(delta)
		else:
			farm_manager.step(delta, current_screen == "farm")
		_update_farm_hud()
	save_elapsed += delta
	if save_elapsed >= 5.0:
		save_elapsed = 0.0
		Game.save_game()
func _apply_level_ups() -> void:
	while Game.xp >= Game.xp_to_next:
		Game.xp -= Game.xp_to_next
		Game.farm_level += 1
		Game.xp_to_next = round(Game.xp_to_next * 1.18)
		_toast("🎉 FARM LV.%d · Passive Gold +1%%" % Game.farm_level)

func _sync_critters() -> void:
	var alive := {}
	var farm_animals := Game.animals_for_map(current_planet)
	for animal in farm_animals:
		alive[animal.id] = true
	for id in critter_views.keys().duplicate():
		if not alive.has(id):
			critter_views[id].queue_free()
			critter_views.erase(id)
	for animal in farm_animals:
		if not critter_views.has(animal.id):
			var view := CritterScene.instantiate()
			farm_layer.add_child(view)
			view.setup(animal.id)
			critter_views[animal.id] = view
	if not selected_animal_id.is_empty() and not alive.has(selected_animal_id):
		selected_animal_id = ""
	if not drag_id.is_empty() and not alive.has(drag_id):
		_cancel_drag()
	_update_critter_selection()

func _step_wander(delta: float) -> void:
	creature_ai.step(delta)

func _switch_planet(planet_id: String) -> void:
	if _has_blocking_modal():
		return
	if farm_manager != null and farm_manager.raids.active:
		_warn_raid_screen_switch()
		return
	_replace_farm_map(planet_id, true)

func _cycle_farm_map() -> void:
	if farm_manager != null and farm_manager.raids.active:
		_warn_raid_screen_switch()
		return
	var index := MAP_ORDER.find(current_planet)
	_switch_planet(MAP_ORDER[(index + 1) % MAP_ORDER.size()])

func _replace_farm_map(planet_id: String, announce: bool) -> void:
	if not MAP_SCENES.has(planet_id):
		planet_id = "earth"
	if planet_id == current_planet and farm_map != null:
		_update_map_switch_button()
		return
	# Invalidate old pointer events before swapping the map and its coordinates.
	_cancel_drag()
	selected_animal_id = ""
	pending_fusion.clear()
	pending_fusion_planet = ""
	if is_instance_valid(fusion_modal_layer):
		fusion_modal_layer.visible = false
	for view in critter_views.values():
		if is_instance_valid(view):
			view.queue_free()
	for view in egg_views.values():
		if is_instance_valid(view):
			view.queue_free()
	critter_views.clear()
	egg_views.clear()
	var map_slot := $UI/FarmScreen/MapSlot
	if is_instance_valid(farm_map):
		map_slot.remove_child(farm_map)
		farm_map.queue_free()
	farm_map = MAP_SCENES[planet_id].instantiate() as Node2D
	farm_map.name = "FarmMap"
	map_slot.add_child(farm_map)
	map_slot.move_child(farm_map, 0)
	farm_ground = farm_map.get_node("FarmGround") as Panel
	farm_layer = farm_map.get_node("MouseLayer/FarmCritterLayer") as Node2D
	current_planet = planet_id
	Game.current_planet = planet_id
	_ensure_farm_runtime_layers()
	if farm_manager != null:
		_sync_critters()
		_sync_egg_views()
	_update_map_switch_button()
	call_deferred("_apply_responsive_layout")
	if announce:
		Game.save_game()
		_toast("🚀 Traveling to %s!" % PLANETS[planet_id].name)

func _update_map_switch_button() -> void:
	if map_switch_button == null:
		return
	var index := maxi(0, MAP_ORDER.find(current_planet))
	map_switch_button.text = "🗺  %s  %d/%d" % [PLANETS[current_planet].name, index + 1, MAP_ORDER.size()]

func _show_income_popup(amount: int) -> void:
	if critter_views.is_empty():
		return
	var view: Node2D = critter_views.values().pick_random()
	var popup := Label.new()
	popup.text = "+%d 🪙" % amount
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", Color("f6b82f"))
	popup.add_theme_color_override("font_outline_color", INK)
	popup.add_theme_constant_override("outline_size", 4)
	popup.position = view.position + Vector2(-30, -55)
	farm_layer.add_child(popup)
	var tween := popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60.0, 1.2)
	tween.tween_property(popup, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(popup.queue_free)

func _input(event: InputEvent) -> void:
	if current_screen != "farm" or _has_blocking_modal():
		return
	var pointer_position := Vector2(-1, -1)
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer_position = event.position
	if is_instance_valid(tutorial) and tutorial.blocks_farm_input(pointer_position):
		return
	if is_instance_valid(rewards_hub):
		for shortcut in [rewards_hub.daily_button, rewards_hub.ad_button]:
			if shortcut.is_visible_in_tree() and shortcut.get_global_rect().has_point(pointer_position): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _try_hatch_at(event.position):
			get_viewport().set_input_as_handled()
			return
		if event.pressed: _begin_drag(event.position)
		else: _end_drag()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and _try_hatch_at(event.position):
			get_viewport().set_input_as_handled()
			return
		if event.pressed: _begin_drag(event.position)
		else: _end_drag()
	elif event is InputEventScreenDrag:
		_update_drag(event.position)

func _try_hatch_at(screen_position: Vector2) -> bool:
	for egg_id in egg_views:
		var view: Button = egg_views[egg_id]
		if is_instance_valid(view) and not view.disabled and view.get_global_rect().has_point(screen_position):
			_hatch_egg(str(egg_id))
			return true
	return false

func _farm_local(screen_position: Vector2) -> Vector2:
	# Creature coordinates are local to FarmCritterLayer, not FarmGround.
	# Using the layer transform keeps picking correct after the map, layer or
	# parent is moved/scaled in the editor.
	return farm_layer.to_local(screen_position)

func _animal_at(point: Vector2, except := "") -> Dictionary:
	var nearest := {}
	var distance := INF
	for animal in Game.animals_for_map(current_planet):
		if animal.id == except: continue
		if not _has_visible_critter(str(animal.id)):
			continue
		var pos := Vector2(animal.x / 100.0 * Game.farm_size.x, animal.y / 100.0 * Game.farm_size.y)
		var d := point.distance_to(pos)
		# A slightly generous radius feels reliable on a phone touch screen.
		if d < 56 and d < distance:
			nearest = animal
			distance = d
	return nearest

func _begin_drag(position: Vector2) -> void:
	_cancel_drag()
	if current_screen != "farm" or _has_blocking_modal():
		return
	var animal := _animal_at(_farm_local(position))
	if animal.is_empty():
		_set_selected_animal("")
		return
	_set_selected_animal(animal.id)
	drag_id = animal.id
	drag_planet = current_planet
	drag_start = position
	drag_moved = false
	animal.dragging = true
	animal.walking = false

func _set_selected_animal(animal_id: String) -> void:
	selected_animal_id = animal_id
	_update_critter_selection()

func _update_critter_selection() -> void:
	for id in critter_views:
		var view = critter_views[id]
		if is_instance_valid(view):
			view.highlighted = str(id) == selected_animal_id
			view.queue_redraw()

func _update_drag(position: Vector2) -> void:
	if drag_id.is_empty(): return
	if not _drag_is_current():
		_cancel_drag()
		return
	drag_moved = drag_moved or position.distance_to(drag_start) > 8
	var animal := Game.find_animal(drag_id)
	if animal.is_empty(): return
	var local := _farm_local(position)
	animal.x = clampf(local.x / maxf(1, Game.farm_size.x) * 100.0, 3, 97)
	animal.y = clampf(local.y / maxf(1, Game.farm_size.y) * 100.0, 8, 94)

func _end_drag() -> void:
	if drag_id.is_empty(): return
	if not _drag_is_current():
		_cancel_drag()
		return
	var animal := Game.find_animal(drag_id)
	var source_id := drag_id
	var was_moved := drag_moved
	_cancel_drag()
	if animal.is_empty(): return
	if not was_moved: return
	var target := _animal_at(Vector2(animal.x / 100.0 * Game.farm_size.x, animal.y / 100.0 * Game.farm_size.y), source_id)
	var kind := Game.pairing_kind(animal, target)
	if kind == "merge":
		var merge_result := farm_manager.merge.merge(source_id, target.id)
		_sync_critters()
		_play_merge_reveal(merge_result, false)
		_show_merge_success(merge_result, false)
		if is_instance_valid(tutorial) and not merge_result.is_empty():
			tutorial.accept_event("merge_succeeded", {"success": true})
	elif kind == "crossbreed":
		pending_fusion = [source_id, target.id]
		var chance := farm_manager.fusion.chance(source_id, target.id)
		_show_fusion_modal(animal, target, chance)
	_sync_critters()
	_refresh_all()
	Game.save_game()

func _has_visible_critter(animal_id: String) -> bool:
	var view: Node2D = critter_views.get(animal_id)
	return is_instance_valid(view) and not view.is_queued_for_deletion() and view.is_visible_in_tree()

func _drag_is_current() -> bool:
	return current_screen == "farm" and not _has_blocking_modal() \
		and drag_planet == current_planet and current_planet == Game.current_planet \
		and Game.animal_belongs_to_map(Game.find_animal(drag_id), current_planet) \
		and _has_visible_critter(drag_id)

func _cancel_drag() -> void:
	var animal := Game.find_animal(drag_id)
	if not animal.is_empty():
		animal.dragging = false
	drag_id = ""
	drag_planet = ""
	drag_moved = false

func _confirm_fusion() -> void:
	if fusion_closing or fusion_resolving:
		return
	if fusion_result_showing:
		_hide_fusion_modal()
		return
	if pending_fusion.size() != 2:
		return
	var left := Game.find_animal(pending_fusion[0])
	var right := Game.find_animal(pending_fusion[1])
	if pending_fusion_planet != current_planet or Game.pairing_kind(left, right) != "crossbreed" \
			or not _has_visible_critter(pending_fusion[0]) or not _has_visible_critter(pending_fusion[1]):
		_hide_fusion_modal()
		return
	fusion_resolving = true
	var result := farm_manager.fusion.fuse(pending_fusion[0], pending_fusion[1])
	pending_fusion.clear()
	if result.is_empty():
		fusion_resolving = false
		_hide_fusion_modal()
		_toast("This pair can no longer be fused.")
		return
	_sync_critters()
	_refresh_all()
	# Resolve and persist once, before the visual sequence. Repeated clicks or
	# an app interruption must never re-roll or consume the pair twice.
	Game.save_game()
	_play_fusion_outcome(result)

func _play_merge_reveal(result: Dictionary, is_fusion: bool) -> void:
	if result.is_empty() or not result.has("animal"):
		return
	if not is_fusion: Audio.play_sfx("merge")
	var creature: Dictionary = result.animal
	var local_position := Vector2(
		creature.x / 100.0 * Game.farm_size.x,
		creature.y / 100.0 * Game.farm_size.y
	)
	var reveal_global_position := farm_ground.global_position + local_position
	var is_first_discovery := bool(result.get("is_first", false))
	if not is_first_discovery:
		var burst := MergeBurstScene.new()
		burst.position = effects_layer.to_local(reveal_global_position)
		burst.z_index = 900
		burst.setup(Color("d970ff") if is_fusion else Color("ffd84d"))
		effects_layer.add_child(burst)
	if not critter_views.has(creature.id):
		return
	var view: Node2D = critter_views[creature.id]
	view.modulate = Color(1, 1, 1, 0)
	view.scale = Vector2(0.25, 0.25)
	view.z_index = 901
	if is_first_discovery:
		_play_first_discovery_overlay(creature, view)
	else:
		var reveal := view.create_tween().set_parallel(true)
		reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_interval(0.22)
		reveal.tween_property(view, "modulate:a", 1.0, 0.42).set_delay(0.18)
		reveal.tween_property(view, "scale", Vector2.ONE, 0.55).set_delay(0.18)
		reveal.chain().tween_callback(func(): view.z_index = int(creature.y))

func _play_first_discovery_overlay(creature: Dictionary, farm_view: Node2D) -> void:
	Audio.play_sfx("success")
	var discovery_canvas := CanvasLayer.new()
	discovery_canvas.name = "DiscoveryCanvas"
	discovery_canvas.layer = 110
	add_child(discovery_canvas)
	var overlay := Control.new()
	discovery_overlay = overlay
	discovery_canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 4000
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0

	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load("res://assets/effects/new-discovery/reveal-backdrop.png") as Texture2D
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(backdrop)

	var question := Label.new()
	question.text = "?"
	question.position = Vector2(500, 175)
	question.size = Vector2(150, 180)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 150)
	question.add_theme_color_override("font_color", Color("ffe34f"))
	question.add_theme_color_override("font_outline_color", Color("3b69a5"))
	question.add_theme_constant_override("outline_size", 14)
	overlay.add_child(question)

	var headline := Label.new()
	headline.text = "WHO IS IT?"
	headline.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	headline.position = Vector2(110, 90)
	headline.size = Vector2(500, 90)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 48)
	headline.add_theme_color_override("font_color", Color("fff3a0"))
	headline.add_theme_color_override("font_outline_color", Color("49305f"))
	headline.add_theme_constant_override("outline_size", 10)
	overlay.add_child(headline)
	var name_label := Label.new()
	name_label.text = "%s  ·  TIER %d" % [Game.display_name(creature), int(creature.tier)]
	name_label.add_theme_font_override("font", FONT_BALOO_EXTRA_BOLD)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.position = Vector2(70, 735)
	name_label.size = Vector2(580, 70)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color("49305f"))
	name_label.add_theme_constant_override("outline_size", 8)
	name_label.modulate.a = 0.0
	overlay.add_child(name_label)

	var halo := NewDiscoveryVFXScene.new()
	halo.position = Vector2(360, 585)
	halo.scale = Vector2(1.35, 1.35)
	overlay.add_child(halo)

	var preview := Sprite2D.new()
	preview.texture = Game.creature_texture(creature)
	preview.position = Vector2(360, 690)
	preview.scale = Vector2(0.34, 0.34)
	preview.modulate = Color(0.025, 0.02, 0.045, 0.0)
	preview.z_index = 960
	overlay.add_child(preview)

	var intro := overlay.create_tween()
	intro.tween_property(overlay, "modulate:a", 1.0, 0.18)
	intro.tween_interval(0.10)
	intro.set_parallel(true)
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(preview, "position:y", 520.0, 0.72)
	intro.tween_property(preview, "scale", Vector2(0.58, 0.58), 0.72)
	intro.tween_property(preview, "modulate:a", 1.0, 0.24)
	intro.chain().set_parallel(false)
	intro.tween_interval(0.32)
	intro.tween_callback(func():
		headline.text = "✨ DISCOVERED! ✨"
		question.visible = false
	)
	intro.tween_property(preview, "modulate", Color.WHITE, 0.16)
	intro.parallel().tween_property(name_label, "modulate:a", 1.0, 0.16)
	intro.tween_property(preview, "scale", Vector2(0.68, 0.68), 0.16).set_trans(Tween.TRANS_BACK)
	intro.tween_property(preview, "scale", Vector2(0.58, 0.58), 0.16)
	intro.tween_interval(0.65)
	intro.tween_property(overlay, "modulate:a", 0.0, 0.30)
	intro.tween_callback(func():
		if is_instance_valid(farm_view):
			farm_view.modulate = Color.WHITE
			farm_view.scale = Vector2.ONE
			farm_view.z_index = int(creature.y)
		modal_input_guard_until = Time.get_ticks_msec() + 180
		discovery_overlay = null
		discovery_canvas.queue_free()
	)

func _show_merge_success(result: Dictionary, is_fusion: bool) -> void:
	if result.is_empty() or not result.has("animal"):
		return
	var creature: Dictionary = result.animal
	var rarity_mark := " ✨" if creature.rarity == "rare" else ""
	var action := "FUSION" if is_fusion else "MERGE"
	_toast("🎉 %s SUCCESS: %s · TIER %d%s" % [action, Game.display_name(creature), creature.tier, rarity_mark], 3.5)

func _toast(text: String, duration: float = 2.0) -> void:
	toast_queue.append({"text": text, "duration": duration})
	if not toast_running:
		_play_next_toast()

func _play_next_toast() -> void:
	if toast_queue.is_empty():
		toast_running = false
		toast_elapsed = 0.0
		toast_panel.visible = false
		return
	toast_running = true
	var message: Dictionary = toast_queue.pop_front()
	var text: String = str(message.text)
	var duration: float = float(message.duration)
	toast_label.text = text
	toast_panel.visible = true
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.size.y = toast_panel.size.y
	toast_label.position = Vector2(toast_panel.size.x, 0)
	var font := toast_label.get_theme_font("font")
	var font_size := toast_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	toast_label.size.x = maxf(text_width + 48.0, toast_panel.size.x)
	var travel_time := maxf(duration, 5.0)
	toast_elapsed = travel_time
	toast_tween = toast_label.create_tween()
	toast_tween.tween_property(toast_label, "position:x", -toast_label.size.x, travel_time)
	toast_tween.finished.connect(_play_next_toast)
