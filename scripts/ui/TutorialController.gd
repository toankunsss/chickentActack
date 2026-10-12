class_name TutorialController
extends CanvasLayer

signal bootstrap_egg_requested
signal tutorial_closed

const STEP_IDS := ["welcome", "open_shop", "select_chickens", "acquire_pair", "return_farm", "merge", "hatch", "collection"]
const COPY := {
	"welcome": ["WELCOME, FARMER!", "Gold buys chickens and upgrades. Gems unlock special eggs. Energy starts battles and is refilled through optional ads."],
	"open_shop": ["VISIT THE MARKET", "Tap the highlighted SHOP button at the bottom-right."],
	"select_chickens": ["CHOOSE CHICKENS", "Tap the highlighted CHICKENS tab at the top of the Shop."],
	"acquire_pair": ["BUILD A PAIR", "Tap the highlighted BUY button twice to get two matching Tier 1 chickens."],
	"return_farm": ["BACK TO THE FARM", "Tap the highlighted FARM button at the bottom-left."],
	"merge": ["MERGE YOUR CHICKENS", "Drag one highlighted matching chicken directly onto the other."],
	"hatch": ["HATCH A UFO EGG", "Tap the highlighted egg once to hatch your new chicken."],
	"collection": ["CHECK YOUR COLLECTION", "Tap the highlighted COLLECTION button at the bottom."],
}

@onready var root: Control = $Root
@onready var blockers: Array[ColorRect] = [$Root/BlockTop, $Root/BlockLeft, $Root/BlockRight, $Root/BlockBottom]
@onready var spotlight: Panel = $Root/Spotlight
@onready var callout: Panel = $Root/Callout
@onready var step_label: Label = $Root/Callout/Step
@onready var title_label: Label = $Root/Callout/Title
@onready var body_label: Label = $Root/Callout/Body
@onready var next_button: Button = $Root/Callout/Next
@onready var skip_button: Button = $Root/Callout/Skip

var app: Control
var target: Control
var current_step := "welcome"
var replay_mode := false
var completion_prompt := false
var input_guard_until := 0
var _last_target_rect := Rect2()
var pointer: Label
var pointer_base := Vector2.ZERO
var pointer_time := 0.0

func _ready() -> void:
	visible = false
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	get_viewport().size_changed.connect(_layout)
	_style()
	pointer = Label.new()
	pointer.text = "▼"
	pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.size = Vector2(56, 56)
	pointer.add_theme_font_size_override("font_size", 42)
	pointer.add_theme_color_override("font_color", Color("ffd84d"))
	pointer.add_theme_color_override("font_outline_color", Color("6b351c"))
	pointer.add_theme_constant_override("outline_size", 6)
	root.add_child(pointer)

func setup(owner_app: Control) -> void:
	app = owner_app
	root.theme = owner_app.theme
	var game := _game()
	if game != null and game.has_method("is_tutorial_active") and game.is_tutorial_active():
		show_from_state(false)

func show_from_state(is_replay: bool) -> void:
	replay_mode = is_replay
	completion_prompt = false
	current_step = "welcome" if is_replay else _game_step()
	if not STEP_IDS.has(current_step):
		current_step = "welcome"
	visible = true
	_route_resume_screen()
	_show_step()
	var game := _game()
	if not is_replay and current_step == "collection" and game != null and bool(game.tutorial_snapshot().get("collection_ready", false)):
		_show_completion()

func replay() -> void:
	if visible:
		return
	show_from_state(true)

func accept_event(event_id: String, payload: Dictionary = {}) -> void:
	if not visible or completion_prompt or not _event_matches_step(event_id):
		return
	if payload.has("success") and not bool(payload.success):
		return
	var game := _game()
	if not replay_mode and game != null and game.has_method("accept_tutorial_event"):
		game.accept_tutorial_event(event_id, payload)
	if current_step == "collection" and event_id == "screen_collection":
		_show_completion()
		return
	_advance_local()

func blocks_farm_input(position: Vector2) -> bool:
	if not visible:
		return false
	if Time.get_ticks_msec() < input_guard_until:
		return true
	if current_step != "merge":
		return true
	return not _spotlight_rect().has_point(position)

func is_open() -> bool:
	return visible

func set_target(control: Control) -> void:
	target = control
	_layout()

