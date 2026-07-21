# pom_pom_gun.gd — Light quad-barrel flak gun with a cartoony rhythm.
#
# Holds the trigger → fires a rhythmic "POM-POM-POM-POM" burst of chunky
# flak shells, then pauses to rewind the ammo belt.  Each shell pops into
# a small airburst at the end of its flight or on impact.
# Fits both medium and light weapon slots.
class_name PomPomGun
extends Node2D

const SHELL_SCENE := preload("res://scenes/weapons/pom_pom_shell.tscn")

## Seconds between shells inside one burst — the "pom-pom" rhythm.
const BURST_INTERVAL   := 0.14
## Seconds of belt-rewind recovery after a burst (from WeaponData.cooldown).
const RECOVERY_TIME    := 0.9
## Shells per burst (from WeaponData.projectile_count).
const BURST_SIZE       := 4
## Speed of fired shells in pixels per second.
const PROJECTILE_SPEED := 440.0
## Random spread in degrees applied to each shell.
const SPREAD_DEG       := 4.0
## How far from the mount the muzzle sits.
const MUZZLE_DISTANCE  := 12.0
## Recoil kick scale applied to the sprite on each shot (cartoony squash).
const RECOIL_SCALE     := 1.22
## How fast the sprite springs back from recoil.
const RECOIL_RECOVER_SPEED := 8.0
const MAX_AMMO := 240

var _weapon_sprite: Sprite2D = null
var _sprite_base_scale := Vector2.ONE

var _damage: int = 6
var _pierce: int = 1
var _penetration: int = 3
var _aoe_scale: float = 0.6
var _burst_size: int = BURST_SIZE
var _recovery_time: float = RECOVERY_TIME
var _projectile_speed: float = PROJECTILE_SPEED

## Shells left in the current burst; 0 = not bursting.
var _burst_remaining: int = 0
## Countdown to the next shell or the end of recovery.
var _cooldown: float = 0.0
var _ammo_current: int = MAX_AMMO
var _ammo_capacity: int = MAX_AMMO
## InputMap action name for firing this weapon.
var fire_action: String = "fire"

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D
	if is_instance_valid(_weapon_sprite):
		_sprite_base_scale = _weapon_sprite.scale

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage           = data.damage
	_pierce           = data.pierce
	_penetration      = data.penetration
	_aoe_scale        = data.area
	_burst_size       = maxi(1, data.projectile_count)
	_recovery_time    = data.cooldown
	_projectile_speed = data.projectile_speed
	_ammo_capacity    = MAX_AMMO
	_ammo_current     = _ammo_capacity
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	pass

func _process(delta: float) -> void:
	_cooldown -= delta

	var trigger_pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)

	if _burst_remaining > 0:
		# Mid-burst: keep the rhythm going regardless of trigger state.
		if _cooldown <= 0.0:
			_fire_shell()
	elif trigger_pressed and can_fire():
		_start_burst()

	# Cartoony recoil spring-back
	if is_instance_valid(_weapon_sprite):
		_weapon_sprite.scale = _weapon_sprite.scale.lerp(_sprite_base_scale, minf(1.0, RECOIL_RECOVER_SPEED * delta))

func can_fire() -> bool:
	return _cooldown <= 0.0 and _burst_remaining == 0 and has_ammo()

func _start_burst() -> void:
	_burst_remaining = mini(_burst_size, _ammo_current)
	_fire_shell()

func _fire_shell() -> void:
	if not has_ammo():
		_burst_remaining = 0
		_cooldown = _recovery_time
		return

	_shoot()
	_ammo_current -= 1
	_burst_remaining -= 1
	if _burst_remaining > 0:
		_cooldown = BURST_INTERVAL
	else:
		_cooldown = _recovery_time

	if is_instance_valid(_weapon_sprite):
		_weapon_sprite.scale = _sprite_base_scale * RECOIL_SCALE

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

func _shoot() -> void:
	var fire_dir: Vector2 = global_transform.x
	var spread := deg_to_rad(randf_range(-SPREAD_DEG, SPREAD_DEG))
	fire_dir = fire_dir.rotated(spread)
	var muzzle_pos: Vector2 = global_position + fire_dir * MUZZLE_DISTANCE

	AudioEventSystem.play_weapon_fire(muzzle_pos, AudioEventSystem.WeaponSound.AUTOCANNON)

	var shell: PomPomShell = SHELL_SCENE.instantiate()
	shell.damage      = _damage
	shell.pierce      = _pierce
	shell.penetration = _penetration
	shell.aoe_scale   = _aoe_scale
	shell.velocity    = fire_dir * _projectile_speed
	shell.rotation    = fire_dir.angle()
	shell.global_position = muzzle_pos
	get_tree().root.add_child(shell)
