# railgun.gd — Charge-and-release hitscan weapon.
#
# Hold the fire button to charge over CHARGE_TIME seconds.
# Release to fire: a hitscan ray pierces ALL enemies on the line.
# The weapon sprite glows and grows as charge accumulates.
class_name Railgun
extends Node2D

const BEAM_SCENE  := preload("res://scenes/weapons/railgun_beam.tscn")
const MAX_RANGE   := 1200.0
const HIT_MASK    := 2          # layer 2 = enemies / targets
const CHARGE_TIME := 1.5        # seconds to reach full charge (1.0)
const MIN_CHARGE  := 0.35       # fraction of charge needed to fire at all

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

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage = data.damage
	_pierce = data.pierce

func _process(delta: float) -> void:
	if Input.is_action_pressed("fire"):
		_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
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
		query.collide_with_bodies = false
		query.exclude             = excluded

		var result := space.intersect_ray(query)
		if result.is_empty():
			break

		var collider = result["collider"]
		if collider.has_method("take_damage"):
			collider.take_damage(int(_damage * _charge))
		excluded.append(collider.get_rid())

	# Spawn beam visual at the scene root so it renders above everything.
	var beam := BEAM_SCENE.instantiate()
	get_tree().root.add_child(beam)
	beam.call("fire", muzzle_pos, end_pos, _charge)

	# Reset sprite immediately so charge glow vanishes on fire.
	_weapon_sprite.modulate = COLOR_IDLE
	_weapon_sprite.scale    = Vector2.ONE
