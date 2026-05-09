# laser_beam.gd — Persistent beam visual that stays alive while the laser fires,
# then fades out when stop() is called.
class_name LaserBeam
extends Node2D

const FADE_TIME := 0.25  # seconds for fade-out after stop()

@onready var _glow: Line2D = $GlowLine
@onready var _line: Line2D = $BeamLine

var _fading:  bool  = false
var _elapsed: float = 0.0

func _ready() -> void:
	add_to_group("level_effect")

## Initial setup — called on the first frame the laser fires
func fire(from: Vector2, to: Vector2) -> void:
	_fading  = false
	_elapsed = 0.0
	_glow.clear_points()
	_glow.add_point(from)
	_glow.add_point(to)
	_line.clear_points()
	_line.add_point(from)
	_line.add_point(to)
	# Restore full alpha in case a previous fade left it partial
	var gc := _glow.default_color; gc.a = 0.45; _glow.default_color = gc
	var lc := _line.default_color; lc.a = 1.00; _line.default_color = lc

## Update endpoints each frame while the laser is firing
func update_beam(from: Vector2, to: Vector2) -> void:
	if _glow.get_point_count() < 2:
		fire(from, to)
		return
	_glow.set_point_position(0, from)
	_glow.set_point_position(1, to)
	_line.set_point_position(0, from)
	_line.set_point_position(1, to)

## Begin fade-out; the node frees itself when the fade completes
func stop() -> void:
	_fading  = true
	_elapsed = 0.0

func _process(delta: float) -> void:
	if not _fading:
		return
	_elapsed += delta
	var t := _elapsed / FADE_TIME
	if t >= 1.0:
		queue_free()
		return
	var alpha := 1.0 - t
	var gc := _glow.default_color; gc.a = alpha * 0.45; _glow.default_color = gc
	var lc := _line.default_color; lc.a = alpha;        _line.default_color = lc
