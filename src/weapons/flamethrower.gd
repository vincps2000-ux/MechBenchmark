# flamethrower.gd — Cone flame weapon with randomized geometry.
# Casts a fan of raycasts across a 50° cone for hit detection.
# Visuals: a chaotic outer cone (per-segment independent noise) plus
# TONGUE_COUNT individual flame-streamer polygons, each randomly
# parameterised and animated with its own phase / frequency.
class_name Flamethrower
extends Node2D

const MAX_RANGE    := 240.0
const CONE_ANGLE   := 0.873   # ≈ 50 degrees in radians
const RAY_COUNT    := 11      # raycasts spread across the cone
const HIT_MASK     := 2 | 16  # layer 2 = enemies + layer 5 = obstacles

const SEG_COUNT    := 20      # vertices along the outer cone arc
const TONGUE_COUNT := 8       # individual flame-streamer polygons

@onready var _flame_poly:  Polygon2D = $FlamePoly
@onready var _flame_inner: Polygon2D = $FlameInner

var _firing: bool  = false
var _time:   float = 0.0
## Damage dealt per cone ray hit, configured via setup()
var _damage: int = 3
## Armour penetration value, configured via setup()
var _penetration: int = 2

# ── Per-segment independent noise parameters (set once in _ready) ─────────────
var _seg_freq_a:  Array[float] = []   # fast oscillation frequency per segment
var _seg_phase_a: Array[float] = []   # fast oscillation phase offset
var _seg_freq_b:  Array[float] = []   # slow oscillation frequency per segment
var _seg_phase_b: Array[float] = []   # slow oscillation phase offset

# ── Flame tongue nodes (added as children in _ready) ─────────────────────────
var _tongues:           Array[Polygon2D] = []
var _tongue_base_angle: Array[float]     = []  # resting angle within cone
var _tongue_length:     Array[float]     = []  # max length as fraction of MAX_RANGE
var _tongue_phase:      Array[float]     = []  # personal time offset
var _tongue_freq:       Array[float]     = []  # oscillation speed
var _tongue_width:      Array[float]     = []  # half-width at muzzle end

var _rng := RandomNumberGenerator.new()

## Per-angle obstacle distances (updated each firing frame by _fire_cone).
## Maps segment-index → max local-space distance the flame can reach.
var _obstacle_ranges: Array[float] = []

func _ready() -> void:
	_rng.seed = 0xF1A4E  # fixed seed — same "personality" every run

	# Generate per-segment noise parameters
	for _i in SEG_COUNT + 1:
		_seg_freq_a.append(_rng.randf_range(12.0, 24.0))
		_seg_phase_a.append(_rng.randf_range(0.0, TAU))
		_seg_freq_b.append(_rng.randf_range(4.0, 9.0))
		_seg_phase_b.append(_rng.randf_range(0.0, TAU))

	# Spawn tongue polygons and assign random parameters
	var half := CONE_ANGLE * 0.5
	for _i in TONGUE_COUNT:
		var poly := Polygon2D.new()
		poly.z_index = 5
		poly.visible = false
		add_child(poly)
		_tongues.append(poly)
		_tongue_base_angle.append(_rng.randf_range(-half, half))
		_tongue_length.append(_rng.randf_range(0.50, 1.00))
		_tongue_phase.append(_rng.randf_range(0.0, TAU))
		_tongue_freq.append(_rng.randf_range(6.0, 15.0))
		_tongue_width.append(_rng.randf_range(6.0, 18.0))

## Called by PlayerController right after instantiation to wire up WeaponData.
func setup(data: WeaponData) -> void:
	_damage = data.damage
	_penetration = data.penetration

func stop_firing() -> void:
	_firing = false
	_flame_poly.visible  = false
	_flame_inner.visible = false
	for poly in _tongues:
		poly.visible = false

