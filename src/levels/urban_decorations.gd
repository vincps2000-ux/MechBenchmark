# urban_decorations.gd — Procedural background decorations for the urban level.
# Draws street elements: puddles, trash, tire marks, graffiti tags, streetlights,
# parking lines, and building shadows purely via _draw().
class_name UrbanDecorations
extends Node2D

## Arena half-size (should match level_1.gd ARENA_HALF_SIZE)
@export var arena_half_size: float = 1200.0

## Number of random puddles
@export var puddle_count: int = 18

## Number of tire skid marks
@export var skid_count: int = 10

## Number of trash piles
@export var trash_count: int = 20

## Number of street lights
@export var light_count: int = 12

## Number of trees on sidewalk blocks
@export var tree_count: int = 8

## Number of grass patches
@export var grass_count: int = 8

var _puddles: Array = []     # [{pos, radius_x, radius_y, color}]
var _skids: Array = []       # [{start, end, width}]
var _trash: Array = []       # [{pos, points, color}]
var _lights: Array = []      # [{pos, rotation}]
var _parking_lots: Array = []  # [{pos, size, slot_count}]
var _trees: Array = []       # [{pos, canopy_radius}]
var _hedges: Array = []      # [{pos, size}]
var _grass: Array = []       # [{pos, size}]

func _ready() -> void:
	z_index = -1   # draw behind everything in the world layer
	_generate_decorations()
	queue_redraw()

func _generate_decorations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77   # deterministic urban layout

	var half := arena_half_size * 0.85

	# Puddles — dark reflective patches on roads
	for i in puddle_count:
		var pos := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var rx := rng.randf_range(15.0, 50.0)
		var ry := rng.randf_range(10.0, 35.0)
		var alpha := rng.randf_range(0.05, 0.12)
		_puddles.append({
			"pos": pos,
			"radius_x": rx,
			"radius_y": ry,
			"color": Color(0.1, 0.12, 0.18, alpha)
		})

	# Tire skid marks — curved dark lines
	for i in skid_count:
		var start := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var angle := rng.randf_range(0.0, TAU)
		var length := rng.randf_range(60.0, 200.0)
		var curve := rng.randf_range(-0.3, 0.3)
		var end := start + Vector2(cos(angle + curve), sin(angle + curve)) * length
		_skids.append({
			"start": start,
			"end": end,
			"width": rng.randf_range(2.0, 5.0)
		})

	# Trash / debris piles
	for i in trash_count:
		var pos := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var point_count := rng.randi_range(3, 6)
		var points: PackedVector2Array = []
		for j in point_count:
			var angle := TAU * (float(j) / point_count) + rng.randf_range(-0.4, 0.4)
			var dist := rng.randf_range(3.0, 10.0)
			points.append(Vector2(cos(angle), sin(angle)) * dist)
		var brown := rng.randf_range(0.12, 0.22)
		_trash.append({
			"pos": pos,
			"points": points,
			"color": Color(brown + 0.05, brown, brown - 0.03, 0.5)
		})

	# Street light positions along "roads"
	for i in light_count:
		var side := 1.0 if rng.randf() > 0.5 else -1.0
		var along := rng.randf_range(-half * 0.8, half * 0.8)
		var pos: Vector2
		if i % 2 == 0:
			pos = Vector2(side * rng.randf_range(200.0, half * 0.7), along)
		else:
			pos = Vector2(along, side * rng.randf_range(200.0, half * 0.7))
		_lights.append({
			"pos": pos,
			"rotation": rng.randf_range(-0.1, 0.1)
		})

	# Parking lot markings
	_parking_lots.append({"pos": Vector2(-600, -500), "slots": 5, "horizontal": true})
	_parking_lots.append({"pos": Vector2(500, 400), "slots": 4, "horizontal": false})
	_parking_lots.append({"pos": Vector2(-400, 600), "slots": 3, "horizontal": true})

	# Trees — on sidewalk blocks, avoiding building centres
	var tree_positions := [
		Vector2(240, 240),
		Vector2(-240, 240),
		Vector2(720, -720),
		Vector2(-720, 720),
		Vector2(720, -240),
		Vector2(-240, -720),
		Vector2(240, -700),
		Vector2(-720, 240),
	]
	for i in mini(tree_count, tree_positions.size()):
		var pos: Vector2 = tree_positions[i]
		pos += Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		_trees.append({
			"pos": pos,
			"canopy_radius": rng.randf_range(22.0, 38.0)
		})

	# Hedges — small green rectangles at building edges
	_hedges = [
		{"pos": Vector2(-145, -240), "size": Vector2(40, 15)},
		{"pos": Vector2(315, -240), "size": Vector2(35, 12)},
		{"pos": Vector2(-720, -165), "size": Vector2(50, 12)},
		{"pos": Vector2(720, 155), "size": Vector2(55, 12)},
		{"pos": Vector2(-155, 720), "size": Vector2(40, 12)},
	]

	# Grass patches — small green areas on sidewalks
	for i in grass_count:
		var gpos := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var gsize := Vector2(rng.randf_range(25.0, 70.0), rng.randf_range(12.0, 30.0))
		_grass.append({"pos": gpos, "size": gsize})

