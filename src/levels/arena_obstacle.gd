# arena_obstacle.gd — Static blocking obstacle for the testing ground arena.
# Drawn procedurally — no external sprite needed.
class_name ArenaObstacle
extends StaticBody2D

enum Shape { CRATE, WALL_H, WALL_V, BARREL, L_SHAPE }

## Which shape variant this obstacle uses.
@export var shape_type: Shape = Shape.CRATE

## Overall tint of the obstacle.
@export var color: Color = Color(0.35, 0.32, 0.28, 1.0)

## Highlight / accent color for detail lines.
@export var accent: Color = Color(0.55, 0.50, 0.40, 1.0)

## Size used for rectangular shapes (CRATE, WALL_H, WALL_V).
@export var rect_size: Vector2 = Vector2(60, 60)

## Radius used for BARREL.
@export var barrel_radius: float = 24.0

func _ready() -> void:
	collision_layer = 16  # environment layer 5
	collision_mask  = 0
	_build_collision()

func _build_collision() -> void:
	match shape_type:
		Shape.CRATE, Shape.WALL_H, Shape.WALL_V:
			var col := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = rect_size
			col.shape = rect
			add_child(col)
		Shape.BARREL:
			var col := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = barrel_radius
			col.shape = circle
			add_child(col)
		Shape.L_SHAPE:
			# Two overlapping rectangles forming an L
			var col_a := CollisionShape2D.new()
			var rect_a := RectangleShape2D.new()
			rect_a.size = Vector2(rect_size.x, rect_size.y * 0.4)
			col_a.shape = rect_a
			col_a.position = Vector2(0, -rect_size.y * 0.3)
			add_child(col_a)
			var col_b := CollisionShape2D.new()
			var rect_b := RectangleShape2D.new()
			rect_b.size = Vector2(rect_size.x * 0.4, rect_size.y)
			col_b.shape = rect_b
			col_b.position = Vector2(-rect_size.x * 0.3, 0)
			add_child(col_b)

func _draw() -> void:
	match shape_type:
		Shape.CRATE:
			_draw_crate()
		Shape.WALL_H, Shape.WALL_V:
			_draw_wall()
		Shape.BARREL:
			_draw_barrel()
		Shape.L_SHAPE:
			_draw_l_shape()

func _draw_crate() -> void:
	var half := rect_size * 0.5
	var r := Rect2(-half, rect_size)
	# Body
	draw_rect(r, color)
	# Border
	draw_rect(r, accent, false, 2.0)
	# Cross braces
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, half.y), accent * 0.7, 1.5)
	draw_line(Vector2(half.x, -half.y), Vector2(-half.x, half.y), accent * 0.7, 1.5)
	# Inner padding rect
	var inset := 6.0
	draw_rect(Rect2(-half.x + inset, -half.y + inset, rect_size.x - inset * 2, rect_size.y - inset * 2), accent, false, 1.0)

func _draw_wall() -> void:
	var half := rect_size * 0.5
	var r := Rect2(-half, rect_size)
	# Dark concrete fill
	var wall_col := Color(0.28, 0.26, 0.24, 1.0)
	draw_rect(r, wall_col)
	# Hazard stripe accents
	var stripe_col := Color(0.85, 0.65, 0.1, 0.5)
	var stripe_w := 8.0
	if rect_size.x >= rect_size.y:
		# Horizontal wall — vertical stripes
		var x_pos := -half.x + 12.0
		while x_pos < half.x - 4.0:
			draw_rect(Rect2(x_pos, -half.y + 2.0, stripe_w, rect_size.y - 4.0), stripe_col)
			x_pos += stripe_w * 3.0
	else:
		# Vertical wall — horizontal stripes
		var y_pos := -half.y + 12.0
		while y_pos < half.y - 4.0:
			draw_rect(Rect2(-half.x + 2.0, y_pos, rect_size.x - 4.0, stripe_w), stripe_col)
			y_pos += stripe_w * 3.0
	# Border
	draw_rect(r, accent, false, 2.5)

func _draw_barrel() -> void:
	var r := barrel_radius
	# Outer circle fill
	draw_circle(Vector2.ZERO, r, color)
	# Ring details
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, accent, 2.0)
	draw_arc(Vector2.ZERO, r * 0.6, 0, TAU, 24, accent * 0.7, 1.5)
	# Highlight dot
	draw_circle(Vector2(-r * 0.25, -r * 0.25), 3.0, Color(1, 1, 1, 0.15))

func _draw_l_shape() -> void:
	# Horizontal bar of the L
	var h_rect := Rect2(-rect_size.x * 0.5, -rect_size.y * 0.5, rect_size.x, rect_size.y * 0.4)
	draw_rect(h_rect, color)
	draw_rect(h_rect, accent, false, 2.0)
	# Vertical bar of the L
	var v_rect := Rect2(-rect_size.x * 0.5, -rect_size.y * 0.5, rect_size.x * 0.4, rect_size.y)
	draw_rect(v_rect, color)
	draw_rect(v_rect, accent, false, 2.0)
