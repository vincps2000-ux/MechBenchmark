# arena_decorations.gd — Procedural background decorations for the testing arena.
# Adds floor markings, scorch marks, oil stains, and range markers purely via _draw().
class_name ArenaDecorations
extends Node2D

## Arena half-size (should match gameplay.gd ARENA_HALF_SIZE)
@export var arena_half_size: float = 1000.0

## Number of random floor stains
@export var stain_count: int = 25

## Number of random scorch marks
@export var scorch_count: int = 15

## Number of debris piles
@export var debris_count: int = 12

var _stains: Array = []     # [{pos, radius, color}]
var _scorches: Array = []   # [{pos, radius, rot}]
var _debris: Array = []     # [{pos, points, color}]

func _ready() -> void:
	z_index = -1   # draw behind everything in the world layer
	_generate_decorations()
	queue_redraw()

func _generate_decorations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42   # deterministic so the arena looks the same each run

	var half := arena_half_size * 0.9  # keep within bounds

	# Oil / grease stains
	for i in stain_count:
		var pos := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var radius := rng.randf_range(12.0, 45.0)
		var alpha := rng.randf_range(0.04, 0.12)
		var shade := rng.randf_range(0.0, 0.08)
		_stains.append({
			"pos": pos,
			"radius": radius,
			"color": Color(shade, shade, shade + 0.02, alpha)
		})

	# Scorch / burn marks (from previous tests)
	for i in scorch_count:
		var pos := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var radius := rng.randf_range(8.0, 30.0)
		_scorches.append({
			"pos": pos,
			"radius": radius,
			"rot": rng.randf_range(0.0, TAU)
		})

	# Random debris piles — small irregular polygons
	for i in debris_count:
		var pos := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var point_count := rng.randi_range(4, 7)
		var points: PackedVector2Array = []
		for j in point_count:
			var angle := TAU * (float(j) / point_count) + rng.randf_range(-0.3, 0.3)
			var dist := rng.randf_range(4.0, 14.0)
			points.append(Vector2(cos(angle), sin(angle)) * dist)
		var grey := rng.randf_range(0.15, 0.25)
		_debris.append({
			"pos": pos,
			"points": points,
			"color": Color(grey, grey - 0.02, grey - 0.04, 0.6)
		})

func _draw() -> void:
	_draw_lane_markings()
	_draw_stains()
	_draw_scorches()
	_draw_debris()
	_draw_target_zones()

func _draw_lane_markings() -> void:
	# Dashed lines radiating from origin like shooting lanes
	var lane_color := Color(0.85, 0.65, 0.1, 0.08)
	var dash_len := 20.0
	var gap_len := 15.0
	var lane_count := 8
	for i in lane_count:
		var angle := TAU * (float(i) / lane_count)
		var dir := Vector2(cos(angle), sin(angle))
		var dist := 100.0
		while dist < arena_half_size * 0.9:
			var start := dir * dist
			var end := dir * (dist + dash_len)
			draw_line(start, end, lane_color, 1.5)
			dist += dash_len + gap_len

func _draw_stains() -> void:
	for s in _stains:
		draw_circle(s["pos"], s["radius"], s["color"])

func _draw_scorches() -> void:
	var scorch_color := Color(0.08, 0.06, 0.04, 0.15)
	for s in _scorches:
		var pos: Vector2 = s["pos"]
		var r: float = s["radius"]
		# Draw as several overlapping circles for an irregular look
		draw_circle(pos, r, scorch_color)
		draw_circle(pos + Vector2(r * 0.3, r * 0.2), r * 0.6, scorch_color * 0.8)
		draw_circle(pos - Vector2(r * 0.2, r * 0.4), r * 0.4, scorch_color * 0.6)

func _draw_debris() -> void:
	for d in _debris:
		var points: PackedVector2Array = d["points"]
		var col: Color = d["color"]
		var offset: Vector2 = d["pos"]
		var shifted: PackedVector2Array = []
		for p in points:
			shifted.append(p + offset)
		if shifted.size() >= 3:
			draw_colored_polygon(shifted, col)

func _draw_target_zones() -> void:
	# Faint circles on the floor where targets are typically placed
	var zone_color := Color(0.9, 0.3, 0.2, 0.06)
	var zone_radii := [200.0, 400.0, 650.0]
	for r in zone_radii:
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, zone_color, 2.0)
	# Cardinal direction labels (N/S/E/W at the edges)
	# Offset slightly inside the boundary
	var label_dist := arena_half_size - 60.0
	var marker_col := Color(0.85, 0.65, 0.1, 0.12)
	var marker_len := 30.0
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d: Vector2 in dirs:
		var base: Vector2 = d * label_dist
		var perp: Vector2 = Vector2(-d.y, d.x)
		draw_line(base - perp * marker_len, base + perp * marker_len, marker_col, 2.0)
		draw_line(base, base - d * marker_len * 0.6, marker_col, 2.0)
