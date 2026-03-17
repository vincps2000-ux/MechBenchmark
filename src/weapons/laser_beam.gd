# laser_beam.gd — Short-lived beam visual spawned at the world root
class_name LaserBeam
extends Node2D

const FADE_TIME := 0.20  # seconds until beam disappears

@onready var _glow: Line2D = $GlowLine
@onready var _line: Line2D = $BeamLine

var _elapsed: float = 0.0

## Set up the beam between two world-space points and start fading
func fire(from: Vector2, to: Vector2) -> void:
	_glow.clear_points()
	_glow.add_point(from)
	_glow.add_point(to)
	_line.clear_points()
	_line.add_point(from)
	_line.add_point(to)

func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / FADE_TIME
	if t >= 1.0:
		queue_free()
		return
	var alpha := 1.0 - t
	var gc := _glow.default_color
	gc.a = alpha * 0.45
	_glow.default_color = gc
	var lc := _line.default_color
	lc.a = alpha
	_line.default_color = lc
