# c4_launcher.gd — Light C4 charge launcher with manual remote detonation.
#
# TAP the fire action  → toss a sticky C4 charge that slides to a stop
#                        and sits armed, LED blinking.
# HOLD the fire action → squeeze the clacker: every placed charge goes up
#                        in a huge rippling detonation.
# Only 5 charges — make them count.  Fits medium & light weapon slots.
class_name C4Launcher
extends Node2D

const CHARGE_SCENE := preload("res://scenes/weapons/c4_charge.tscn")

## Hold the trigger this long to detonate instead of throwing.
const HOLD_DETONATE_TIME := 0.3
## Minimum time between charge throws.
const THROW_INTERVAL     := 0.4
## Launch speed of a tossed charge in pixels per second.
const PROJECTILE_SPEED   := 260.0
## How far from the mount the charge spawns.
const MUZZLE_DISTANCE    := 10.0
## Ripple delay between charges when detonating several at once.
const RIPPLE_DELAY       := 0.08
## Recoil squash applied to the sprite on each throw.
const RECOIL_SCALE       := Vector2(0.8, 1.25)
## How fast the sprite springs back from recoil.
const RECOIL_RECOVER_SPEED := 6.0
const MAX_AMMO := 5

var _weapon_sprite: Sprite2D = null
var _sprite_base_scale := Vector2.ONE

var _damage: int = 120
var _penetration: int = 10
var _aoe_scale: float = 3.0
var _throw_interval: float = THROW_INTERVAL
var _projectile_speed: float = PROJECTILE_SPEED

var _cooldown: float = 0.0
var _ammo_current: int = MAX_AMMO
## Charges currently placed in the world, awaiting the clacker.
var _placed_charges: Array = []
## How long the trigger has been held this press.
var _hold_time: float = 0.0
## True once this press already detonated (prevents repeat detonations).
var _detonated_this_press: bool = false
## InputMap action name for firing this weapon.
var fire_action: String = "fire"

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D
	if is_instance_valid(_weapon_sprite):
		_sprite_base_scale = _weapon_sprite.scale

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage           = data.damage
	_penetration      = data.penetration
	_aoe_scale        = data.area
	_throw_interval   = data.cooldown
	_projectile_speed = data.projectile_speed
	_ammo_current     = MAX_AMMO
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	_hold_time = 0.0
	_detonated_this_press = false

func _process(delta: float) -> void:
	_cooldown -= delta

	var pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)
	if pressed:
		_hold_time += delta
		if not _detonated_this_press and _hold_time >= HOLD_DETONATE_TIME:
			detonate_all()
			_detonated_this_press = true
	else:
		# Released: a short press is a throw, a long press already detonated.
		if _hold_time > 0.0 and not _detonated_this_press:
			try_throw_once()
		_hold_time = 0.0
		_detonated_this_press = false

	# Cartoony recoil spring-back
	if is_instance_valid(_weapon_sprite):
		_weapon_sprite.scale = _weapon_sprite.scale.lerp(_sprite_base_scale, minf(1.0, RECOIL_RECOVER_SPEED * delta))

func can_throw() -> bool:
	return _cooldown <= 0.0 and has_ammo()

func try_throw_once() -> bool:
	if not can_throw():
		return false
	_throw_charge()
	_ammo_current -= 1
	_cooldown = _throw_interval
	if is_instance_valid(_weapon_sprite):
		_weapon_sprite.scale = _sprite_base_scale * RECOIL_SCALE
	return true

## Detonate every placed charge with a short ripple between blasts.
## Returns the number of charges detonated.
func detonate_all() -> int:
	var count := 0
	for charge in _placed_charges:
		if is_instance_valid(charge):
			charge.detonate_delayed(RIPPLE_DELAY * count)
			count += 1
	_placed_charges.clear()
	return count

func get_placed_charge_count() -> int:
	var count := 0
	for charge in _placed_charges:
		if is_instance_valid(charge):
			count += 1
	return count

func get_ammo_count() -> int:
	return _ammo_current

func get_ammo_capacity() -> int:
	return MAX_AMMO

func has_ammo() -> bool:
	return _ammo_current > 0

func is_out_of_ammo() -> bool:
	return not has_ammo()

func _throw_charge() -> void:
	var fire_dir: Vector2 = global_transform.x
	var muzzle_pos: Vector2 = global_position + fire_dir * MUZZLE_DISTANCE

	AudioEventSystem.play_weapon_fire(muzzle_pos, AudioEventSystem.WeaponSound.ROCKET)

	var charge: C4Charge = CHARGE_SCENE.instantiate()
	charge.damage      = _damage
	charge.penetration = _penetration
	charge.aoe_scale   = _aoe_scale
	charge.velocity    = fire_dir * _projectile_speed
	charge.global_position = muzzle_pos
	get_tree().root.add_child(charge)
	_placed_charges.append(charge)
