# laser_pointer_attachment.gd — Draws a thin laser beam from the weapon barrel.
# The beam colour is customisable via beam_color.
class_name LaserPointerAttachment
extends WeaponAttachment

## Maximum length of the laser beam in pixels.
var beam_length: float = 600.0

## Width of the laser beam in pixels.
var beam_width: float = 1.5

## Colour of the laser beam.
var beam_color: Color = Color.RED:
	set(value):
		beam_color = value
		queue_redraw()

## Collision mask for the laser pointer raycast (enemies + obstacles).
const HIT_MASK := 2 | 16

func _init() -> void:
	display_name = "Laser Pointer"
	z_index = 4

func _process(_delta: float) -> void:
	if not enabled:
		if visible:
			_update_visibility()
		return
	if not visible:
		_update_visibility()
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return

	# Beam starts at the weapon's muzzle tip (local +X direction).
	var muzzle_offset := Vector2(16.0, 0.0)
	var end_offset := muzzle_offset + Vector2(beam_length, 0.0)

	# Raycast in world space to stop at obstacles/enemies.
	var space := get_world_2d()
	if space == null:
		_draw_beam_line(muzzle_offset, end_offset)
		return

	var dss := space.direct_space_state
	if dss == null:
		_draw_beam_line(muzzle_offset, end_offset)
		return

	var world_start: Vector2 = to_global(muzzle_offset)
	var world_end: Vector2 = to_global(end_offset)

	var query := PhysicsRayQueryParameters2D.create(world_start, world_end)
	query.collision_mask = HIT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := dss.intersect_ray(query)
	if not result.is_empty():
		end_offset = to_local(result["position"])

	_draw_beam_line(muzzle_offset, end_offset)

func _draw_beam_line(from: Vector2, to_pos: Vector2) -> void:
	# Outer glow (wider, semi-transparent).
	var glow_color := beam_color
	glow_color.a = 0.25
	draw_line(from, to_pos, glow_color, beam_width * 3.0, true)

	# Core beam.
	draw_line(from, to_pos, beam_color, beam_width, true)

	# Small dot at the end point.
	var dot_color := beam_color
	dot_color.a = 0.9
	draw_circle(to_pos, beam_width * 2.0, dot_color)
