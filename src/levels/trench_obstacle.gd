# trench_obstacle.gd — Static blocking obstacle for the trench battlefield.
# Sandbag walls, bunkers, barbed wire, wreckage — drawn procedurally.
class_name TrenchObstacle
extends StaticBody2D

enum Shape { SANDBAG_WALL, BUNKER, BARBED_WIRE, WRECKAGE }

@export var shape_type: Shape = Shape.SANDBAG_WALL
@export var rect_size: Vector2 = Vector2(140, 32)
@export var color: Color = Color(0.55, 0.47, 0.35, 1.0)
@export var accent: Color = Color(0.4, 0.33, 0.22, 1.0)

func _ready() -> void:
	collision_layer = 16
	collision_mask  = 0
	_build_collision()

func _build_collision() -> void:
	match shape_type:
		Shape.SANDBAG_WALL, Shape.BUNKER, Shape.BARBED_WIRE, Shape.WRECKAGE:
			var col := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = rect_size
			col.shape = rect
			add_child(col)

func _draw() -> void:
	match shape_type:
		Shape.SANDBAG_WALL: _draw_sandbag_wall()
		Shape.BUNKER:       _draw_bunker()
		Shape.BARBED_WIRE:  _draw_barbed_wire()
		Shape.WRECKAGE:     _draw_wreckage()

func _draw_sandbag_wall() -> void:
	var half := rect_size * 0.5
	var sand_color  := Color(0.62, 0.54, 0.38, 1.0)
	var shadow_color := Color(0.38, 0.30, 0.18, 1.0)
	var top_color   := Color(0.68, 0.60, 0.44, 1.0)
	var bag_w := 28.0
	var bag_h := rect_size.y * 0.75

	# Bottom row of sandbags
	var x := -half.x + bag_w * 0.5
	while x < half.x - bag_w * 0.3:
		var r := Rect2(x - bag_w * 0.5, -half.y + (rect_size.y - bag_h) * 0.5, bag_w - 2.0, bag_h)
		draw_rect(r, sand_color)
		draw_rect(r, shadow_color, false, 1.5)
		draw_circle(Vector2(x, 0.0), 2.5, shadow_color)
		x += bag_w - 3.0

	# Top row (offset, slightly smaller)
	x = -half.x + bag_w
	var top_bag_h := bag_h * 0.65
	while x < half.x - bag_w * 0.5:
		var r := Rect2(x - bag_w * 0.5, -half.y, bag_w - 2.0, top_bag_h)
		draw_rect(r, top_color)
		draw_rect(r, shadow_color, false, 1.0)
		x += bag_w - 3.0

func _draw_bunker() -> void:
	var half := rect_size * 0.5
	var concrete := Color(0.32, 0.30, 0.27, 1.0)
	var dark     := Color(0.15, 0.14, 0.12, 1.0)
	var roof     := Color(0.28, 0.26, 0.23, 1.0)

	draw_rect(Rect2(-half, rect_size), concrete)
	draw_rect(Rect2(-half, rect_size), dark, false, 3.0)

	# Gun slit
	var slit_w := rect_size.x * 0.38
	var slit_h := 7.0
	draw_rect(Rect2(-slit_w * 0.5, -slit_h * 0.5, slit_w, slit_h), dark)

	# Roof panel lines
	var line_gap := rect_size.x / 4.0
	for i in 3:
		var lx := -half.x + line_gap * (i + 1)
		draw_line(Vector2(lx, -half.y + 4.0), Vector2(lx, half.y - 4.0), roof, 2.0)

	# Corner bolts
	for cx in [-half.x + 6.0, half.x - 6.0]:
		for cy in [-half.y + 6.0, half.y - 6.0]:
			draw_circle(Vector2(cx, cy), 3.5, dark)

func _draw_barbed_wire() -> void:
	var half      := rect_size * 0.5
	var wire_col  := Color(0.68, 0.63, 0.52, 1.0)
	var post_col  := Color(0.42, 0.38, 0.28, 1.0)

	# Upright posts
	var post_spacing := 36.0
	var px := -half.x + 10.0
	while px <= half.x - 10.0:
		draw_line(Vector2(px, -half.y), Vector2(px, half.y), post_col, 3.0)
		px += post_spacing

	# Zigzag wire strands (two rows)
	for row in 2:
		var y_base := lerpf(-half.y + 5.0, half.y - 5.0, 0.25 + row * 0.5)
		var prev := Vector2(-half.x, y_base)
		var xi := -half.x + 8.0
		var toggle := false
		while xi < half.x:
			var ny := y_base + (8.0 if toggle else -8.0)
			draw_line(prev, Vector2(xi, ny), wire_col, 1.5)
			prev = Vector2(xi, ny)
			toggle = !toggle
			xi += 8.0

func _draw_wreckage() -> void:
	var half      := rect_size * 0.5
	var hull_col  := Color(0.28, 0.24, 0.20, 1.0)
	var burn_col  := Color(0.16, 0.13, 0.10, 1.0)
	var rust_col  := Color(0.46, 0.28, 0.14, 1.0)
	var rim_col   := Color(0.13, 0.11, 0.09, 1.0)

	draw_rect(Rect2(-half, rect_size), hull_col)
	# Burn patches
	draw_rect(Rect2(-half.x + 8.0, -half.y + 6.0, rect_size.x * 0.32, rect_size.y * 0.55), burn_col)
	draw_rect(Rect2(half.x - rect_size.x * 0.28 - 6.0, half.y - rect_size.y * 0.45 - 6.0,
		rect_size.x * 0.28, rect_size.y * 0.45), burn_col)
	# Rust streaks
	draw_line(Vector2(-half.x + 22.0, -half.y), Vector2(-half.x + 16.0, half.y), rust_col, 2.0)
	draw_line(Vector2(half.x - 26.0, -half.y), Vector2(half.x - 20.0, half.y), rust_col, 2.0)
	# Outline
	draw_rect(Rect2(-half, rect_size), rim_col, false, 2.5)
