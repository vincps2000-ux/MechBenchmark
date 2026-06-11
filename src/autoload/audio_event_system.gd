extends Node

const AUDIO_EVENT_SCRIPT := preload("res://src/autoload/audio_event.gd")
const _AUDIO_SAMPLE_RATE := 22050
const _LASER_LOOP_DURATION := 0.12

enum EventKind {
	LASER_STATE,
	DEFLECTION,
	EXPLOSION,
}

class LaserVoice:
	extends RefCounted

	var player: AudioStreamPlayer2D = null
	var source_ref: WeakRef = null
	var last_timestamp: float = -INF
	var intensity: int = 2


var _clock_sec: float = 0.0
var _pending_events: Array = []
var _next_sequence: int = 0
var _processing_events: bool = false
var _laser_voices: Dictionary = {}
var _laser_stream_cache: Dictionary = {}
var _deflection_stream: AudioStreamWAV = null
var _explosion_stream_cache: Dictionary = {}


func _process(delta: float) -> void:
	_clock_sec += maxf(delta, 0.0)
	_drain_ready_events()
	_prune_orphaned_laser_voices()


func now() -> float:
	return _clock_sec


func queue_event(event) -> void:
	if event == null or event.cancelled:
		return
	if event.time_sec <= 0.0:
		event.time_sec = _clock_sec
	event.sequence = _next_sequence
	_next_sequence += 1
	_pending_events.append(event)
	if not _processing_events:
		_drain_ready_events()


func queue_laser_state(source: Object, position: Vector2, intensity: int, active: bool, event_time: float = -1.0) -> void:
	var event = _create_event(EventKind.LASER_STATE, position, intensity, event_time)
	event.source_id = _source_id(source)
	event.source_ref = weakref(source) if is_instance_valid(source) else null
	event.active = active
	queue_event(event)


func play_deflection_sizzle(position: Vector2, intensity: int = 2, event_time: float = -1.0) -> void:
	var event = _create_event(EventKind.DEFLECTION, position, intensity, event_time)
	queue_event(event)


func play_explosion_boom(position: Vector2, scale: float = 1.0, event_time: float = -1.0) -> void:
	var event = _create_event(EventKind.EXPLOSION, position, 2, event_time)
	event.scale = scale
	queue_event(event)


func stop_event(event) -> void:
	if event == null:
		return
	event.cancelled = true
	_pending_events.erase(event)
	if event.player != null and is_instance_valid(event.player):
		event.player.stop()
		event.player.queue_free()
		event.player = null


static func get_laser_volume_db(level: int) -> float:
	match clampi(level, 0, 4):
		0: return -32.0
		1: return -26.0
		2: return -16.0
		3: return -5.0
		_: return 1.5


static func get_laser_pitch_scale(level: int) -> float:
	match clampi(level, 0, 4):
		0: return 0.74
		1: return 0.82
		2: return 1.0
		3: return 1.24
		_: return 1.42


static func get_deflection_volume_db(level: int) -> float:
	var t := float(clampi(level, 0, 4)) / 4.0
	return lerpf(-12.0, -5.5, t)


func _source_id(source: Object) -> int:
	if is_instance_valid(source):
		return source.get_instance_id()
	return 0


func _create_event(kind: int, position: Vector2, intensity: int, event_time: float) -> Variant:
	var event = AUDIO_EVENT_SCRIPT.new()
	event.kind = kind
	event.time_sec = _clock_sec if event_time < 0.0 else event_time
	event.position = position
	event.intensity = clampi(intensity, 0, 4)
	event.max_distance = 800.0
	if kind == EventKind.DEFLECTION:
		event.max_distance = 600.0
	return event


func _drain_ready_events() -> void:
	if _pending_events.is_empty():
		return
	_processing_events = true
	_pending_events.sort_custom(_is_event_before)
	while not _pending_events.is_empty():
		var event = _pending_events[0]
		if event.time_sec > _clock_sec + 0.0001:
			break
		_pending_events.pop_front()
		_dispatch_event(event)
	_processing_events = false


