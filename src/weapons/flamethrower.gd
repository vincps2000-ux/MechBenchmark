# flamethrower.gd — Cone flame weapon: fires while left mouse button is held.
# Casts a fan of raycasts across a 50° cone, one-shotting anything in range.
# A Polygon2D child animates the flame with flickering edges and colour cycling.
class_name Flamethrower
extends Node2D

const MAX_RANGE  := 240.0
const CONE_ANGLE := 0.873    # ≈ 50 degrees in radians
const RAY_COUNT  := 11       # raycasts spread across the cone
const HIT_MASK   := 2        # layer 2 = enemies / targets

@onready var _flame_poly:  Polygon2D = $FlamePoly
@onready var _flame_inner: Polygon2D = $FlameInner

var _firing: bool  = false
var _time:   float = 0.0## Damage dealt per cone ray hit, configured via setup()
var _damage: int = 3

## Called by PlayerController right after instantiation to wire up WeaponData.
func setup(data: WeaponData) -> void:
	_damage = data.damage
# ─── Per-frame update ─────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	_firing = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

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

	for i in RAY_COUNT:
		var t     := float(i) / float(RAY_COUNT - 1)
		var angle : float = base_angle + lerp(-half, half, t)
		var dir   := Vector2.from_angle(angle)
		var end   := muzzle_pos + dir * MAX_RANGE

		var query := PhysicsRayQueryParameters2D.create(muzzle_pos, end)
		query.collision_mask      = HIT_MASK
		query.collide_with_areas  = true
		query.collide_with_bodies = false

		var result := space.intersect_ray(query)
		if not result.is_empty():
			var collider = result["collider"]
			if is_instance_valid(collider) and not already_hit.has(collider):
				already_hit.append(collider)
				if collider.has_method("take_damage"):
					collider.take_damage(_damage)

# ─── Flame visual ─────────────────────────────────────────────────────────────
# Builds a cone polygon in the weapon's own local space (+X = forward).
# Outer and inner polygons give a hollow-cone look and depth variation.
func _animate_flame() -> void:
	_flame_poly.visible  = _firing
	_flame_inner.visible = _firing
	if not _firing:
		return

	var half      : float = CONE_ANGLE * 0.5
	var seg_count : int   = 16

	# Outer cone — slightly irregular edge to look flame-like
	var outer := PackedVector2Array()
	outer.append(Vector2.ZERO)
	for i in seg_count + 1:
		var t     := float(i) / float(seg_count)
		var angle : float = lerp(-half, half, t)
		# Vary radius per segment using two slightly offset sin waves
		var r : float = MAX_RANGE * (0.80 + 0.20 * sin(_time * 14.0 + t * TAU))
		outer.append(Vector2.from_angle(angle) * r)
	_flame_poly.polygon = outer

	# Inner hot-core cone — shorter, brighter
	var inner := PackedVector2Array()
	inner.append(Vector2.ZERO)
	for i in seg_count + 1:
		var t     := float(i) / float(seg_count)
		var angle : float = lerp(-half * 0.55, half * 0.55, t)
		var r : float = MAX_RANGE * 0.55 * (0.75 + 0.25 * sin(_time * 22.0 + t * TAU + 1.0))
		inner.append(Vector2.from_angle(angle) * r)
	_flame_inner.polygon = inner

	# Outer colour: flicker between deep orange and bright yellow-orange
	var flicker_outer : float = 0.5 + 0.5 * sin(_time * 20.0)
	_flame_poly.color = Color(1.0, 0.30 + 0.35 * flicker_outer, 0.0, 0.50 + 0.15 * flicker_outer)

	# Inner colour: bright near-white yellow core
	var flicker_inner : float = 0.5 + 0.5 * sin(_time * 30.0 + 0.8)
	_flame_inner.color = Color(1.0, 0.75 + 0.20 * flicker_inner, 0.1, 0.70 + 0.15 * flicker_inner)
