# machinegun.gd — Light rapid-fire machinegun.
#
# Fires small bullets at a very high rate while the fire action is held.
# Low damage per shot, compensated by sheer volume of fire.
# Fits both medium and light weapon slots.
class_name Machinegun
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/weapons/machinegun_projectile.tscn")

## Seconds between automatic shots — very rapid.
const FIRE_INTERVAL     := 0.10
## Speed of the fired bullet in pixels per second.
const PROJECTILE_SPEED  := 600.0
## How long the muzzle-flash sprite tint lasts in seconds.
const MUZZLE_FLASH_TIME := 0.03
## Random spread in degrees applied to each shot.
const SPREAD_DEG        := 5.0
const BARREL_PROFILES := [
	{"fire_interval": 0.07, "projectile_speed": 520.0, "spread_deg": 10.0, "projectile_lifetime": 1.4, "muzzle_distance": 8.0},
	{"fire_interval": 0.085, "projectile_speed": 560.0, "spread_deg": 7.0, "projectile_lifetime": 1.7, "muzzle_distance": 10.0},
	{"fire_interval": FIRE_INTERVAL, "projectile_speed": PROJECTILE_SPEED, "spread_deg": SPREAD_DEG, "projectile_lifetime": MachinegunProjectile.MAX_LIFETIME, "muzzle_distance": 10.0},
	{"fire_interval": 0.12, "projectile_speed": 660.0, "spread_deg": 3.5, "projectile_lifetime": 2.3, "muzzle_distance": 14.0},
	{"fire_interval": 0.14, "projectile_speed": 720.0, "spread_deg": 2.0, "projectile_lifetime": 2.7, "muzzle_distance": 16.0},
]

## Colour of the weapon sprite when idle.
const COLOR_IDLE  := Color(1.0, 1.0, 1.0, 1.0)
## Colour of the weapon sprite during the muzzle flash.
const COLOR_FLASH := Color(1.0, 0.95, 0.5, 1.0)

var _weapon_sprite: Sprite2D = null

## Damage per bullet; configured via setup().
var _damage: int   = 3
## Pierce count passed to each projectile; configured via setup().
var _pierce: int   = 1
## Armour penetration value; configured via setup().
var _penetration: int = 4
var _fire_interval: float = FIRE_INTERVAL
var _projectile_speed: float = PROJECTILE_SPEED
var _spread_deg: float = SPREAD_DEG
var _projectile_lifetime: float = MachinegunProjectile.MAX_LIFETIME
var _muzzle_distance: float = 10.0
## Countdown timer — goes negative to trigger a shot then resets.
var _cooldown: float = 0.0
## Muzzle-flash timer; >0 while flash is showing.
var _flash_timer: float = 0.0
## InputMap action name for firing this weapon.
var fire_action: String = "fire"

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage      = data.damage
	_pierce      = data.pierce
	_penetration = data.penetration
	_apply_barrel_profile(data.barrel_length)
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	pass

func _apply_barrel_profile(length_level: int) -> void:
	var profile: Dictionary = BARREL_PROFILES[WeaponData.clamp_barrel_length(length_level)]
	_fire_interval = float(profile["fire_interval"])
	_projectile_speed = float(profile["projectile_speed"])
	_spread_deg = float(profile["spread_deg"])
	_projectile_lifetime = float(profile["projectile_lifetime"])
	_muzzle_distance = float(profile["muzzle_distance"])

func _process(delta: float) -> void:
	_cooldown -= delta

	var trigger_pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)
	if trigger_pressed and _cooldown <= 0.0:
		_shoot()
		_cooldown = _fire_interval
		_flash_timer = MUZZLE_FLASH_TIME

	# Muzzle-flash tint
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_FLASH
	else:
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_IDLE

func _shoot() -> void:
	var fire_dir: Vector2 = global_transform.x
	var spread := deg_to_rad(randf_range(-_spread_deg, _spread_deg))
	fire_dir = fire_dir.rotated(spread)
	var muzzle_pos: Vector2 = global_position + fire_dir * _muzzle_distance

	var proj: MachinegunProjectile = PROJECTILE_SCENE.instantiate()
	proj.damage      = _damage
	proj.pierce      = _pierce
	proj.penetration = _penetration
	proj.max_lifetime = _projectile_lifetime
	proj.velocity    = fire_dir * _projectile_speed
	proj.rotation    = fire_dir.angle()
	proj.global_position = muzzle_pos
	get_tree().root.add_child(proj)
