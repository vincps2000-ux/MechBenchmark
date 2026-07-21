# artillery.gd — Long-range bombardment weapon.
#
# Holding the fire button paints a targeting reticle at the cursor.  Because the
# heavy gun cannot lob a shell sideways, it may only fire while the barrel is
# pointed close to the cursor direction — the reticle turns GREEN when a strike
# is possible and RED/AMBER otherwise.  Each launch drops an ArtilleryStrike
# somewhere inside the aim circle (shells scatter), which fills with red and
# then detonates in one huge explosion.
#
# Magazine: 5 shells.
class_name Artillery
extends Node2D

const STRIKE_SCRIPT := preload("res://src/weapons/artillery_strike.gd")
const TARGETER_SCRIPT := preload("res://src/weapons/artillery_targeter.gd")

## Number of shells in the magazine.
const MAX_AMMO := 5
## Seconds between launches.
const FIRE_INTERVAL := 1.1
## How close (radians) the barrel must point to the cursor before firing.
const ALIGNMENT_TOLERANCE := deg_to_rad(14.0)
## Radius of the projected blast footprint in pixels.
const BLAST_RADIUS := 150.0
## Maximum distance a shell may land from the aim point (impact scatter).
const SCATTER_RADIUS := 55.0
## Seconds the strike marker fills before detonating.
const FILL_TIME := 1.5
## Closest a strike may be dropped relative to the gun (avoids self-bombing).
const MIN_TARGET_DISTANCE := 32.0

## Reticle colours per fire state.
const COLOR_READY := Color(0.30, 1.00, 0.40, 0.95)   # green — clear to fire
const COLOR_MISALIGNED := Color(1.00, 0.30, 0.25, 0.95)  # red — barrel not on target
const COLOR_COOLDOWN := Color(1.00, 0.78, 0.20, 0.95)    # amber — reloading
const COLOR_NO_AMMO := Color(0.55, 0.55, 0.55, 0.85)     # grey — empty

enum FireState { READY, MISALIGNED, COOLDOWN, NO_AMMO }

var _weapon_sprite: Sprite2D = null
var _targeter: Node2D = null

var _damage: int = 120
var _penetration: int = 8
var _blast_radius: float = BLAST_RADIUS
var _scatter_radius: float = SCATTER_RADIUS
var _fill_time: float = FILL_TIME
var _cooldown: float = 0.0
var _ammo_current: int = MAX_AMMO
var _ammo_capacity: int = MAX_AMMO

## InputMap action name for firing this weapon.
var fire_action: String = "fire"
## Collision layer(s) the spawned explosions should damage (2 = enemies).
var explosion_target_mask: int = 2
## Kept for parity with other weapons / external targeting overrides.
var projectile_target_mask: int = 2

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D
	_targeter = TARGETER_SCRIPT.new()
	_targeter.top_level = true
	_targeter.visible = false
	add_child(_targeter)

func setup(data: WeaponData) -> void:
	_damage = data.damage
	_penetration = data.penetration
	if data.area > 0.0:
		_blast_radius = BLAST_RADIUS * data.area
		_scatter_radius = SCATTER_RADIUS * data.area
	_ammo_capacity = MAX_AMMO
	_ammo_current = _ammo_capacity
	WeaponAttachment.mount_from_data(self, data)

## Called by PlayerController when this weapon must hold fire (deadspot/drone).
func stop_firing() -> void:
	_hide_preview()

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)

	var trigger_pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)
	if not trigger_pressed:
		_hide_preview()
		return

	_update_preview()
	if compute_fire_state() == FireState.READY:
		fire_at(get_global_mouse_position())

# ─── Targeting preview ────────────────────────────────────────────────────────
func _update_preview() -> void:
	if not is_instance_valid(_targeter):
		return
	_targeter.visible = true
	_targeter.global_position = get_global_mouse_position()
	# Keep the reticle world-aligned regardless of how the turret is rotated.
	_targeter.global_rotation = 0.0
	_targeter.configure(_blast_radius, state_color(compute_fire_state()), _scatter_radius)

func _hide_preview() -> void:
	if is_instance_valid(_targeter):
		_targeter.visible = false

# ─── Fire-state machine ───────────────────────────────────────────────────────
func compute_fire_state() -> FireState:
	if not has_ammo():
		return FireState.NO_AMMO
	if _cooldown > 0.0:
		return FireState.COOLDOWN
	if not is_aligned_to(get_global_mouse_position()):
		return FireState.MISALIGNED
	return FireState.READY

func state_color(state: FireState) -> Color:
	match state:
		FireState.READY:      return COLOR_READY
		FireState.MISALIGNED: return COLOR_MISALIGNED
		FireState.COOLDOWN:   return COLOR_COOLDOWN
		_:                    return COLOR_NO_AMMO

## True when the barrel points within ALIGNMENT_TOLERANCE of the target.
func is_aligned_to(target: Vector2) -> bool:
	var to_target := target - global_position
	if to_target.length() < MIN_TARGET_DISTANCE:
		return false
	var aim := global_transform.x
	return absf(aim.angle_to(to_target)) <= ALIGNMENT_TOLERANCE

# ─── Firing ───────────────────────────────────────────────────────────────────
func can_fire() -> bool:
	return _cooldown <= 0.0 and has_ammo()

## Launch a strike at the given world position, ignoring barrel alignment.
## The shell scatters randomly within SCATTER_RADIUS of the aim point.
## Returns true if a shell was spent.
func fire_at(target: Vector2) -> bool:
	if not can_fire():
		return false
	_ammo_current -= 1
	_cooldown = FIRE_INTERVAL
	_spawn_strike(target + random_scatter_offset())
	AudioEventSystem.play_weapon_fire(global_position, AudioEventSystem.WeaponSound.ROCKET)
	return true

## Returns a uniformly distributed random offset within the scatter disc.
func random_scatter_offset() -> Vector2:
	if _scatter_radius <= 0.0:
		return Vector2.ZERO
	var angle := randf() * TAU
	var dist := sqrt(randf()) * _scatter_radius
	return Vector2.from_angle(angle) * dist

func _spawn_strike(target: Vector2) -> void:
	var strike: Node2D = STRIKE_SCRIPT.new()
	strike.blast_radius = _blast_radius
	strike.fill_time = _fill_time
	strike.damage = _damage
	strike.penetration = _penetration
	strike.target_collision_mask = explosion_target_mask

	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(strike)
	strike.global_position = target
	strike.global_rotation = 0.0

# ─── Ammo API ─────────────────────────────────────────────────────────────────
func get_ammo_count() -> int:
	return _ammo_current

func get_ammo_capacity() -> int:
	return _ammo_capacity

func set_ammo_capacity_multiplier(multiplier: float) -> void:
	_ammo_capacity = maxi(1, int(round(float(MAX_AMMO) * maxf(multiplier, 0.0))))
	_ammo_current = _ammo_capacity

func has_ammo() -> bool:
	return _ammo_current > 0

func is_out_of_ammo() -> bool:
	return not has_ammo()
