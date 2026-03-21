# urban_obstacle.gd — Static blocking obstacle themed for city streets.
# Buildings, cars, dumpsters, barricades — all drawn procedurally.
class_name UrbanObstacle
extends StaticBody2D

enum Shape { BUILDING, CAR, DUMPSTER, BARRICADE, BUS_STOP, LAMPPOST }

## Which shape variant this obstacle uses.
@export var shape_type: Shape = Shape.BUILDING

## Size used for rectangular shapes (BUILDING, CAR, DUMPSTER, BARRICADE).
@export var rect_size: Vector2 = Vector2(120, 100)

## Main fill colour.
@export var color: Color = Color(0.25, 0.24, 0.28, 1.0)

## Accent detail colour.
@export var accent: Color = Color(0.45, 0.42, 0.5, 1.0)

func _ready() -> void:
	collision_layer = 16  # environment layer 5
	collision_mask  = 0
	_build_collision()

func _build_collision() -> void:
	match shape_type:
		Shape.BUILDING:
			var col := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = rect_size
			col.shape = rect
			add_child(col)
		Shape.CAR:
			var col := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = rect_size  # typically ~80x40
			col.shape = rect
			add_child(col)
		Shape.DUMPSTER:
			var col := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = rect_size  # typically ~50x35
			col.shape = rect
			add_child(col)
		Shape.BARRICADE:
			var col := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = rect_size  # typically ~100x20
			col.shape = rect
			add_child(col)
		Shape.BUS_STOP:
			var col := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(60, 20)
			col.shape = rect
			add_child(col)
		Shape.LAMPPOST:
			var col := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 8.0
			col.shape = circle
			add_child(col)

func _draw() -> void:
	match shape_type:
		Shape.BUILDING:
			_draw_building()
		Shape.CAR:
			_draw_car()
		Shape.DUMPSTER:
			_draw_dumpster()
		Shape.BARRICADE:
			_draw_barricade()
		Shape.BUS_STOP:
			_draw_bus_stop()
		Shape.LAMPPOST:
			_draw_lamppost()

func _draw_building() -> void:
	var half := rect_size * 0.5
	var r := Rect2(-half, rect_size)
	# Concrete fill
	var concrete := Color(0.22, 0.21, 0.24, 1.0)
	draw_rect(r, concrete)
	# Dark border
	draw_rect(r, Color(0.15, 0.14, 0.16, 1.0), false, 3.0)
	# Window grid
	var win_color := Color(0.5, 0.55, 0.3, 0.4)  # yellowish lit windows
	var win_dark := Color(0.12, 0.13, 0.18, 0.6)  # dark windows
	var win_w := 10.0
	var win_h := 12.0
	var gap_x := 18.0
	var gap_y := 20.0
	var x := -half.x + 12.0
	var row := 0
	while x + win_w < half.x - 8.0:
		var y := -half.y + 12.0
		var col_idx := 0
		while y + win_h < half.y - 8.0:
			# Deterministic "lit" pattern
			var lit := ((row * 7 + col_idx * 3) % 5) < 3
			var wc: Color = win_color if lit else win_dark
			draw_rect(Rect2(x, y, win_w, win_h), wc)
			y += win_h + gap_y
			col_idx += 1
		x += win_w + gap_x
		row += 1
	# Rooftop edge
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), accent, 2.0)

func _draw_car() -> void:
	var half := rect_size * 0.5  # ~40x20
	var r := Rect2(-half, rect_size)
	# Car body
	draw_rect(r, color)
	draw_rect(r, accent, false, 1.5)
	# Windshield (lighter rectangle inset)
	var ws_inset := Vector2(rect_size.x * 0.15, rect_size.y * 0.2)
	var ws_rect := Rect2(-half + ws_inset, rect_size - ws_inset * 2.0)
	draw_rect(ws_rect, Color(0.3, 0.35, 0.45, 0.6))
	# Wheels (4 dark circles at corners)
	var wheel_r: float = min(rect_size.x, rect_size.y) * 0.12
	var wheel_col := Color(0.08, 0.08, 0.08, 1.0)
	draw_circle(Vector2(-half.x + wheel_r + 4, -half.y + 2), wheel_r, wheel_col)
	draw_circle(Vector2(half.x - wheel_r - 4, -half.y + 2), wheel_r, wheel_col)
	draw_circle(Vector2(-half.x + wheel_r + 4, half.y - 2), wheel_r, wheel_col)
	draw_circle(Vector2(half.x - wheel_r - 4, half.y - 2), wheel_r, wheel_col)
	# Headlights
	draw_circle(Vector2(-half.x + 4, 0), 3.0, Color(0.9, 0.85, 0.5, 0.7))
	draw_circle(Vector2(half.x - 4, 0), 3.0, Color(0.9, 0.2, 0.15, 0.5))

func _draw_dumpster() -> void:
	var half := rect_size * 0.5
	var r := Rect2(-half, rect_size)
	# Main body — dark green
	var dumpster_col := Color(0.15, 0.3, 0.15, 1.0)
	draw_rect(r, dumpster_col)
	draw_rect(r, Color(0.1, 0.2, 0.1, 1.0), false, 2.0)
	# Lid line
	draw_line(Vector2(-half.x, -half.y + 6), Vector2(half.x, -half.y + 6), Color(0.08, 0.15, 0.08, 1.0), 2.0)
	# Handle
	draw_rect(Rect2(-6, -half.y + 1, 12, 4), Color(0.4, 0.4, 0.35, 0.8))
	# Grime stain
	draw_circle(Vector2(half.x * 0.3, half.y * 0.3), 8.0, Color(0.08, 0.1, 0.06, 0.3))

func _draw_barricade() -> void:
	var half := rect_size * 0.5
	var r := Rect2(-half, rect_size)
	# Orange/white striped barricade
	var stripe_a := Color(0.9, 0.5, 0.1, 0.9)
	var stripe_b := Color(0.85, 0.85, 0.8, 0.9)
	draw_rect(r, stripe_b)
	# Diagonal stripes
	var stripe_w := 12.0
	var x := -half.x
	var toggle := true
	while x < half.x:
		var sw: float = min(stripe_w, half.x - x)
		if toggle:
			draw_rect(Rect2(x, -half.y, sw, rect_size.y), stripe_a)
		x += stripe_w
		toggle = not toggle
	draw_rect(r, Color(0.3, 0.3, 0.3, 1.0), false, 2.0)

func _draw_bus_stop() -> void:
	# Shelter roof top-down
	var roof := Rect2(-30, -10, 60, 20)
	draw_rect(roof, Color(0.3, 0.35, 0.4, 0.8))
	draw_rect(roof, Color(0.2, 0.25, 0.3, 1.0), false, 2.0)
	# Bench inside
	draw_rect(Rect2(-20, -3, 40, 6), Color(0.35, 0.25, 0.15, 0.7))
	# Sign pole
	draw_circle(Vector2(25, 0), 4.0, Color(0.2, 0.4, 0.7, 0.8))

func _draw_lamppost() -> void:
	# Pole base (small circle)
	draw_circle(Vector2.ZERO, 6.0, Color(0.3, 0.3, 0.28, 1.0))
	draw_arc(Vector2.ZERO, 6.0, 0, TAU, 16, accent, 1.5)
	# Light glow
	draw_circle(Vector2.ZERO, 35.0, Color(0.9, 0.8, 0.4, 0.03))
	draw_circle(Vector2.ZERO, 18.0, Color(0.9, 0.8, 0.4, 0.06))