func _is_event_before(left, right) -> bool:
	if not is_equal_approx(left.time_sec, right.time_sec):
		return left.time_sec < right.time_sec
	return left.sequence < right.sequence


func _dispatch_event(event) -> void:
	match event.kind:
		EventKind.LASER_STATE:
			_apply_laser_state(event)
		EventKind.DEFLECTION:
			_play_one_shot(event.position, _get_deflection_stream(), -8.0, 600.0, 1.0)
		EventKind.EXPLOSION:
			var t := clampf((event.scale - 1.0) * 0.5 + 0.5, 0.0, 1.0)
			var volume := lerpf(-7.0, -3.0, t)
			var pitch := lerpf(0.92, 1.08, t)
			_play_one_shot(event.position, _get_explosion_stream(event.scale), volume, 800.0 * maxf(0.2, event.scale), pitch)


func _apply_laser_state(event) -> void:
	if event.source_id == 0:
		return
	if not event.active:
		_stop_laser_voice(event.source_id)
		return

	var voice: LaserVoice = _laser_voices.get(event.source_id)
	if voice == null:
		voice = LaserVoice.new()
		voice.player = _create_player(event.position, _get_laser_stream(event.intensity), get_laser_volume_db(event.intensity), 800.0, get_laser_pitch_scale(event.intensity))
		voice.source_ref = event.source_ref
		voice.last_timestamp = event.time_sec
		voice.intensity = event.intensity
		_laser_voices[event.source_id] = voice
		return

	if event.time_sec < voice.last_timestamp:
		return
	voice.last_timestamp = event.time_sec
	voice.source_ref = event.source_ref
	if not is_instance_valid(voice.player):
		voice.player = _create_player(event.position, _get_laser_stream(event.intensity), get_laser_volume_db(event.intensity), 800.0, get_laser_pitch_scale(event.intensity))
		voice.intensity = event.intensity
		return

	voice.player.global_position = event.position
	if voice.intensity != event.intensity:
		voice.intensity = event.intensity
		voice.player.stop()
		voice.player.stream = _get_laser_stream(event.intensity)
	voice.player.volume_db = get_laser_volume_db(event.intensity)
	voice.player.pitch_scale = get_laser_pitch_scale(event.intensity)
	if not voice.player.playing:
		voice.player.play()


func _stop_laser_voice(source_id: int) -> void:
	if not _laser_voices.has(source_id):
		return
	var voice: LaserVoice = _laser_voices[source_id]
	_laser_voices.erase(source_id)
	if voice != null and is_instance_valid(voice.player):
		voice.player.stop()
		voice.player.queue_free()


func _prune_orphaned_laser_voices() -> void:
	var removed: Array[int] = []
	for source_id in _laser_voices.keys():
		var voice: LaserVoice = _laser_voices[source_id]
		if voice == null:
			removed.append(source_id)
			continue
		var source: Object = voice.source_ref.get_ref() if voice.source_ref != null else null
		if source == null or not is_instance_valid(source) or not is_instance_valid(voice.player):
			removed.append(source_id)
	for source_id in removed:
		_stop_laser_voice(source_id)


func _create_player(position: Vector2, stream: AudioStream, volume_db: float, max_distance: float, pitch_scale: float) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.global_position = position
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.pitch_scale = pitch_scale
	add_child(player)
	player.play()
	return player


func _play_one_shot(position: Vector2, stream: AudioStream, volume_db: float, max_distance: float, pitch_scale: float) -> void:
	var player := _create_player(position, stream, volume_db, max_distance, pitch_scale)
	player.finished.connect(player.queue_free)


