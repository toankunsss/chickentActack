class_name BattleArenaScreen
extends Control

signal exit_requested
signal battle_finished
const SIM = preload("res://scripts/battle/BattleSimulation.gd")
const VFX = preload("res://scripts/battle/BattleSkillVFX.gd")
const INTRO = preload("res://scripts/battle/BattleCountdown.gd")
const RESULT = preload("res://scenes/battle/BattleResultPopup.tscn")
const OFFLINE = preload("res://scripts/battle/OfflineOpponent.gd")
const SKIN = preload("res://scripts/battle/BattleUI.gd")
const BATTLE_FRAME = preload("res://assets/ui/battle_simple/farm-battle-frame.png")
const TILE_SHEET = preload("res://assets/ui/battle_simple/farm-battle-tiles.png")
const ROWS := SIM.ROWS
const COLUMNS := SIM.COLUMNS
const MATCH_DURATION := SIM.DURATION
@onready var timer_label: Label = $Header/Timer
@onready var player_hearts_label: Label = $Header/PlayerHearts
@onready var enemy_hearts_label: Label = $Header/EnemyHearts
@onready var territory_label: Label = $Header/Territory
@onready var opponent_label: Label = $Header/Opponent
@onready var grid: GridContainer = $Board/Grid
@onready var message_label: Label = $Message
@onready var leave_button: Button = $Leave
var simulation := SIM.new()
var cells: Array[Control] = []
var cell_styles: Dictionary = {}
var tile_textures: Array[Texture2D] = []
var views: Dictionary = {}
var effects: Control
var running := false
var reward_granted := false
var reward_pending := false
var selected_uid := ""
var last_cast := ""
var speed := 1.0
var speed_button: Button
var rematch_button: Button
var current_snapshot: Dictionary = {}
var countdown := 0.0
var intro: Control
var result_popup: CanvasLayer
var preparing := false
var pending_sheets: Array[String] = []
var loaded_sheets: Dictionary = {}
var loading_requests: Dictionary = {}
var prepare_started := 0
var paused := false
var leave_confirm_until := 0
var content_height_cache := 1040.0
var energy_committed := false
var render_delta := 1.0 / 60.0
var visual_clock := 0.0
var retired: Array[Dictionary] = []
var battle_frame: TextureRect

func _ready() -> void:
	leave_button.pressed.connect(_leave)
	_build_board()
	effects = VFX.new()
	effects.set_process(false)
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.clip_contents = true
	$Board.add_child(effects)
	effects.z_index = 20
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro = INTRO.new()
	$Board.add_child(intro)
	intro.z_index = 30
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_popup = RESULT.instantiate()
	add_child(result_popup)
	result_popup.rematch_button.text = "REMATCH · %d ENERGY" % Game.PlayProgress.BATTLE_COST
	result_popup.leave_requested.connect(_leave)
	result_popup.rematch_requested.connect(func(): start_snapshot(current_snapshot))
	result_popup.retry_reward_requested.connect(_finish_match)
	speed_button = Button.new()
	speed_button.text = "x1"
	speed_button.position = Vector2(450, 0)
	speed_button.size = Vector2(100, 88)
	speed_button.pressed.connect(func():
		speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
		speed_button.text = "x%d" % int(speed))
	add_child(speed_button)
	rematch_button = Button.new()
	rematch_button.text = "REMATCH\n%d ENERGY" % Game.PlayProgress.BATTLE_COST
	rematch_button.size = Vector2(182, 88)
	rematch_button.hide()
	rematch_button.pressed.connect(func(): start_snapshot(current_snapshot))
	add_child(rematch_button)
	SKIN.button(speed_button, Color("d5eafa"))
	SKIN.button(rematch_button, Color("83c844"))
	SKIN.button(leave_button, Color("cfab85"))
	leave_button.add_theme_font_size_override("font_size", 18)
	player_hearts_label.text = "YOUR TEAM"
	enemy_hearts_label.text = "AI TEAM"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 20)
	_style_arena()
	_install_battle_art()
	visible = false

