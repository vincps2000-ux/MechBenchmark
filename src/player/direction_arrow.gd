# direction_arrow.gd — Red arrow showing the mech body's forward direction
class_name DirectionArrow
extends Node2D

const ARROW_OFFSET := 20.0          # gap in front of the legs sprite
const ARROW_LENGTH := 30.0
const ARROW_WIDTH := 2.5
const ARROW_HEAD_LENGTH := 10.0
const ARROW_HEAD_HALF_WIDTH := 5.0
const ARROW_COLOR := Color(0.95, 0.15, 0.15, 0.55)

func _draw() -> void:
	# Shaft: starts offset in front of the legs, along +X (body forward)
	var start := Vector2(ARROW_OFFSET, 0.0)
	var shaft_end := Vector2(ARROW_OFFSET + ARROW_LENGTH, 0.0)
	draw_line(start, shaft_end, ARROW_COLOR, ARROW_WIDTH)
	# Arrowhead triangle
	var tip := Vector2(ARROW_OFFSET + ARROW_LENGTH + ARROW_HEAD_LENGTH, 0.0)
	var left := Vector2(ARROW_OFFSET + ARROW_LENGTH, -ARROW_HEAD_HALF_WIDTH)
	var right := Vector2(ARROW_OFFSET + ARROW_LENGTH, ARROW_HEAD_HALF_WIDTH)
	draw_polygon(
		PackedVector2Array([tip, left, right]),
		PackedColorArray([ARROW_COLOR, ARROW_COLOR, ARROW_COLOR])
	)