func _get_laser_stream(level: int) -> AudioStreamWAV:
	var idx := clampi(level, 0, 4)
	if _laser_stream_cache.has(idx):
		return _laser_stream_cache[idx]
	var stream := _create_laser_stream(idx)
	_laser_stream_cache[idx] = stream
	return stream


func _get_deflection_stream() -> AudioStreamWAV:
	if _deflection_stream != null:
		return _deflection_stream
	_deflection_stream = _create_deflection_stream()
	return _deflection_stream


func _get_explosion_stream(scale: float) -> AudioStreamWAV:
	var key := snappedf(maxf(0.2, scale), 0.2)
	if _explosion_stream_cache.has(key):
		return _explosion_stream_cache[key]
	var stream := _create_explosion_stream(key)
	_explosion_stream_cache[key] = stream
	return stream


static func _laser_carrier_gain(level: int) -> float:
	match level:
		0: return 0.24
		1: return 0.36
		2: return 0.52
		3: return 0.70
		_: return 0.90


static func _laser_harmonic_gain(level: int) -> float:
	match level:
		0: return 0.12
		1: return 0.20
		2: return 0.30
		3: return 0.40
		_: return 0.52


static func _laser_buzz_gain(level: int) -> float:
	match level:
		0: return 0.06
		1: return 0.10
		2: return 0.16
		3: return 0.22
		_: return 0.30


static func _laser_noise_gain(level: int) -> float:
	match level:
		0: return 0.01
		1: return 0.02
		2: return 0.03
		3: return 0.04
		_: return 0.05


static func _laser_carrier_cycles(level: int) -> int:
	match level:
		0: return 8
		1: return 11
		2: return 15
		3: return 19
		_: return 24


static func _laser_harmonic_cycles(level: int) -> int:
	match level:
		0: return 16
		1: return 22
		2: return 30
		3: return 38
		_: return 48


static func _laser_buzz_cycles(level: int) -> int:
	match level:
		0: return 5
		1: return 7
		2: return 9
		3: return 12
		_: return 15


static func _laser_noise_rate(level: int) -> float:
	match level:
		0: return 0.6
		1: return 0.8
		2: return 1.0
		3: return 1.2
		_: return 1.4


static func _create_laser_stream(level: int) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.12
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var carrier_gain := _laser_carrier_gain(level)
	var harmonic_gain := _laser_harmonic_gain(level)
	var buzz_gain := _laser_buzz_gain(level)
	var noise_gain := _laser_noise_gain(level)
	var carrier_cycles := _laser_carrier_cycles(level)
	var harmonic_cycles := _laser_harmonic_cycles(level)
	var buzz_cycles := _laser_buzz_cycles(level)
	var noise_rate := _laser_noise_rate(level)

	for i in num_samples:
		var phase := float(i) / float(num_samples)
		var carrier: float = sin(phase * float(carrier_cycles) * TAU) * carrier_gain
		var harmonic: float = sin(phase * float(harmonic_cycles) * TAU) * harmonic_gain
		var buzz: float = sin(phase * float(buzz_cycles) * TAU) * buzz_gain
		var hiss: float = (randf() * 2.0 - 1.0) * noise_gain * noise_rate
		var sample: float = carrier + harmonic + buzz + hiss
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream


static func _create_deflection_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.09
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-t * 40.0)
		var hiss := (randf() * 2.0 - 1.0) * 0.60
		var crackle := sin(t * (3600.0 + 1800.0 * exp(-t * 55.0)) * TAU) * 0.35
		var fizz := sin(t * (7600.0 + 900.0 * exp(-t * 70.0)) * TAU) * 0.20
		var sample := (hiss + crackle + fizz) * envelope
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


static func _create_explosion_stream(scale: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.18 * maxf(0.5, minf(scale, 2.0))
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-t * 20.0)
		var freq := 90.0 + 60.0 * exp(-t * 25.0)
		var boom := sin(t * freq * TAU) * 0.7
		var noise := (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 35.0)
		var sample := (boom + noise) * envelope
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream