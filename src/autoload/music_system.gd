# music_system.gd — Procedural background music autoload.
# Renders a looping synthwave/chiptune battle track at startup
# (square lead, triangle bass, noise drums) and plays it on a
# non-positional AudioStreamPlayer. No audio assets required.
extends Node

const SAMPLE_RATE := 22050
const BPM := 148.0
const STEPS_PER_BAR := 16          # 16th-note grid
const BARS := 8
const TOTAL_STEPS := STEPS_PER_BAR * BARS
const DEFAULT_VOLUME_DB := -14.0

# Chord root per bar (MIDI): Em Em G A | Em Em C D  — driving minor progression.
const BAR_ROOTS: Array[int] = [40, 40, 43, 45, 40, 40, 48, 50]

# Lead riff: 16 steps of semitone offsets from the bar root (-1 = rest).
const LEAD_RIFF: Array[int] = [12, -1, 19, 17, 12, -1, 24, 22, 19, -1, 17, 15, 12, 15, 17, 19]
# Variation riff used on every other bar pair for movement.
const LEAD_RIFF_B: Array[int] = [24, -1, 22, -1, 19, 17, 15, -1, 12, -1, 15, -1, 17, -1, 19, 22]

var _player: AudioStreamPlayer = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = _render_track()
	_player.volume_db = DEFAULT_VOLUME_DB
	_player.autoplay = false
	add_child(_player)
	_player.play()


func set_music_enabled(enabled: bool) -> void:
	if _player == null:
		return
	if enabled and not _player.playing:
		_player.play()
	elif not enabled and _player.playing:
		_player.stop()


func is_music_playing() -> bool:
	return _player != null and _player.playing


func set_music_volume_db(volume_db: float) -> void:
	if _player != null:
		_player.volume_db = volume_db


static func _midi_to_freq(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


static func _render_track() -> AudioStreamWAV:
	var step_dur := 60.0 / BPM / 4.0
	var step_samples := int(SAMPLE_RATE * step_dur)
	var num_samples := step_samples * TOTAL_STEPS

	var mix := PackedFloat32Array()
	mix.resize(num_samples)

	_render_bass(mix, step_samples)
	_render_lead(mix, step_samples)
	_render_drums(mix, step_samples)

	# Convert to 16-bit PCM with soft clipping.
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var sample := tanh(mix[i] * 1.1)
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream


# Triangle-wave bass: pumping octave eighths on the bar root.
static func _render_bass(mix: PackedFloat32Array, step_samples: int) -> void:
	for step in TOTAL_STEPS:
		if step % 2 != 0:
			continue  # eighth notes
		var bar := step / STEPS_PER_BAR
		var root: int = BAR_ROOTS[bar]
		var midi := root if (step % 4 == 0) else root + 12
		var freq := _midi_to_freq(midi)
		var start := step * step_samples
		var length := step_samples * 2
		var phase := 0.0
		for i in length:
			var idx := start + i
			if idx >= mix.size():
				break
			phase += freq / float(SAMPLE_RATE)
			var tri := 4.0 * absf(fposmod(phase, 1.0) - 0.5) - 1.0
			var env := exp(-float(i) / float(SAMPLE_RATE) * 8.0)
			mix[idx] += tri * 0.30 * env


# Detuned square lead playing the riff.
static func _render_lead(mix: PackedFloat32Array, step_samples: int) -> void:
	for step in TOTAL_STEPS:
		var bar := step / STEPS_PER_BAR
		var riff: Array[int] = LEAD_RIFF if (bar % 4) < 2 else LEAD_RIFF_B
		var offset: int = riff[step % STEPS_PER_BAR]
		if offset < 0:
			continue
		var freq := _midi_to_freq(BAR_ROOTS[bar] + offset + 12)
		var start := step * step_samples
		var phase_a := 0.0
		var phase_b := 0.0
		for i in step_samples:
			var idx := start + i
			if idx >= mix.size():
				break
			phase_a += freq / float(SAMPLE_RATE)
			phase_b += freq * 1.005 / float(SAMPLE_RATE)
			var sq_a := 1.0 if fposmod(phase_a, 1.0) < 0.5 else -1.0
			var sq_b := 1.0 if fposmod(phase_b, 1.0) < 0.5 else -1.0
			var t := float(i) / float(SAMPLE_RATE)
			var env := minf(t * 200.0, 1.0) * exp(-t * 14.0)
			mix[idx] += (sq_a + sq_b) * 0.5 * 0.16 * env


# Four-on-the-floor kick, snare on 2 & 4, offbeat hats.
static func _render_drums(mix: PackedFloat32Array, step_samples: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xBEA7
	for step in TOTAL_STEPS:
		var start := step * step_samples
		var pos := step % STEPS_PER_BAR
		if pos % 4 == 0:
			_render_kick(mix, start)
		if pos == 4 or pos == 12:
			_render_snare(mix, start, rng)
		if pos % 2 == 1:
			_render_hat(mix, start, rng)


static func _render_kick(mix: PackedFloat32Array, start: int) -> void:
	var length := int(SAMPLE_RATE * 0.12)
	for i in length:
		var idx := start + i
		if idx >= mix.size():
			break
		var t := float(i) / float(SAMPLE_RATE)
		var freq := 50.0 + 110.0 * exp(-t * 45.0)
		mix[idx] += sin(t * freq * TAU) * 0.55 * exp(-t * 22.0)


static func _render_snare(mix: PackedFloat32Array, start: int, rng: RandomNumberGenerator) -> void:
	var length := int(SAMPLE_RATE * 0.10)
	for i in length:
		var idx := start + i
		if idx >= mix.size():
			break
		var t := float(i) / float(SAMPLE_RATE)
		var noise := (rng.randf() * 2.0 - 1.0) * 0.32
		var body := sin(t * 190.0 * TAU) * 0.18
		mix[idx] += (noise + body) * exp(-t * 32.0)


static func _render_hat(mix: PackedFloat32Array, start: int, rng: RandomNumberGenerator) -> void:
	var length := int(SAMPLE_RATE * 0.03)
	for i in length:
		var idx := start + i
		if idx >= mix.size():
			break
		var t := float(i) / float(SAMPLE_RATE)
		mix[idx] += (rng.randf() * 2.0 - 1.0) * 0.10 * exp(-t * 120.0)
