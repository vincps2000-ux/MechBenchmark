# mud_pit.gd — Traversable hazard zone that slows the player.
# No collision blocking — the player walks through but at reduced speed.
# Shape is elliptical/circular.
class_name MudPit
extends Area2D

## Half-extents (rx, ry) of the ellipse.
@export var radii: Vector2 = Vector2(90, 70)
@export var mud_color: Color = Color(0.34, 0.26, 0.16, 0.72)

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1  # detect player (layer 1)
	monitorable = false

	var col := CollisionShape2D.new()
	var caps := CapsuleShape2D.new()
	caps.radius = (radii.x + radii.y) * 0.5
	caps.height = maxf(radii.x, radii.y) * 2.0
	col.shape = caps
	# Rotate capsule so its long axis matches the larger radius direction
	col.rotation = 0.0 if radii.x >= radii.y else PI * 0.5
	add_child(col)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_mud_zone"):
		body.enter_mud_zone()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("exit_mud_zone"):
		body.exit_mud_zone()

func _draw() -> void:
	var rim := Color(mud_color.r * 0.60, mud_color.g * 0.50, mud_color.b * 0.40, mud_color.a)

	# Base ellipse fill
	_draw_ellipse(Vector2.ZERO, radii, mud_color)

	# Inner highlight blob
	var blob_col := Color(mud_color.r * 0.80, mud_color.g * 0.70, mud_color.b * 0.58, mud_color.a * 0.80)
	_draw_ellipse(Vector2(-radii.x * 0.22, -radii.y * 0.20), radii * 0.45, blob_col)

	# Rim outline
	_draw_ellipse_outline(Vector2.ZERO, radii, rim, 2.5)

	# Slow indicator arrows
	var arrow_col := Color(1.0, 0.85, 0.2, 0.55)
	_draw_down_arrow(Vector2(0.0, -radii.y * 0.3), 7.0, arrow_col)
	_draw_down_arrow(Vector2(-radii.x * 0.38, radii.y * 0.15), 7.0, arrow_col)
	_draw_down_arrow(Vector2( radii.x * 0.38, radii.y * 0.15), 7.0, arrow_col)

func _draw_ellipse(center: Vector2, r: Vector2, col: Color) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * r.x, sin(angle) * r.y))
	draw_colored_polygon(points, col)

func _draw_ellipse_outline(center: Vector2, r: Vector2, col: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * r.x, sin(angle) * r.y))
	draw_polyline(points, col, width)

func _draw_down_arrow(pos: Vector2, size: float, col: Color) -> void:
	draw_line(pos + Vector2(0.0, -size), pos + Vector2(0.0, size), col, 2.0)
	draw_line(pos + Vector2(0.0, size), pos + Vector2(-size * 0.5, size * 0.4), col, 2.0)
	draw_line(pos + Vector2(0.0, size), pos + Vector2(size * 0.5, size * 0.4), col, 2.0)