func _atlas(source: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas

func _texture_layer(parent: Control, texture: Texture2D, behind := true) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.show_behind_parent = behind
	parent.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art

func _install_battle_art() -> void:
	battle_frame = _texture_layer($Board, BATTLE_FRAME, false)
	battle_frame.name = "SimpleFarmBattleFrame"
	battle_frame.z_index = 5
	_style_button(message_label, Color("f5bd39"), Color("8c571f"))
	_style_button(leave_button, Color("a86d4d"), Color("5d3426"))
	_style_button(speed_button, Color("9cb8c9"), Color("445869"))
	message_label.add_theme_color_override("font_color", Color("54351f"))
	leave_button.add_theme_color_override("font_color", Color("fff7df"))
	speed_button.add_theme_color_override("font_color", Color("ffffff"))
	for control in [message_label, leave_button, speed_button]:
		control.add_theme_font_override("font", SKIN.FONT)
		control.add_theme_color_override("font_outline_color", Color("4d2f22"))
		control.add_theme_constant_override("outline_size", 2)

func _style_button(control: Control, fill: Color, border: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill.lightened(0.08) if state == "hover" else (fill.darkened(0.10) if state == "pressed" else fill)
		if state == "disabled": box.bg_color = Color("b8b0a3")
		box.border_color = border
		box.set_border_width_all(3)
		box.border_width_top = 5
		box.set_corner_radius_all(15)
		box.shadow_color = Color(0.20, 0.10, 0.04, 0.28)
		box.shadow_size = 4
		box.shadow_offset = Vector2(0, 4 if state != "pressed" else 2)
		box.content_margin_top = 6
		control.add_theme_stylebox_override(state, box)

func _style_arena() -> void:
	$Background.color = Color("fff5d7")
	for entry in [["Header", "dbe59d", "8a6235"], ["Board", "eff7be", "8faf42"]]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(entry[1])
		box.border_color = Color(entry[2])
		box.set_border_width_all(4)
		box.set_corner_radius_all(18)
		box.shadow_color = Color(0.16, 0.10, 0.05, 0.22)
		box.shadow_size = 7
		box.shadow_offset = Vector2(0, 3)
		get_node(entry[0]).add_theme_stylebox_override("panel", box)
	for label in [player_hearts_label, enemy_hearts_label]:
		label.add_theme_font_override("font", SKIN.FONT)
		label.add_theme_font_size_override("font_size", 22)
	player_hearts_label.add_theme_color_override("font_color", Color("287348"))
	enemy_hearts_label.add_theme_color_override("font_color", Color("a7443a"))
	opponent_label.add_theme_font_override("font", SKIN.FONT)
	territory_label.add_theme_font_override("font", SKIN.FONT)
	opponent_label.add_theme_color_override("font_color", Color("604226"))
	territory_label.add_theme_color_override("font_color", Color("604226"))
	opponent_label.add_theme_color_override("font_outline_color", Color("fff6d8"))
	territory_label.add_theme_color_override("font_outline_color", Color("fff6d8"))
	opponent_label.add_theme_constant_override("outline_size", 2)
	territory_label.add_theme_constant_override("outline_size", 2)
	message_label.add_theme_font_override("font", SKIN.FONT)
	var message_box := StyleBoxFlat.new()
	message_box.bg_color = Color("ffe08a")
	message_box.border_color = Color("a96c2f")
	message_box.set_border_width_all(3)
	message_box.set_corner_radius_all(16)
	message_box.shadow_color = Color(0.25, 0.13, 0.04, 0.18)
	message_box.shadow_size = 5
	message_label.add_theme_stylebox_override("normal", message_box)
	timer_label.add_theme_font_override("font", preload("res://assets/Hyper_Casual_UI/Fonts/Baloo2-ExtraBold.ttf"))
	timer_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	timer_label.add_theme_color_override("font_color", Color("fff3a1"))
	timer_label.add_theme_color_override("font_outline_color", Color("5d361c"))
	timer_label.add_theme_constant_override("outline_size", 4)

func apply_responsive_height(content_height: float) -> void:
	content_height_cache = content_height
	var width := size.x
	var header := $Header as Control
	header.size.x = width - 16.0
	player_hearts_label.size.x = (header.size.x - 110.0) * 0.5
	enemy_hearts_label.position.x = header.size.x * 0.5 + 55.0
	enemy_hearts_label.size.x = header.size.x * 0.5 - 69.0
	timer_label.position.x = (header.size.x - timer_label.size.x) * 0.5
	opponent_label.size.x = header.size.x - 28.0
	territory_label.size.x = header.size.x - 28.0
	var board := $Board as Control
	board.size.x = width - 16.0
	board.offset_bottom = content_height - 210.0
	message_label.size.x = width - 16.0
	message_label.position.y = content_height - 198.0
	message_label.size.y = 88.0
	leave_button.position = Vector2(20, content_height - 100.0)
	leave_button.size = Vector2(220, 88)
	if rematch_button: rematch_button.position = Vector2((width - rematch_button.size.x) * 0.5, content_height - 100.0)
	if speed_button: speed_button.position = Vector2(width - 120.0, content_height - 100.0)
	grid.position.x = 36.0
	grid.position.y = 24.0
	grid.size.x = board.size.x - 72.0
	grid.offset_bottom = board.size.y - 24.0
	var rows := simulation.board_rows
	var cell_height := maxf(30.0, floorf((board.size.y - 48.0 - (rows - 1) * 2.0) / float(rows)))
	var cell_width := floorf((grid.size.x - (COLUMNS - 1) * 4.0) / COLUMNS)
	for cell in cells: cell.custom_minimum_size = Vector2(cell_width, cell_height)

func start_match(opponent_name: String, opponent_power: int, match_seed: int = -1) -> void:
	# Compatibility entry point for DEV and older scene hooks; still a local AI match.
	var snapshot := OFFLINE.build(Game, 1, Time.get_ticks_usec() if match_seed < 0 else match_seed)
	snapshot.opponent = "AI · " + opponent_name
	snapshot.opponent_power = opponent_power
	start_snapshot(snapshot)

func start_snapshot(snapshot: Dictionary) -> void:
	if running or reward_pending: return
	if Game.energy_balance() < Game.PlayProgress.BATTLE_COST:
		result_popup.hide()
		message_label.text = "Need %d Energy · Refill from an optional ad" % Game.PlayProgress.BATTLE_COST
		leave_button.text = "BACK TO TEAM"
		return
	energy_committed = false
	result_popup.hide()
	current_snapshot = snapshot.duplicate(true)
	opponent_label.text = "%s · %s" % [snapshot.opponent, snapshot.difficulty]
	simulation.setup(snapshot.players, snapshot.enemies, int(snapshot.seed))
	if cells.size() != simulation.board_rows * COLUMNS:
		_build_board()
	apply_responsive_height(content_height_cache)
	running = simulation.running
	reward_granted = false
	countdown = INTRO.DURATION if running else 0.0
	paused = false
	leave_confirm_until = 0
	rematch_button.hide()
	speed = 1.0
	speed_button.text = "x1"
	selected_uid = ""
	last_cast = "AUTO SKILLS · Tap a chicken to inspect its move"
	leave_button.text = "LEAVE"
	speed_button.disabled = true
	_clear_views()
	effects.clear()
	_begin_preparation()
	if not running:
		last_cast = "Select a valid team before starting a battle."
		message_label.text = last_cast
	_refresh()
	if running: intro.show_time(0.0, preparing)
	else: intro.hide()

func _begin_preparation() -> void:
	pending_sheets.clear()
	prepare_started = Time.get_ticks_msec()
	for unit in simulation.units:
		for action in ["bounce", "attack", "hit"]:
			var path := "%s/animations/%03d/%s.png" % [Game.CHICKEN_ASSET_ROOT, Game.creature_asset_id(unit.animal), action]
			if loaded_sheets.has(path) or pending_sheets.has(path): continue
			if not loading_requests.has(path):
				if ResourceLoader.load_threaded_request(path, "Texture2D") != OK:
					_preparation_failed()
					return
				loading_requests[path] = true
			pending_sheets.append(path)
	preparing = not pending_sheets.is_empty()

func _poll_preparation() -> void:
	var retrieved := 0
	for path in pending_sheets.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Never get a resource still loading: that would block the render thread.
			loaded_sheets[path] = ResourceLoader.load_threaded_get(path)
			loading_requests.erase(path)
			pending_sheets.erase(path)
			retrieved += 1
			if retrieved >= 2: break
		elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			loading_requests.erase(path)
			_preparation_failed()
			return
	if Time.get_ticks_msec() - prepare_started > 30000:
		_preparation_failed()
		return
	preparing = not pending_sheets.is_empty()

func _preparation_failed() -> void:
	abandon_match()
	last_cast = "Could not prepare battle assets. Please retry."
	message_label.text = last_cast
	rematch_button.show()
	leave_button.text = "BACK TO TEAM"

func _process(delta: float) -> void:
	if not is_visible_in_tree() or paused: return
	render_delta = minf(delta, 0.05) * speed
	visual_clock += render_delta
	effects._process(delta * speed)
	for ghost in retired.duplicate():
		ghost.age += delta
		if ghost.age >= 0.24:
			ghost.root.queue_free()
			retired.erase(ghost)
		else:
			ghost.root.modulate.a = 1.0 - ghost.age / 0.24
			ghost.root.position.y -= delta * 28.0
	if leave_confirm_until > 0 and Time.get_ticks_msec() >= leave_confirm_until:
		leave_confirm_until = 0
		leave_button.text = "LEAVE"
	if preparing:
		_poll_preparation()
		_refresh()
		if running: intro.show_time(0.0, preparing)
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		_refresh()
		intro.show_time(INTRO.DURATION - countdown)
		message_label.text = "Skills cast automatically when enemies are in range"
		if countdown <= 0.0:
			intro.hide()
			speed_button.disabled = false
		return
	if running and not paused:
		if not energy_committed:
			var payment := Game.spend_battle_energy()
			if not payment.ok:
				abandon_match()
				message_label.text = "Could not start: %s. No energy spent." % str(payment.reason).replace("_", " ")
				leave_button.text = "BACK TO TEAM"
				return
			energy_committed = true
		simulation.advance(delta * speed)
		for event in simulation.drain_events():
			var points: Array[Vector2] = []
			for point in event.to: points.append(_visual_center(point))
			effects.play(event, _visual_center(event.from), points)
			if event.type == "cast": Audio.play_skill(str(event.skill.get("visual", "energy")))
			elif event.type == "heal": Audio.play_skill("leaf")
			if event.type == "cast": last_cast = "%s · %s" % ["YOUR SKILL" if event.side == 1 else "ENEMY SKILL", event.skill.name]
		if not simulation.running: _finish_match()
	_refresh()

func _build_board() -> void:
	for child in grid.get_children(): child.free()
	cells.clear()
	tile_textures = [
		_atlas(TILE_SHEET, Rect2(60, 60, 675, 420)),
		_atlas(TILE_SHEET, Rect2(805, 60, 675, 420)),
		_atlas(TILE_SHEET, Rect2(60, 550, 675, 420)),
		_atlas(TILE_SHEET, Rect2(805, 550, 675, 420)),
	]
	cell_styles = {
		"enemy": _cell_style(Color("f9d7c5")), "enemy_owned": _cell_style(Color("f3b7a5")),
		"player": _cell_style(Color("d8edca")), "player_owned": _cell_style(Color("aee1b5")),
		"center": _cell_style(Color("ffe5a5"), true), "center_player": _cell_style(Color("aee1b5"), true),
		"center_enemy": _cell_style(Color("f3b7a5"), true),
	}
	for row in simulation.board_rows:
		for column in COLUMNS:
			var cell := TextureRect.new()
			cell.custom_minimum_size = Vector2(180, 54)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.texture = tile_textures[2] if row == simulation.board_rows / 2 else tile_textures[(row + column) % 2]
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_SCALE
			grid.add_child(cell)
			cells.append(cell)

func _idle_cell_color(row: int) -> Color:
	if row < simulation.board_rows / 2: return Color("f9d7c5")
	if row > simulation.board_rows / 2: return Color("d8edca")
	return Color("ffe5a5")

func _style_for_cell(row: int, owner: int) -> StyleBoxFlat:
	if row == simulation.board_rows / 2:
		return cell_styles["center_player" if owner == 1 else ("center_enemy" if owner == -1 else "center")]
	if row < simulation.board_rows / 2:
		return cell_styles["player_owned" if owner == 1 else ("enemy_owned" if owner == -1 else "enemy")]
	return cell_styles["player_owned" if owner == 1 else ("enemy_owned" if owner == -1 else "player")]

func _cell_style(fill: Color, center_lane := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("d5b77b") if center_lane else fill.darkened(0.18)
	style.set_border_width_all(2)
	if center_lane:
		style.border_width_top = 3
		style.border_width_bottom = 3
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.22, 0.14, 0.07, 0.12)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style

func _cell_center(point: Vector2) -> Vector2:
	var cell := cells[clampi(int(point.y) * COLUMNS + int(point.x), 0, cells.size() - 1)]
	return cell.position + grid.position + cell.size * 0.5

func _visual_center(point: Vector2) -> Vector2:
	for unit in simulation.units:
		if unit.column == int(point.x) and unit.row == int(point.y) and views.has(unit.uid):
			var holder: Control = views[unit.uid].root
			return holder.position + holder.size * 0.5
	return _cell_center(point)

func _clear_views() -> void:
	for view in views.values(): view.root.free()
	views.clear()
	for ghost in retired: if is_instance_valid(ghost.root): ghost.root.queue_free()
	retired.clear()

func _make_view(unit: Dictionary) -> Dictionary:
	var holder := Button.new()
	holder.z_index = 10
	holder.flat = true
	holder.text = ""
	holder.pressed.connect(func(): selected_uid = unit.uid)
	holder.tooltip_text = "%s\n%s\n%s" % [Game.display_name(unit.animal), unit.skill.name, unit.skill.description]
	$Board.add_child(holder)
	var shadow := preload("res://scripts/battle/BattleUnitShadow.gd").new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.friendly = unit.side == 1
	holder.add_child(shadow)
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(image)
	var hp := _bar(holder, Color("68bd56") if unit.side == 1 else Color("ee7865"))
	var cooldown := _bar(holder, Color("70cce9"))
	var status := Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_override("font", SKIN.FONT)
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("ffffff"))
	var status_box := StyleBoxFlat.new()
	status_box.bg_color = Color("664339d9")
	status_box.set_corner_radius_all(8)
	status.add_theme_stylebox_override("normal", status_box)
	holder.add_child(status)
	var damage := Label.new()
	damage.add_theme_font_override("font", SKIN.FONT)
	damage.add_theme_font_size_override("font_size", 22)
	damage.add_theme_color_override("font_color", Color("ffefbd"))
	damage.add_theme_color_override("font_outline_color", Color("6c3026"))
	damage.add_theme_constant_override("outline_size", 4)
	damage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(damage)
	$Board.move_child(effects, -1)
	$Board.move_child(intro, -1)
	return {"root": holder, "image": image, "hp": hp, "cooldown": cooldown, "status": status,
		"shadow": shadow, "spawned": false, "last_hp": float(unit.hp), "hit": 0.0, "damage": damage,
		"action": "bounce", "action_left": 0.0, "last_anim": 0.0}

func _bar(parent: Control, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for name in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color if name == "fill" else Color("5d4a3c")
		if name == "background":
			style.border_color = Color("fff4df")
			style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(name, style)
	parent.add_child(bar)
	return bar

func _refresh() -> void:
	timer_label.text = "%02d" % ceili(simulation.remaining)
	player_hearts_label.text = "YOU · %d ALIVE" % simulation.units.filter(func(unit): return unit.side == 1).size()
	enemy_hearts_label.text = "AI · %d ALIVE" % simulation.units.filter(func(unit): return unit.side == -1).size()
	territory_label.text = "AUTO BATTLE · TAP A CHICKEN TO SEE ITS SKILL"
	for index in mini(cells.size(), simulation.territory.size()):
		var row := int(index / COLUMNS)
		var owner := int(simulation.territory[index])
		cells[index].modulate = Color("d5efff") if owner == 1 else (Color("ffd8d0") if owner == -1 else Color.WHITE)
	var alive: Dictionary = {}
	for unit in simulation.units:
		alive[unit.uid] = true
		if not views.has(unit.uid): views[unit.uid] = _make_view(unit)
		var view: Dictionary = views[unit.uid]
		var cell := cells[int(unit.row) * COLUMNS + int(unit.column)]
		var height := cell.size.y
		var destination := _cell_center(Vector2(unit.column, unit.row)) - Vector2(65, height * 0.5)
		view.root.position = destination if not view.spawned else view.root.position.lerp(destination, 1.0 - exp(-render_delta * 16.0))
		view.root.size = Vector2(130, height)
		view.shadow.position = Vector2(28, height - 29)
		view.shadow.size = Vector2(74, 20)
		view.shadow.selected = unit.uid == selected_uid
		view.shadow.queue_redraw()
		if float(unit.animation_time) > float(view.last_anim) + 0.02 or str(unit.animation) != view.action:
			view.action = str(unit.animation)
			view.action_left = float(unit.animation_time)
		view.last_anim = float(unit.animation_time)
		view.action_left = maxf(0, float(view.action_left) - render_delta)
		var moving: bool = view.root.position.distance_to(destination) > 1.5
		var bob := sin(visual_clock * (12.0 if moving else 3.5) + float(unit.column)) * (3.5 if moving else 1.0)
		var attack_kick := sin(clampf((0.45 - float(view.action_left)) / 0.45, 0, 1) * PI) * 7.0 if view.action == "attack" and view.action_left > 0 else 0.0
		view.image.position = Vector2(24, -3 + bob - attack_kick * unit.side)
		view.image.size = Vector2(82, maxf(24, height - 8))
		view.image.pivot_offset = view.image.size * 0.5
		view.image.rotation = sin(visual_clock * 12) * 0.045 if moving else 0.0
		var action := str(view.action) if view.action_left > 0 else "bounce"
		var anim_time := int((visual_clock if action == "bounce" else 0.55 - view.action_left) * 1000.0)
		var sheet_path := "%s/animations/%03d/%s.png" % [Game.CHICKEN_ASSET_ROOT, Game.creature_asset_id(unit.animal), action]
		if loaded_sheets.has(sheet_path):
			view.image.texture = Game.creature_animation_texture(unit.animal, action, maxi(0, anim_time))
		view.image.modulate = Game.creature_color(unit.animal)
		if float(unit.hp) < float(view.last_hp):
			view.hit = 0.48
			view.damage.text = "-%d" % ceili(float(view.last_hp) - float(unit.hp))
		view.last_hp = float(unit.hp)
		view.hit = maxf(0, float(view.hit) - render_delta)
		view.damage.visible = view.hit > 0
		view.damage.position = Vector2(0, -12 - (0.48 - float(view.hit)) * 30)
		view.damage.size = Vector2(130, 30)
		view.damage.modulate.a = minf(1, float(view.hit) * 5)
		if view.hit > 0.36: view.image.modulate = Color("ffcfbe")
		view.hp.position = Vector2(17, height - 12)
		view.hp.size = Vector2(96, 6)
		view.hp.max_value = unit.max_hp
		view.hp.value = unit.hp if not view.spawned else lerpf(view.hp.value, unit.hp, 1.0 - exp(-render_delta * 18))
		view.cooldown.position = Vector2(17, height - 5)
		view.cooldown.size = Vector2(96, 4)
		view.cooldown.max_value = unit.skill.cooldown
		var charge := maxf(0.0, float(unit.skill.cooldown) - float(unit.cooldown))
		view.cooldown.value = charge if charge < view.cooldown.value or not view.spawned else lerpf(view.cooldown.value, charge, 1.0 - exp(-render_delta * 18))
		view.spawned = true
		view.status.position = Vector2(18, -7)
		view.status.size = Vector2(94, 25)
		var status_name := str(unit.statuses.keys()[0]) if not unit.statuses.is_empty() else ""
		view.status.text = "SHIELD" if unit.shield > 0.0 else {"burn": "FIRE", "haste": "FAST", "poison": "TOXIN", "weaken": "WEAK"}.get(status_name, status_name.to_upper())
		view.status.visible = not view.status.text.is_empty()
	for uid in views.keys():
		if not alive.has(uid):
			views[uid].root.disabled = true
			retired.append({"root": views[uid].root, "age": 0.0})
			views.erase(uid)
	if running:
		message_label.text = last_cast
		for unit in simulation.units:
			if unit.uid == selected_uid:
				message_label.text = "%s · %s\n%s · %.1fs" % [Game.display_name(unit.animal), unit.skill.name, unit.skill.label, unit.cooldown]
				break

func _finish_match() -> void:
	if reward_granted or simulation.running or simulation.result not in ["victory", "defeat", "draw"]: return
	# An abandoned match or an unpaid preview can never grant a victory prize.
	if simulation.result == "victory" and not energy_committed: return
	running = false
	speed_button.disabled = true
	var reward := 0
	var xp_reward := 0
	if simulation.result == "victory":
		var payout := Game.save_battle_reward(simulation.territory.count(1))
		if not payout.ok:
			reward_pending = true
			rematch_button.hide()
			message_label.text = "VICTORY · Reward pending. Please retry saving."
			var prize: Dictionary = Game.PlayProgress.battle_reward(simulation.territory.count(1))
			result_popup.show_pending_reward(prize.gold, prize.xp, simulation.totals[1])
			return
		reward = payout.gold
		xp_reward = payout.xp
		message_label.text = "VICTORY · +%d GOLD · +%d FARM XP" % [reward, xp_reward]
	else:
		message_label.text = "DRAW · TRY ANOTHER SKILL COMBO" if simulation.result == "draw" else "DEFEAT · TRY A DIFFERENT TEAM"
	reward_pending = false
	reward_granted = true
	Audio.play_sfx("victory" if simulation.result == "victory" else "defeat")
	rematch_button.show()
	message_label.text += "\nYour skills: %d · Damage: %d · KOs: %d" % [simulation.totals[1].casts, roundi(simulation.totals[1].damage), simulation.totals[1].kills]
	leave_button.text = "BACK TO TEAM"
	battle_finished.emit()
	result_popup.show_result(simulation.result, reward, xp_reward, simulation.totals[1])

func abandon_match() -> void:
	if reward_pending: return
	running = false
	energy_committed = false
	simulation.running = false
	countdown = 0.0
	preparing = false
	pending_sheets.clear()
	if is_instance_valid(intro): intro.hide()
	if is_instance_valid(result_popup): result_popup.hide()
	leave_confirm_until = 0
	if is_instance_valid(effects): effects.clear()

func _leave() -> void:
	if reward_pending: return
	if running and Time.get_ticks_msec() > leave_confirm_until:
		leave_confirm_until = Time.get_ticks_msec() + 3000
		leave_button.text = "LEAVE? TAP AGAIN"
		return
	abandon_match()
	exit_requested.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED: paused = false
