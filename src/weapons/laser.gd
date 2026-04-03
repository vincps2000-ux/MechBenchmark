# laser.gd — Continuous laser weapon: fires while right mouse button is held
class_name Laser
extends Node2D

const BEAM_SCENE := preload("res://scenes/weapons/laser_beam.tscn")
const MAX_RANGE  := 900.0
## Collision layer bits to test against (layer 2 = enemies + layer 5 = obstacles)
const HIT_MASK   := 2 | 16

## The live beam visual while firing; null when not firing
var _beam: Node2D = null
## Track the last collider hit so we don't re-hit the same target every frame
var _last_hit: Object = null
## Damage dealt per hit, configured via setup()
var _damage: int = 12
## Armour penetration value, configured via setup()
var _penetration: int = 3

## Called by PlayerController right after instantiation to wire up WeaponData.
func setup(data: WeaponData) -> void:
	_damage = data.damage
	_penetration = data.penetration

func _process(_delta: float) -> void:
	if Input.is_action_pressed("fire"):
		_fire_continuous()
	else:
		_stop_beam()

func _fire_continuous() -> void:
	# Muzzle tip: 14 px forward along the weapon's +X axis in world space
	var fire_dir   : Vector2 = global_transform.x
	var muzzle_pos : Vector2 = global_position + fire_dir * 14.0
	var target_pos : Vector2 = muzzle_pos + fire_dir * MAX_RANGE

	# Instant-hit raycast — only test areas (targets are Area2D nodes)
	var space := get_world_2d().direct_space_state
	var query  := PhysicsRayQueryParameters2D.create(muzzle_pos, target_pos)
	query.collision_mask      = HIT_MASK
	query.collide_with_areas  = true
	query.collide_with_bodies = true   # detect obstacle StaticBody2D

	var result := space.intersect_ray(query)

	var hit_pos: Vector2
	if result.is_empty():
		hit_pos = target_pos
		_last_hit = null
	else:
		hit_pos = result["position"]
		var collider = result["collider"]
		# If we hit an obstacle (StaticBody2D), just stop the beam there
		if collider is StaticBody2D:
			_last_hit = null
		else:
			# One-shot: only call take_damage once per unique target
			if collider != _last_hit:
				_last_hit = collider
				if collider.has_method("take_damage"):
					collider.take_damage(_damage, _penetration)

	# Create beam on first frame, then update its endpoints each subsequent frame
	if _beam == null or not is_instance_valid(_beam):
		_beam = BEAM_SCENE.instantiate()
		get_tree().root.add_child(_beam)
		(_beam as Node2D).call("fire", muzzle_pos, hit_pos)
	else:
		(_beam as Node2D).call("update_beam", muzzle_pos, hit_pos)

func _stop_beam() -> void:
	if _beam != null and is_instance_valid(_beam):
		(_beam as Node2D).call("stop")
		_beam = null
	_last_hit = null

func stop_firing() -> void:
	_stop_beam()
