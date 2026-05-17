# laser.gd — Continuous laser weapon: fires while right mouse button is held
class_name Laser
extends Node2D

const BEAM_SCENE := preload("res://scenes/weapons/laser_beam.tscn")
const MAX_RANGE  := 900.0
## Collision layer bits to test against (layer 2 = enemies + layer 5 = obstacles)
const HIT_MASK   := 2 | 16
const COOL_OFF_DURATION := 0.85
const RESTART_ENERGY := 8.0

## Per-intensity stats: [energy_cost_per_second, damage, penetration].
## Index matches laser_intensity value (0 = Flicker … 4 = Overload).
const _INTENSITY_STATS := [
	[2.0,  2,  1],  # 0 — Flicker  (infantry-only)
	[8.0,  5,  2],  # 1 — Low
	[20.0, 12, 3],  # 2 — Standard (default)
	[35.0, 22, 5],  # 3 — High
	[50.0, 35, 8],  # 4 — Overload (huge penetration & damage)
]

var _energy_cost_per_second: float = 20.0

## The live beam visual while firing; null when not firing
var _beam: Node2D = null
## Track the last collider hit so we don't re-hit the same target every frame
var _last_hit: Object = null
## Damage dealt per hit, configured via setup()
var _damage: int = 12
## Armour penetration value, configured via setup()
var _penetration: int = 3
## InputMap action name for firing this weapon.
var fire_action: String = "fire"
var _cool_off_timer: float = 0.0
var _needs_restart_charge: bool = false
## Current intensity level (0–4); set by setup() from WeaponData.laser_intensity.
var _intensity: int = 2

## Returns the per-intensity stats array for a given intensity level (clamped 0–4).
static func get_stats_for_intensity(level: int) -> Array:
	var idx := clampi(level, 0, 4)
	return [
		[2.0,  2,  1],
		[8.0,  5,  2],
		[20.0, 12, 3],
		[35.0, 22, 5],
		[50.0, 35, 8],
	][idx]

## Called by PlayerController right after instantiation to wire up WeaponData.
func setup(data: WeaponData) -> void:
	var stats := get_stats_for_intensity(data.laser_intensity)
	_energy_cost_per_second = stats[0]
	_damage      = stats[1]
	_penetration = stats[2]
	_intensity   = data.laser_intensity
	WeaponAttachment.mount_from_data(self, data)

func _process(delta: float) -> void:
	_update_cool_off(delta)
	if InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action):
		if _can_resume_fire() and _try_consume_energy(delta):
			_fire_continuous()
		else:
			if _can_resume_fire():
				_enter_cool_off()
			_stop_beam()
	else:
		_stop_beam()

func get_energy_cost_per_second() -> float:
	return _energy_cost_per_second

func get_cool_off_duration() -> float:
	return COOL_OFF_DURATION

func _try_consume_energy(delta: float) -> bool:
	var owner := _find_energy_owner()
	if owner == null:
		return true
	var energy_cost := _energy_cost_per_second * delta
	if not owner.call("has_energy_for", energy_cost):
		return false
	return bool(owner.call("consume_energy", energy_cost))

func _find_energy_owner() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("has_energy_for") and node.has_method("consume_energy"):
			return node
		node = node.get_parent()
	return null

func _update_cool_off(delta: float) -> void:
	if _cool_off_timer > 0.0:
		_cool_off_timer = maxf(0.0, _cool_off_timer - delta)

func _can_resume_fire() -> bool:
	if _cool_off_timer > 0.0:
		return false
	if not _needs_restart_charge:
		return true
	var owner := _find_energy_owner()
	if owner == null:
		_needs_restart_charge = false
		return true
	if owner.call("has_energy_for", RESTART_ENERGY):
		_needs_restart_charge = false
		return true
	return false

func _enter_cool_off() -> void:
	_cool_off_timer = COOL_OFF_DURATION
	_needs_restart_charge = true

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
		(_beam as Node2D).call("set_intensity", _intensity)
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
