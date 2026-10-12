extends Node
## Independent local preferences, bounded SFX voices and cross-faded music.
signal preferences_changed
const PREFS := "user://audio_settings.cfg"
const LANGUAGES := [
	{"code": "en", "name": "English"},
	{"code": "es", "name": "Español"},
	{"code": "pt", "name": "Português"},
	{"code": "fr", "name": "Français"},
	{"code": "de", "name": "Deutsch"},
	{"code": "ja", "name": "日本語"},
	{"code": "ko", "name": "한국어"},
	{"code": "zh", "name": "简体中文"},
]
const CUES := ["click", "open", "close", "egg_drop", "hatch", "merge", "success", "failure", "reward", "count", "go", "victory", "defeat", "warning", "cannon", "ice", "fire", "water", "lightning", "leaf", "rock", "wind", "energy"]
var music_volume := 0.55
var sfx_volume := 0.75
var muted := false
var language := "en"
var save_error := OK
var tracks: Dictionary = {}
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var active_player := 0
var context := ""
var cooldowns: Dictionary = {}
var last_skill := -1000
var fade: Tween
var save_timer: Timer
var suspended := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for cue in CUES: sounds[cue] = load("res://assets/audio/" + cue + ".wav")
	# Stream long music from Vorbis instead of keeping raw PCM WAV playback in
	# Android's AudioTrack.  The x86_64 emulator repeatedly crashed in the native
	# audio thread at the exact end of the farm WAV loop.  Ogg looping is handled
	# by Godot's streaming decoder and is also considerably lighter in memory.
	for mood in ["farm", "battle", "raid"]:
		var stream := load("res://assets/audio/" + mood + "_music.ogg") as AudioStreamOggVorbis
		if stream == null:
			push_error("Missing music stream for %s" % mood)
			continue
		stream.loop = true
		stream.loop_offset = 0.0
		tracks[mood] = stream
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		music_players.append(player)
	# Four bounded voices are enough for this game's short cues and reduce audio
	# mixing pressure on lower-end phones and Android emulators.
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		voices.append(player)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.35
	add_child(save_timer)
	save_timer.timeout.connect(save_preferences)
	load_preferences()
	get_tree().node_added.connect(_watch_button)
	_bind_buttons(get_tree().root)

func _watch_button(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(func(): play_sfx("click"))

func _bind_buttons(node: Node) -> void:
	_watch_button(node)
	for child in node.get_children(): _bind_buttons(child)

func load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS) == OK:
		music_volume = _volume(cfg.get_value("audio", "music", 0.55), 0.55)
		sfx_volume = _volume(cfg.get_value("audio", "sfx", 0.75), 0.75)
		var value: Variant = cfg.get_value("audio", "muted", false)
		muted = value if value is bool else false
		var saved_language := str(cfg.get_value("display", "language", "en"))
		language = saved_language if _valid_language(saved_language) else "en"
	_apply()

func _volume(value: Variant, fallback: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), 0, 1)

func set_volume(bus: String, value: float) -> void:
	if bus == "Music": music_volume = _volume(value, 0.55)
	elif bus == "SFX": sfx_volume = _volume(value, 0.75)
	else: return
	_changed()

func set_muted(value: bool) -> void:
	muted = value
	_changed()

func set_language(value: String) -> void:
	if not _valid_language(value) or language == value: return
	language = value
	_changed()

func _valid_language(value: String) -> bool:
	for entry in LANGUAGES:
		if entry.code == value: return true
	return false

func _changed() -> void:
	_apply()
	save_timer.start()
	preferences_changed.emit()

func _apply() -> void:
	for bus in ["Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		var volume := music_volume if bus == "Music" else sfx_volume
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, muted or volume <= 0.0 or suspended)

func save_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("display", "language", language)
	save_error = cfg.save(PREFS)
	preferences_changed.emit()

func set_context(value: String) -> void:
	if not tracks.has(value) or context == value: return
	context = value
	if fade: fade.kill()
	var old := music_players[active_player]
	active_player = 1 - active_player
	var next := music_players[active_player]
	next.stop()
	next.stream = tracks[value]
	next.volume_db = -45
	next.play()
	next.stream_paused = suspended
	fade = create_tween().set_parallel(true)
	fade.tween_property(old, "volume_db", -45.0, 0.55)
	fade.tween_property(next, "volume_db", -3.0, 0.65)
	fade.chain().tween_callback(old.stop)

func play_sfx(cue: String) -> void:
	if muted or suspended or sfx_volume <= 0 or not sounds.has(cue): return
	var now := Time.get_ticks_msec()
	var interval := 160 if cue in ["cannon", "egg_drop"] else 65
	if now - int(cooldowns.get(cue, -10000)) < interval: return
	cooldowns[cue] = now
	for player in voices:
		if not player.playing:
			player.stream = sounds[cue]
			player.volume_db = -5
			player.play()
			return

func play_skill(motif: String) -> void:
	var now := Time.get_ticks_msec()
	if now - last_skill < 180: return
	last_skill = now
	play_sfx(motif if motif in ["ice", "fire", "water", "lightning", "leaf", "rock", "wind"] else "energy")

func suspend_audio(value: bool) -> void:
	suspended = value
	for player in music_players: player.stream_paused = value
	if value:
		for player in voices: player.stop()
	_apply()

func _notification(what: int) -> void:
	if not is_instance_valid(save_timer): return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		save_preferences()
		suspend_audio(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		suspend_audio(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_preferences()