# ─── Per-frame update ─────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	_firing = Input.is_action_pressed("fire")

	if _firing:
		_fire_cone()

	_animate_flame()

# ─── Raycast fan ─────────────────────────────────────────────────────────────
func _fire_cone() -> void:
	var fire_dir   : Vector2 = global_transform.x          # world-space forward
	var muzzle_pos : Vector2 = global_position + fire_dir * 14.0
	var base_angle : float   = fire_dir.angle()
	var half       : float   = CONE_ANGLE * 0.5

	var space := get_world_2d().direct_space_state
	var already_hit: Array = []

	# ── First pass: find obstacle distances per visual segment ──────────────
	# Cast one ray per visual segment against bodies only to find the nearest
	# obstacle distance at each angle.  The flame visuals will be clamped to
	# these distances so they no longer draw through walls.
	_obstacle_ranges.clear()
	for i in SEG_COUNT + 1:
		var t     : float = float(i) / float(SEG_COUNT)
		var angle : float = base_angle + lerp(-half, half, t)
		var dir   := Vector2.from_angle(angle)
		var end   := muzzle_pos + dir * MAX_RANGE

		var oq := PhysicsRayQueryParameters2D.create(muzzle_pos, end)
		oq.collision_mask      = 16   # obstacles only
		oq.collide_with_areas  = false
		oq.collide_with_bodies = true

		var oresult := space.intersect_ray(oq)
		if oresult.is_empty():
			_obstacle_ranges.append(MAX_RANGE)
		else:
			var hit_dist: float = (oresult["position"] as Vector2 - muzzle_pos).length()
			_obstacle_ranges.append(hit_dist)

	# ── Second pass: damage raycasts (enemies + obstacles) ──────────────────
	for i in RAY_COUNT:
		var t     := float(i) / float(RAY_COUNT - 1)
		var angle : float = base_angle + lerp(-half, half, t)
		var dir   := Vector2.from_angle(angle)
		var end   := muzzle_pos + dir * MAX_RANGE

		var query := PhysicsRayQueryParameters2D.create(muzzle_pos, end)
		query.collision_mask      = HIT_MASK
		query.collide_with_areas  = true
		query.collide_with_bodies = true   # detect obstacle StaticBody2D

		var result := space.intersect_ray(query)
		if not result.is_empty():
			var collider = result["collider"]
			# Skip obstacles — they block the flame but don't take damage
			if collider is StaticBody2D:
				continue
			if is_instance_valid(collider) and not already_hit.has(collider):
				already_hit.append(collider)
				if collider.has_method("take_damage"):
					collider.take_damage(_damage, _penetration)

