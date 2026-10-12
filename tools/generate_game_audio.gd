extends SceneTree
## Original procedural score/SFX. Run once offline; no synthesis during gameplay.
const RATE := 22050
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	rng.seed = 20261004
	DirAccess.make_dir_recursive_absolute("res://assets/audio")
	for mood in ["farm", "battle", "raid"]:
		_music(mood)
	var cues := {
		"click": [79, 84], "open": [67, 72, 76], "close": [76, 72],
		"egg_drop": [60, 48], "hatch": [72, 76, 79, 84],
		"merge": [60, 64, 67, 72], "success": [72, 76, 79, 84, 88],
		"failure": [64, 60, 55], "reward": [79, 84, 88],
		"count": [72], "go": [72, 76, 79, 84],
		"victory": [60, 64, 67, 72, 79, 84], "defeat": [67, 64, 60, 55],
		"warning": [67, 72, 67, 72], "cannon": [48, 36],
		"ice": [96, 91, 103], "fire": [48, 43, 36], "water": [72, 79, 84],
		"lightning": [91, 67, 96], "leaf": [79, 84, 88],
		"rock": [43, 36], "wind": [79, 86], "energy": [72, 84],
	}
	for cue in cues:
		var notes: Array = cues[cue]
		var step := 0.085 if cue in ["click", "close", "ice", "lightning"] else 0.14
		var samples := _buffer(notes.size() * step + 0.28)
		for i in notes.size():
			# Lower octave and softer sine/triangle timbre; no piercing bell partials.
			_note(samples, i * step, 0.25, float(notes[i]) - 12, 0.14, 0)
		if cue in ["cannon", "fire", "rock", "egg_drop", "lightning", "wind"]:
			_noise(samples, 0, 0.22, 0.045)
		_save(cue, samples, false)
	print("GAME_AUDIO_GENERATED: 3 music loops + %d cues" % cues.size())
	quit()

func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(ceili(seconds * RATE))
	return samples

func _note(samples: PackedFloat32Array, start: float, duration: float, midi: float, gain: float, voice: int) -> void:
	var hz := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
	for i in int(duration * RATE):
		var t := float(i) / RATE
		var envelope := minf(t / 0.024, 1.0) * exp(-t * 3.4 / duration) * minf((duration - t) / 0.05, 1.0)
		var tone := sin(TAU * hz * t)
		if voice == 0: tone += 0.10 * sin(TAU * hz * 2 * t)
		if voice == 2: tone += 0.10 * sin(TAU * hz * 1.002 * t)
		var index := (int(start * RATE) + i) % samples.size()
		samples[index] += tone * envelope * gain

func _noise(samples: PackedFloat32Array, start: float, duration: float, gain: float) -> void:
	var smooth := 0.0
	for i in int(duration * RATE):
		var t := float(i) / RATE
		smooth = lerpf(smooth, rng.randf_range(-1, 1), 0.3)
		var envelope := minf(t / 0.006, 1.0) * pow(1.0 - t / duration, 3)
		samples[(int(start * RATE) + i) % samples.size()] += smooth * envelope * gain

func _music(mood: String) -> void:
	var bpm := 84.0 if mood == "farm" else (108.0 if mood == "battle" else 116.0)
	var beat := 60.0 / bpm
	var samples := _buffer(32 * beat)
	var roots := [48, 53, 55, 48, 57, 53, 55, 48] if mood != "raid" else [45, 45, 41, 43, 45, 41, 43, 45]
	var tune := [0, 4, 7, 12, 7, 4, 2, 7, 4, 7, 12, 16, 12, 7, 4, 2]
	for bar in 8:
		var root_note: int = roots[bar]
		var third := 3 if mood == "raid" else 4
		for b in 4:
			var at := (bar * 4 + b) * beat
			_note(samples, at, beat * 0.8, root_note - 12 if b % 2 == 0 else root_note - 5, 0.12, 1)
			for chord in [0, third, 7]:
				_note(samples, at + beat * 0.5, beat * 0.4, root_note + chord, 0.035, 2)
			if mood != "farm": _noise(samples, at + beat * 0.5, 0.06, 0.025)
			if mood != "farm":
				_note(samples, at, 0.12, 30, 0.13, 1)
				if b % 2 == 1: _noise(samples, at, 0.10, 0.06)
		for n in 8:
			if mood == "farm" and n in [1, 3, 5, 7]: continue
			var interval: int = tune[(bar * 4 + n) % tune.size()]
			if mood == "raid" and interval % 12 == 4: interval -= 1
			_note(samples, (bar * 4 + n * 0.5) * beat, beat * 1.25, root_note + 12 + interval, 0.065, 0)
	_save(mood, samples, true)

func _save(cue: String, samples: PackedFloat32Array, looping: bool) -> void:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size(): pcm.encode_s16(i * 2, int(clampf(samples[i], -0.95, 0.95) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = pcm
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	assert(stream.save_to_wav("res://assets/audio/" + cue + ".wav") == OK)
