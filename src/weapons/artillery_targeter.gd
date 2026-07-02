# artillery_targeter.gd — Aiming reticle for the Artillery weapon.
#
# A lightweight Node2D that draws the projected blast footprint at the cursor
# while the fire button is held.  The Artillery weapon repositions and recolours
# it every frame: green when a strike can be launched, red/amber otherwise.
# It also draws a dashed inner ring showing the shell-scatter zone so the player
# can read how far an impact may drift from the aim point.
class_name ArtilleryTargeter
extends Node2D

const POINT_COUNT := 64

var _radius: float = 150.0
var _scatter_radius: float = 0.0
var _color: Color = Color(0.3, 1.0, 0.35, 0.9)

func _ready() -> void:
	z_index = 8

## Update the reticle footprint radius, colour and scatter zone, then redraw.
func configure(radius: float, color: Color, scatter_radius: float = 0.0) -> void:
	_radius = radius
	_color = color
	_scatter_radius = scatter_radius
	queue_redraw()

func _draw() -> void:
	# Faint fill so the danger zone reads at a glance.
	var fill := _color
	fill.a = 0.12
	draw_circle(Vector2.ZERO, _radius, fill)

	# Outer footprint ring.
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, POINT_COUNT, _color, 2.5, true)

	# Dashed inner ring marks how far the impact may scatter from the aim point.
	if _scatter_radius > 1.0:
		_draw_dashed_circle(_scatter_radius, _color)

	# Cross-hair + centre pip mark the aim point.
	var arm := _radius * 0.22
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), _color, 2.0, true)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), _color, 2.0, true)
	draw_circle(Vector2.ZERO, 3.0, _color)

func _draw_dashed_circle(radius: float, color: Color) -> void:
	var dash_count := 24
	var c := color
	c.a = color.a * 0.7
	for i in dash_count:
		if i % 2 == 1:
			continue  # skip every other segment to create the dashes
		var a0 := TAU * float(i) / float(dash_count)
		var a1 := TAU * float(i + 1) / float(dash_count)
		draw_arc(Vector2.ZERO, radius, a0, a1, 4, c, 1.5, true)
