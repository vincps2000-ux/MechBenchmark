# laser_beam.gd — Persistent beam visual that stays alive while the laser fires,
# then fades out when stop() is called.
class_name LaserBeam
extends Node2D

const FADE_TIME := 0.25  # seconds for fade-out after stop()

@onready var _glow: Line2D = $GlowLine
@onready var _line: Line2D = $BeamLine

var _fading:  bool  = false
var _elapsed: float = 0.0
## Base colours used for both live rendering and alpha-fade; set by set_intensity().
var _glow_base_color: Color
var _beam_base_color: Color
## Current laser intensity level; set by set_intensity() from Laser.setup().
var _intensity: int = 2

func _ready() -> void:
	add_to_group("level_effect")
	# Seed base colours from the scene defaults so the beam works without a
	# set_intensity() call (e.g. in tests or if spawned manually).
	_glow_base_color = _glow.default_color
	_beam_base_color = _line.default_color

## Apply visual properties for a given intensity level (0 = Flicker … 4 = Overload).
## Must be called before fire() so the colours take effect on the first frame.
func set_intensity(level: int) -> void:
	var t := float(clampi(level, 0, 4)) / 4.0
	# Colour: cyan-white at low intensity → deep red at max intensity
	var glow_rgb := Color(0.0, 0.95, 1.0).lerp(Color(1.0, 0.05, 0.0), t)
	var beam_rgb := Color(0.6, 0.95, 1.0).lerp(Color(1.0, 0.45, 0.15), t)
	glow_rgb.a = 0.45
	beam_rgb.a = 1.0
	_glow_base_color = glow_rgb
	_beam_base_color = beam_rgb
	# Width: narrow hairline at Flicker → thick slab at Overload
	_glow.width = lerpf(3.0, 16.0, t)
	_line.width = lerpf(1.0,  6.0, t)

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
	_glow.default_color = _glow_base_color
	_line.default_color = _beam_base_color
	AudioEventSystem.queue_laser_state(self, from, _intensity, true)

## Update endpoints each frame while the laser is firing
func update_beam(from: Vector2, to: Vector2) -> void:
	if _glow.get_point_count() < 2:
		fire(from, to)
		return
	_glow.set_point_position(0, from)
	_glow.set_point_position(1, to)
	_line.set_point_position(0, from)
	_line.set_point_position(1, to)
	AudioEventSystem.queue_laser_state(self, from, _intensity, true)

## Begin fade-out; the node frees itself when the fade completes
func stop() -> void:
	_fading  = true
	_elapsed = 0.0
	AudioEventSystem.queue_laser_state(self, global_position, _intensity, false)

func _process(delta: float) -> void:
	if not _fading:
		return
	_elapsed += delta
	var t := _elapsed / FADE_TIME
	if t >= 1.0:
		queue_free()
		return
	var alpha := 1.0 - t
	var gc := _glow_base_color; gc.a *= alpha; _glow.default_color = gc
	var lc := _beam_base_color; lc.a *= alpha; _line.default_color = lc

