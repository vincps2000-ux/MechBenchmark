# deflection_sparks.gd — Brief spark burst + sizzling sound on armour deflection.
class_name DeflectionSparks
extends Node2D

const SPARK_COUNT  := 6
const SPARK_LENGTH := 12.0
const LIFETIME     := 0.25

var _sparks: Array[Dictionary] = []
var _elapsed: float = 0.0

func _ready() -> void:
	z_index = 12
	add_to_group("level_effect")
	# Generate random spark directions
	for _i in SPARK_COUNT:
		var angle := randf() * TAU
		var speed := randf_range(80.0, 180.0)
		_sparks.append({
			"dir": Vector2.from_angle(angle),
			"speed": speed,
			"offset": 0.0,
		})

	AudioEventSystem.play_deflection_sizzle(global_position)

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

