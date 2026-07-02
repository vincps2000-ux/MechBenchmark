# artillery_strike.gd — Delayed artillery bombardment marker.
#
# Spawned at the targeted world position by the Artillery weapon.  Draws a large
# danger circle that is slowly filled with transparent red over `fill_time`
# seconds, giving enemies (and the player) a window to clear the zone.  When the
# fill completes the marker detonates in one huge area-of-effect explosion.
class_name ArtilleryStrike
extends Node2D

const EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")

## Radius of the danger zone / final blast in pixels.
var blast_radius: float = 150.0
## Seconds the marker takes to fill before detonating.
var fill_time: float = 1.5
## Damage dealt by the final explosion.
var damage: int = 120
## Armour penetration of the final explosion.
var penetration: int = 8
## Collision layer(s) the explosion should damage (2 = enemies, 1 = player).
var target_collision_mask: int = 2

## Outline colour of the warning ring.
const COLOR_RING := Color(0.95, 0.20, 0.15, 0.85)
## Fully-filled red tint (kept transparent so the field stays readable).
const COLOR_FILL := Color(0.90, 0.10, 0.08, 0.45)
const POINT_COUNT := 64

var _elapsed: float = 0.0
var _detonated: bool = false

func _ready() -> void:
	add_to_group("level_effect")
	add_to_group("artillery_strike")
	z_index = 9
	queue_redraw()

func _process(delta: float) -> void:
	if _detonated:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= fill_time:
		_detonate()

## Progress of the fill from 0.0 (just spawned) to 1.0 (about to detonate).
func get_fill_ratio() -> float:
	if fill_time <= 0.0:
		return 1.0
	return clampf(_elapsed / fill_time, 0.0, 1.0)

func _draw() -> void:
	var t := get_fill_ratio()

	# Inner fill grows outward and deepens in opacity as the timer runs down.
	var fill_radius := blast_radius * t
	if fill_radius > 0.5:
		var fill := COLOR_FILL
		fill.a = COLOR_FILL.a * (0.25 + 0.75 * t)
		draw_circle(Vector2.ZERO, fill_radius, fill)

	# Static danger ring marking the full blast footprint.
	var ring := COLOR_RING
	# Pulse the ring brighter as detonation approaches.
	ring.a = clampf(0.55 + 0.45 * t, 0.0, 1.0)
	draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, POINT_COUNT, ring, 3.0, true)

	# Cross-hair to mark the impact point.
	var arm := blast_radius * 0.18
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), ring, 2.0, true)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), ring, 2.0, true)

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true

	var explosion: Node = EXPLOSION_SCENE.instantiate()
	explosion.damage = damage
	explosion.penetration = penetration
	explosion.target_collision_mask = target_collision_mask
	explosion.blast_scale = maxf(0.2, blast_radius / AutocannonExplosion.MAX_RADIUS)

	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(explosion)
	explosion.global_position = global_position

	queue_free()
