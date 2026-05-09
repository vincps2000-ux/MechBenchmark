# railgun.gd — Charge-and-release hitscan weapon.
#
# Hold the fire button to charge over CHARGE_TIME seconds.
# Release to fire: a hitscan ray pierces ALL enemies on the line.
# The weapon sprite glows and grows as charge accumulates.
class_name Railgun
extends Node2D

const BEAM_SCENE  := preload("res://scenes/weapons/railgun_beam.tscn")
const MAX_RANGE   := 1000000.0
const HIT_MASK    := 2 | 16    # layer 2 = enemies + layer 5 = obstacles
const CHARGE_TIME := 1.5        # seconds to reach full charge (1.0)
const MIN_CHARGE  := 0.35       # fraction of charge needed to fire at all
## Total energy consumed while charging from 0 → full.
const CHARGE_ENERGY_TOTAL := 15.0
## Energy drained per second while holding a full charge.
const HOLD_ENERGY_PER_SECOND := 5.0

## Idle weapon sprite colour (no charge).
const COLOR_IDLE   := Color(1.00, 1.00, 1.00, 1.0)
## Weapon sprite colour at maximum charge — bright blue-white glow.
const COLOR_FULL   := Color(0.45, 0.85, 1.00, 1.0)

var _weapon_sprite: Sprite2D = null

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D

## Normalised charge level: 0.0 = empty, 1.0 = full.
var _charge: float = 0.0
## Damage dealt per hit at full charge; partial charge scales linearly.
var _damage: int   = 80
## Maximum number of enemies the beam pierces (safety cap on loop iterations).
var _pierce: int   = 16
## Base armour penetration; scales with charge (7 base, up to 9 at full).
var _penetration: int = 7
## InputMap action name for firing this weapon.
var fire_action: String = "fire"

func _find_energy_owner() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("has_energy_for") and node.has_method("consume_energy"):
			return node
		node = node.get_parent()
	return null

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage = data.damage
	_pierce = data.pierce
	_penetration = data.penetration
	WeaponAttachment.mount_from_data(self, data)

func _process(delta: float) -> void:
	if InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action):
		var owner := _find_energy_owner()
		if _charge < 1.0:
			# Charging phase: consume energy proportional to charge rate.
			var cost := (CHARGE_ENERGY_TOTAL / CHARGE_TIME) * delta
			if owner == null or owner.call("has_energy_for", cost):
				if owner != null:
					owner.call("consume_energy", cost)
				_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
			# If no energy, charge simply doesn't increase.
		else:
			# Holding at full charge: drain 5 energy/s; auto-fire if empty.
			var hold_cost := HOLD_ENERGY_PER_SECOND * delta
			if owner != null and not owner.call("has_energy_for", hold_cost):
				_shoot()
				_charge = 0.0
			else:
				if owner != null:
					owner.call("consume_energy", hold_cost)
	else:
		# Release — fire if we have enough charge, then always reset.
		if _charge >= MIN_CHARGE:
			_shoot()
		_charge = 0.0

	_update_charge_visual()

# ─── Charge visual ────────────────────────────────────────────────────────────
func _update_charge_visual() -> void:
	if not is_instance_valid(_weapon_sprite):
		return

	# Colour cross-fade: white → bright cyan
	_weapon_sprite.modulate = COLOR_IDLE.lerp(COLOR_FULL, _charge)

	# Sprite grows slightly and pulses rapidly at high charge to signal readiness.
	var base_scale := 1.0 + _charge * 0.30
	if _charge > 0.8:
		# Add a pulse ring on top of the base grow
		var pulse := sin(Time.get_ticks_msec() * 0.025) * 0.08 * _charge
		base_scale += pulse
	_weapon_sprite.scale = Vector2(base_scale, base_scale)

# ─── Hitscan ─────────────────────────────────────────────────────────────────
func _shoot() -> void:
	var fire_dir   : Vector2 = global_transform.x
	var muzzle_pos : Vector2 = global_position + fire_dir * 14.0
	var end_pos    : Vector2 = muzzle_pos + fire_dir * MAX_RANGE

	var space    := get_world_2d().direct_space_state
	var excluded : Array[RID] = []

	# Successive raycasts with an expanding exclusion list to pierce enemies.
	for _i in _pierce:
		var query := PhysicsRayQueryParameters2D.create(muzzle_pos, end_pos)
		query.collision_mask      = HIT_MASK
		query.collide_with_areas  = true
		query.collide_with_bodies = true   # detect obstacle StaticBody2D
		query.exclude             = excluded

		var result := space.intersect_ray(query)
		if result.is_empty():
			break

		var collider = result["collider"]
		# Obstacle blocks the beam — stop piercing
		if collider is StaticBody2D:
			end_pos = result["position"]
			break
		if collider.has_method("take_damage"):
			var pen := _penetration + int(2.0 * _charge)
			collider.take_damage(int(_damage * _charge), pen)
		excluded.append(collider.get_rid())

	# Spawn beam visual at the scene root so it renders above everything.
	var beam := BEAM_SCENE.instantiate()
	get_tree().root.add_child(beam)
	beam.call("fire", muzzle_pos, end_pos, _charge)

	# Reset sprite immediately so charge glow vanishes on fire.
	_weapon_sprite.modulate = COLOR_IDLE
	_weapon_sprite.scale    = Vector2.ONE

func stop_firing() -> void:
	_charge = 0.0
	_update_charge_visual()

func get_charge_ratio() -> float:
	return _charge

func get_max_range() -> float:
	return MAX_RANGE