# ─── Flame visuals ────────────────────────────────────────────────────────────
func _animate_flame() -> void:
	_flame_poly.visible  = _firing
	_flame_inner.visible = _firing
	for poly in _tongues:
		poly.visible = _firing
	if not _firing:
		return

	var half : float = CONE_ANGLE * 0.5

	# ── Outer cone: every arc vertex has its own noise pair ───────────────────
	# Each segment blends a fast + slow sin wave with unique freq & phase, so
	# no two adjacent edges move in sync — gives a genuinely ragged boundary.
	# Determine per-segment max reach (clamped by obstacles if data available)
	var seg_max: Array[float] = []
	for i in SEG_COUNT + 1:
		if i < _obstacle_ranges.size():
			seg_max.append(_obstacle_ranges[i])
		else:
			seg_max.append(MAX_RANGE)

	var outer := PackedVector2Array()
	outer.append(Vector2.ZERO)
	for i in SEG_COUNT + 1:
		var t     : float = float(i) / float(SEG_COUNT)
		var angle : float = lerp(-half, half, t)
		var r : float = MAX_RANGE * (
			0.62
			+ 0.20 * sin(_time * _seg_freq_a[i]  + _seg_phase_a[i])
			+ 0.11 * sin(_time * _seg_freq_b[i]  + _seg_phase_b[i])
			+ 0.07 * sin(_time * 37.0             + float(i) * 0.83)
		)
		# Clamp to obstacle distance at this angle
		r = minf(r, seg_max[i])
		outer.append(Vector2.from_angle(angle) * r)
	_flame_poly.polygon = outer

	# ── Inner hot-core cone: narrower arc, independent per-segment noise ──────
	var inner := PackedVector2Array()
	inner.append(Vector2.ZERO)
	for i in SEG_COUNT + 1:
		var t     : float = float(i) / float(SEG_COUNT)
		var angle : float = lerp(-half * 0.48, half * 0.48, t)
		var r : float = MAX_RANGE * 0.52 * (
			0.68
			+ 0.22 * sin(_time * _seg_freq_a[i] * 1.4  + _seg_phase_a[i] + 0.9)
			+ 0.10 * sin(_time * 29.0                   + float(i) * 1.1)
		)
		# Clamp inner cone to obstacle distance too
		r = minf(r, seg_max[i] * 0.95)
		inner.append(Vector2.from_angle(angle) * r)
	_flame_inner.polygon = inner

	# ── Flame tongues: individual narrow streamers ────────────────────────────
	# Each tongue is a tapered 5-point polygon (wide at root, pointed at tip)
	# that drifts in angle and pulses in length over time.
	for i in TONGUE_COUNT:
		var poly : Polygon2D = _tongues[i]

		# Angle drifts gently side-to-side
		var angle_drift := 0.07 * sin(_time * _tongue_freq[i] + _tongue_phase[i])
		var angle := _tongue_base_angle[i] + angle_drift

		# Length breathes on a different phase so it feels alive
		var len_frac : float = _tongue_length[i] * (
			0.72 + 0.28 * sin(_time * _tongue_freq[i] * 1.15 + _tongue_phase[i] + 1.2)
		)
		var r   : float   = MAX_RANGE * len_frac
		# Clamp tongue to the nearest obstacle along its angle
		var tongue_seg_idx: int = clampi(int((angle / half * 0.5 + 0.5) * SEG_COUNT), 0, seg_max.size() - 1)
		r = minf(r, seg_max[tongue_seg_idx])
		var hw  : float   = _tongue_width[i]
		var fwd : Vector2 = Vector2.from_angle(angle)
		var perp: Vector2 = fwd.rotated(PI * 0.5)

		# 5-point teardrop: origin → left mid-bulge → tip → right mid-bulge → origin
		var pts := PackedVector2Array()
		pts.append(perp *  hw * 0.45)                   # base left
		pts.append(fwd * r * 0.28 + perp * hw * 0.90)  # left mid-bulge
		pts.append(fwd * r)                             # tip
		pts.append(fwd * r * 0.28 - perp * hw * 0.90)  # right mid-bulge
		pts.append(perp * -hw * 0.45)                   # base right
		poly.polygon = pts

		# Colour: shorter tongues are more orange; longer ones bleed into yellow
		var heat     : float = len_frac                 # 0 = cool/short, 1 = hot/long
		var flicker  : float = 0.5 + 0.5 * sin(_time * _tongue_freq[i] * 2.0 + _tongue_phase[i])
		poly.color = Color(
			1.0,
			0.35 + 0.40 * heat + 0.10 * flicker,
			0.02 + 0.10 * heat,
			0.35 + 0.20 * flicker
		)

	# ── Global base-cone colour flicker ──────────────────────────────────────
	var f_outer : float = 0.5 + 0.5 * sin(_time * 19.0)
	_flame_poly.color = Color(1.0, 0.26 + 0.28 * f_outer, 0.0, 0.42 + 0.13 * f_outer)

	var f_inner : float = 0.5 + 0.5 * sin(_time * 34.0 + 0.8)
	_flame_inner.color = Color(1.0, 0.72 + 0.18 * f_inner, 0.08, 0.65 + 0.14 * f_inner)
