# autocannon_explosion.gd — Small impact explosion that deals area damage.
#
# Instantiated at the point of projectile impact.  Draws a circle that
# rapidly expands then fades out.  During the expand phase an Area2D hitbox
# (radius = MAX_RADIUS) is active; every enemy touched once receives damage.
# The hitbox is disabled as soon as the expand phase ends so enemies walking
# through the fading visual are not hit a second time.
class_name AutocannonExplosion
extends Area2D

## Radius the explosion ring grows to at full expansion.
const MAX_RADIUS  := 40.0
## Duration of the expand phase (fast snap outward).
const EXPAND_TIME := 0.10
## Duration of the fade phase after fully expanded.
const FADE_TIME   := 0.18
## Number of points used to draw the circle polygon.
const POINT_COUNT := 24

## Inner fill: warm orange.
const COLOR_FILL  := Color(1.00, 0.55, 0.10, 0.70)
## Outer ring: bright yellow-white.
const COLOR_RING  := Color(1.00, 0.90, 0.30, 0.90)

# 0 = expanding, 1 = fading
var _state:   int   = 0
var _elapsed: float = 0.0

var _fill_poly : Polygon2D = null
var _ring_poly : Polygon2D = null

## Damage dealt to each enemy inside the blast radius.  Set by the projectile
## before this node is added to the scene tree.
var damage: int = 25
## Armour penetration value; set by the projectile.
var penetration: int = 4

## Tracks enemies already damaged so a slow enemy isn't hit twice.
var _hit_set: Array = []

func _ready() -> void:
	# ── Collision: no layer (we are not an obstacle), mask layer 2 = enemies ──
	collision_layer = 0
	collision_mask  = 2
	monitorable      = false   # nothing needs to detect us
	# Defer monitoring enable to avoid "Can't change state while flushing queries"
	# when spawned from inside an area_entered callback.
	monitoring       = false
	set_deferred("monitoring", true)

	# Circle hitbox matching the full blast radius
	var shape := CircleShape2D.new()
	shape.radius = MAX_RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Build fill disc
	_fill_poly = Polygon2D.new()
	_fill_poly.color = COLOR_FILL
	_fill_poly.z_index = 10
	add_child(_fill_poly)

	# Build thicker outline ring
	_ring_poly = Polygon2D.new()
	_ring_poly.color = COLOR_RING
	_ring_poly.z_index = 11
	add_child(_ring_poly)

	_update_visuals(0.0, 1.0)

func _process(delta: float) -> void:
	_elapsed += delta

	match _state:
		0:  # expand
			var t := _elapsed / EXPAND_TIME
			if t >= 1.0:
				t = 1.0
				_state = 1
				_elapsed = 0.0
				# Blast window closed — stop detecting new targets
				monitoring = false
			_update_visuals(t, 1.0)

		1:  # fade
			var t := _elapsed / FADE_TIME
			if t >= 1.0:
				queue_free()
				return
			_update_visuals(1.0, 1.0 - t)

func _update_visuals(expand_t: float, alpha: float) -> void:
	# Ease-out expansion so it snaps fast then slows
	var radius := MAX_RADIUS * (1.0 - pow(1.0 - expand_t, 2.0))

	_fill_poly.polygon  = _make_circle(radius * 0.80)
	_ring_poly.polygon  = _make_circle(radius)

	var fill_c  := COLOR_FILL
	fill_c.a    = COLOR_FILL.a  * alpha
	_fill_poly.color = fill_c

	var ring_c  := COLOR_RING
	ring_c.a    = COLOR_RING.a  * alpha
	_ring_poly.color = ring_c

func _on_area_entered(area: Area2D) -> void:
	if _hit_set.has(area):
		return
	_hit_set.append(area)
	if area.has_method("take_damage"):
		area.take_damage(damage, penetration)
	elif is_instance_valid(area.get_parent()) and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, penetration)

func _on_body_entered(body: Node2D) -> void:
	if _hit_set.has(body):
		return
	_hit_set.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage, penetration)

func _make_circle(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in POINT_COUNT:
		var angle := TAU * float(i) / float(POINT_COUNT)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
