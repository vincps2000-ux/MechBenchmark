# deflection_sparks.gd — Brief spark burst + metallic plink on armour deflection.
class_name DeflectionSparks
extends Node2D

const SPARK_COUNT  := 6
const SPARK_LENGTH := 12.0
const LIFETIME     := 0.25

var _sparks: Array[Dictionary] = []
var _elapsed: float = 0.0
var _audio: AudioStreamPlayer2D

func _ready() -> void:
	z_index = 12
	# Generate random spark directions
	for _i in SPARK_COUNT:
		var angle := randf() * TAU
		var speed := randf_range(80.0, 180.0)
		_sparks.append({
			"dir": Vector2.from_angle(angle),
			"speed": speed,
			"offset": 0.0,
		})

	# Procedural plink sound
	_audio = AudioStreamPlayer2D.new()
	_audio.stream = _create_plink_stream()
	_audio.volume_db = -8.0
	_audio.max_distance = 600.0
	add_child(_audio)
	_audio.play()

func _process(delta: float) -> void:
	_elapsed += delta
	for s in _sparks:
		s["offset"] += s["speed"] * delta
	queue_redraw()
	if _elapsed >= LIFETIME:
		queue_free()

func _draw() -> void:
	var alpha := 1.0 - (_elapsed / LIFETIME)
	var color := Color(1.0, 0.85, 0.3, alpha)
	var white := Color(1.0, 1.0, 1.0, alpha * 0.7)
	for s in _sparks:
		var dir: Vector2 = s["dir"]
		var ofs: float = s["offset"]
		var start := dir * ofs
		var end   := dir * (ofs + SPARK_LENGTH * alpha)
		draw_line(start, end, color, 1.5)
		draw_line(start, start + dir * 3.0, white, 2.0)

static func _create_plink_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.07
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-t * 60.0)
		# Descending metallic ping — two harmonics
		var freq1 := 3200.0 + 800.0 * exp(-t * 40.0)
		var freq2 := 4800.0 + 600.0 * exp(-t * 50.0)
		var sample := (sin(t * freq1 * TAU) * 0.6 + sin(t * freq2 * TAU) * 0.4) * envelope
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2]     = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