func _process(delta: float) -> void:
	if not visible:
		return
	pointer_time += delta
	var resolved := _resolve_target()
	if resolved != target:
		target = resolved
	var rect := _spotlight_rect()
	if rect != _last_target_rect:
		_layout()
	if pointer.visible:
		pointer.position = pointer_base + Vector2(0, sin(pointer_time * 7.0) * 6.0)

func _game_step() -> String:
	var game := _game()
	if game != null and game.has_method("tutorial_step_id"):
		return str(game.tutorial_step_id())
	return "welcome"

func _game() -> Node:
	return get_node_or_null("/root/Game")

func _event_matches_step(event_id: String) -> bool:
	var expected := {
		"welcome": "ack_welcome", "open_shop": "screen_shop",
		"select_chickens": "tab_chickens", "acquire_pair": "pair_ready",
		"return_farm": "screen_farm", "merge": "merge_succeeded",
		"hatch": "egg_hatched", "collection": "screen_collection",
	}
	return event_id == expected.get(current_step, "")

func _advance_local() -> void:
	var index := STEP_IDS.find(current_step)
	if index < 0 or index + 1 >= STEP_IDS.size():
		return
	current_step = STEP_IDS[index + 1]
	input_guard_until = Time.get_ticks_msec() + 180
	_route_resume_screen()
	_show_step()

func _show_step() -> void:
	completion_prompt = false
	var copy: Array = COPY[current_step]
	step_label.text = "%d / %d" % [STEP_IDS.find(current_step) + 1, STEP_IDS.size()]
	title_label.text = copy[0]
	body_label.text = copy[1]
	next_button.text = "NEXT" if replay_mode else "START"
	next_button.visible = replay_mode or current_step == "welcome"
	skip_button.visible = true
	target = _resolve_target()
	if app != null:
		if current_step == "open_shop" and str(app.get("current_screen")) == "shop":
			call_deferred("accept_event", "screen_shop")
		elif current_step == "return_farm" and str(app.get("current_screen")) == "farm":
			call_deferred("accept_event", "screen_farm")
		elif current_step == "collection" and str(app.get("current_screen")) == "mutations":
			call_deferred("accept_event", "screen_collection")
	if not replay_mode and current_step == "acquire_pair" and app != null and app.has_method("tutorial_has_merge_pair") and app.tutorial_has_merge_pair():
		call_deferred("accept_event", "pair_ready", {"success": true})
	if current_step == "hatch" and not replay_mode and target == null:
		bootstrap_egg_requested.emit()
	_layout()

func _route_resume_screen() -> void:
	if app == null or not app.has_method("_show_screen"):
		return
	if replay_mode and current_step in ["welcome", "open_shop", "collection"]:
		app.call("_show_screen", "farm")
	elif current_step in ["select_chickens", "acquire_pair"]:
		app.call("_show_screen", "shop")
	elif current_step in ["merge", "hatch"]:
		app.call("_show_screen", "farm")

func _resolve_target() -> Control:
	if app == null or not is_instance_valid(app):
		return null
	match current_step:
		"open_shop": return app.get_node_or_null("UI/BottomMenu/BottomNav/Shop") as Control
		"select_chickens": return app.get_node_or_null("UI/ContentViewport/ShopScreen/MarketShop/Tabs/Chickens") as Control
		"acquire_pair":
			if app.has_method("tutorial_pair_buy_button"):
				return app.tutorial_pair_buy_button()
		"return_farm": return app.get_node_or_null("UI/BottomMenu/BottomNav/Farm") as Control
		"merge":
			if app.has_method("tutorial_merge_target"):
				return app.tutorial_merge_target()
		"hatch":
			if app.has_method("tutorial_egg_target"):
				return app.tutorial_egg_target()
		"collection": return app.get_node_or_null("UI/BottomMenu/BottomNav/Collection") as Control
	return null

func _spotlight_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree() or completion_prompt or current_step == "welcome":
		return Rect2(Vector2.ZERO, viewport_size)
	var rect := target.get_global_rect().grow(10.0)
	if current_step == "merge" and app != null and app.has_method("tutorial_merge_rect"):
		var merge_rect: Rect2 = app.tutorial_merge_rect()
		if merge_rect.size != Vector2.ZERO:
			rect = merge_rect.grow(18.0)
	return rect.intersection(Rect2(Vector2.ZERO, viewport_size))

func _show_completion() -> void:
	completion_prompt = true
	target = null
	title_label.text = "YOU'RE READY!"
	body_label.text = "Keep merging, hatching and discovering mutations. Your farm adventure starts now."
	next_button.text = "FINISH"
	next_button.visible = true
	_layout()

func _layout() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	# Root is PRESET_FULL_RECT in the scene, so its anchors already follow the
	# viewport. Assigning size directly here made Godot overwrite it after
	# _ready() and emitted an anchor warning on every screen-size change.
	var hole := _spotlight_rect()
	_last_target_rect = hole
	var no_hole := target == null or completion_prompt or current_step == "welcome"
	spotlight.visible = not no_hole
	pointer.visible = not no_hole
	spotlight.position = hole.position
	spotlight.size = hole.size
	if not no_hole:
		var point_above := hole.position.y >= 70.0
		pointer.text = "▼" if point_above else "▲"
		var pointer_y := hole.position.y - 58.0 if point_above else hole.end.y + 4.0
		pointer_base = Vector2(clampf(hole.get_center().x - 28.0, 4.0, viewport_size.x - 60.0), pointer_y)
		pointer.position = pointer_base
	if no_hole:
		blockers[0].position = Vector2.ZERO
		blockers[0].size = viewport_size
		for i in range(1, blockers.size()): blockers[i].size = Vector2.ZERO
	else:
		blockers[0].position = Vector2.ZERO
		blockers[0].size = Vector2(viewport_size.x, maxf(0.0, hole.position.y))
		blockers[1].position = Vector2(0.0, hole.position.y)
		blockers[1].size = Vector2(maxf(0.0, hole.position.x), hole.size.y)
		blockers[2].position = Vector2(hole.end.x, hole.position.y)
		blockers[2].size = Vector2(maxf(0.0, viewport_size.x - hole.end.x), hole.size.y)
		blockers[3].position = Vector2(0.0, hole.end.y)
		blockers[3].size = Vector2(viewport_size.x, maxf(0.0, viewport_size.y - hole.end.y))
	var margin := 12.0
	var width := minf(560.0, viewport_size.x - margin * 2.0)
	var height := 196.0
	callout.size = Vector2(width, height)
	var x := clampf(hole.get_center().x - width * 0.5, margin, viewport_size.x - width - margin)
	var below := hole.end.y + 14.0
	var y := below if below + height <= viewport_size.y - margin else hole.position.y - height - 14.0
	if no_hole or y < margin:
		y = clampf((viewport_size.y - height) * 0.5, margin, maxf(margin, viewport_size.y - height - margin))
	callout.position = Vector2(x, y)
	for node in [title_label, body_label]:
		node.size.x = width - 40.0
	next_button.position.x = width - 240.0

func _on_next_pressed() -> void:
	if completion_prompt:
		if not replay_mode:
			var game := _game()
			if game != null and game.has_method("accept_tutorial_event"):
				game.accept_tutorial_event("ack_complete", {})
		_close()
	elif replay_mode:
		if current_step == "collection":
			_show_completion()
		else:
			_advance_local()
	elif current_step == "welcome":
		accept_event("ack_welcome")

func _on_skip_pressed() -> void:
	var game := _game()
	if not replay_mode and game != null and game.has_method("skip_tutorial"):
		game.skip_tutorial()
	_close()

func _close() -> void:
	visible = false
	input_guard_until = Time.get_ticks_msec() + 200
	tutorial_closed.emit()

func _style() -> void:
	var callout_style := StyleBoxFlat.new()
	callout_style.bg_color = Color("fff4d2")
	callout_style.border_color = Color("4e3428")
	callout_style.set_border_width_all(4)
	callout_style.set_corner_radius_all(18)
	callout.add_theme_stylebox_override("panel", callout_style)
	var spotlight_style := StyleBoxFlat.new()
	spotlight_style.bg_color = Color.TRANSPARENT
	spotlight_style.border_color = Color("ffd34e")
	spotlight_style.set_border_width_all(5)
	spotlight_style.set_corner_radius_all(14)
	spotlight.add_theme_stylebox_override("panel", spotlight_style)
	_style_button(skip_button, Color("c99a70"), Color("6b3d25"))
	_style_button(next_button, Color("83d253"), Color("315b25"))

func _style_button(button: Button, fill: Color, border: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill.lightened(0.12) if state == "hover" else (fill.darkened(0.12) if state == "pressed" else fill)
		if state == "disabled": box.bg_color = Color("b9b2a3")
		box.border_color = border
		box.set_border_width_all(3)
		box.border_width_bottom = 6
		box.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("fff7df"))
	button.add_theme_color_override("font_outline_color", border)
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_font_size_override("font_size", 20)