func _draw() -> void:
	_draw_building_shadows()
	_draw_parking_lots()
	_draw_grass()
	_draw_puddles()
	_draw_skid_marks()
	_draw_trash()
	_draw_hedges()
	_draw_street_lights()
	_draw_crosswalk_hints()
	_draw_trees()

func _draw_building_shadows() -> void:
	# Faint rectangular shadows suggesting buildings just off-screen
	var shadow_color := Color(0.0, 0.0, 0.0, 0.08)
	var buildings := [
		Rect2(-1100, -1100, 300, 250),
		Rect2(800, -900, 280, 350),
		Rect2(-950, 700, 350, 280),
		Rect2(700, 600, 300, 300),
		Rect2(-200, -1000, 400, 150),
		Rect2(300, 900, 250, 200),
	]
	for b in buildings:
		draw_rect(b, shadow_color)
		# Shadow offset
		var shadow := Rect2(b.position + Vector2(8, 12), b.size)
		draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.04))

func _draw_parking_lots() -> void:
	var line_color := Color(0.8, 0.8, 0.7, 0.12)
	for lot in _parking_lots:
		var pos: Vector2 = lot["pos"]
		var slots: int = lot["slots"]
		var horiz: bool = lot["horizontal"]
		var slot_w := 40.0
		var slot_h := 70.0
		for s in slots:
			var offset: Vector2
			if horiz:
				offset = Vector2(s * slot_w, 0)
			else:
				offset = Vector2(0, s * slot_h)
			var tl := pos + offset
			if horiz:
				draw_rect(Rect2(tl, Vector2(slot_w, slot_h)), line_color, false, 1.5)
			else:
				draw_rect(Rect2(tl, Vector2(slot_h, slot_w)), line_color, false, 1.5)

func _draw_puddles() -> void:
	for p in _puddles:
		var pos: Vector2 = p["pos"]
		var rx: float = p["radius_x"]
		var ry: float = p["radius_y"]
		var col: Color = p["color"]
		# Approximate ellipse with scaled circle
		var points: PackedVector2Array = []
		var segments := 16
		for i in segments:
			var angle := TAU * float(i) / segments
			points.append(pos + Vector2(cos(angle) * rx, sin(angle) * ry))
		if points.size() >= 3:
			draw_colored_polygon(points, col)

func _draw_skid_marks() -> void:
	var skid_color := Color(0.06, 0.06, 0.05, 0.18)
	for s in _skids:
		draw_line(s["start"], s["end"], skid_color, s["width"])

func _draw_trash() -> void:
	for t in _trash:
		var points: PackedVector2Array = t["points"]
		var col: Color = t["color"]
		var offset: Vector2 = t["pos"]
		var shifted: PackedVector2Array = []
		for p in points:
			shifted.append(p + offset)
		if shifted.size() >= 3:
			draw_colored_polygon(shifted, col)

func _draw_street_lights() -> void:
	var pole_color := Color(0.3, 0.3, 0.28, 0.4)
	var glow_color := Color(0.9, 0.8, 0.4, 0.04)
	for l in _lights:
		var pos: Vector2 = l["pos"]
		# Pole (small rectangle)
		draw_rect(Rect2(pos.x - 2, pos.y - 2, 4, 4), pole_color)
		# Light glow on ground
		draw_circle(pos, 50.0, glow_color)
		draw_circle(pos, 25.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.06))

func _draw_crosswalk_hints() -> void:
	# Extra crosswalk markings at key intersections
	var cw_color := Color(0.85, 0.85, 0.8, 0.08)
	var positions := [Vector2.ZERO, Vector2(480, 0), Vector2(-480, 0), Vector2(0, 480), Vector2(0, -480)]
	for pos in positions:
		for i in range(-3, 4):
			var stripe := Rect2(pos.x - 25 + i * 12, pos.y - 4, 8, 8)
			draw_rect(stripe, cw_color)

func _draw_trees() -> void:
	for t in _trees:
		var pos: Vector2 = t["pos"]
		var r: float = t["canopy_radius"]
		# Shadow
		draw_circle(pos + Vector2(5, 7), r * 1.1, Color(0.0, 0.0, 0.0, 0.06))
		# Canopy — outer
		draw_circle(pos, r, Color(0.12, 0.32, 0.10, 0.75))
		# Canopy — inner highlight
		draw_circle(pos + Vector2(-2, -2), r * 0.65, Color(0.18, 0.42, 0.14, 0.6))
		# Trunk
		draw_circle(pos, 3.5, Color(0.28, 0.18, 0.10, 0.8))

func _draw_hedges() -> void:
	var hedge_color := Color(0.12, 0.28, 0.08, 0.7)
	var hedge_border := Color(0.08, 0.20, 0.05, 0.5)
	for h in _hedges:
		var pos: Vector2 = h["pos"]
		var sz: Vector2 = h["size"]
		var r := Rect2(pos - sz * 0.5, sz)
		draw_rect(r, hedge_color)
		draw_rect(r, hedge_border, false, 1.5)

func _draw_grass() -> void:
	var grass_color := Color(0.15, 0.30, 0.10, 0.2)
	for g in _grass:
		var pos: Vector2 = g["pos"]
		var sz: Vector2 = g["size"]
		draw_rect(Rect2(pos - sz * 0.5, sz), grass_color)
