# autocannon.gd — Slow-firing automatic cannon with high-speed exploding shells.
#
# Fires one round per FIRE_INTERVAL seconds while the fire action is held.
# Each shell travels at high speed and detonates on the first enemy it strikes,
# dealing damage through the explosion.  There is a brief muzzle-flash visual
# on the weapon sprite to give tactile feedback on each shot.
class_name Autocannon
extends Node2D

enum FireControlMode {
	INPUT,
	EXTERNAL,
}

const PROJECTILE_SCENE := preload("res://scenes/weapons/autocannon_projectile.tscn")

## Seconds between automatic shots (lower = faster firing).
const FIRE_INTERVAL  := 0.80
## Speed of the fired shell in pixels per second.
const PROJECTILE_SPEED := 700.0
## How long the muzzle-flash sprite tint lasts in seconds.
const MUZZLE_FLASH_TIME := 0.06
const MAX_AMMO := 20
const BARREL_PROFILES := [
	{"fire_interval": 0.48, "projectile_speed": 600.0, "spread_deg": 5.5, "projectile_lifetime": 1.8, "muzzle_distance": 12.0, "canister_spread_deg": 36.0},
	{"fire_interval": 0.62, "projectile_speed": 650.0, "spread_deg": 3.5, "projectile_lifetime": 2.3, "muzzle_distance": 14.0, "canister_spread_deg": 33.0},
	{"fire_interval": FIRE_INTERVAL, "projectile_speed": PROJECTILE_SPEED, "spread_deg": 2.0, "projectile_lifetime": AutocannonProjectile.MAX_LIFETIME, "muzzle_distance": 16.0, "canister_spread_deg": CANISTER_SPREAD_DEG},
	{"fire_interval": 1.00, "projectile_speed": 780.0, "spread_deg": 1.1, "projectile_lifetime": 3.6, "muzzle_distance": 18.0, "canister_spread_deg": 26.0},
	{"fire_interval": 1.24, "projectile_speed": 860.0, "spread_deg": 0.4, "projectile_lifetime": 4.3, "muzzle_distance": 20.0, "canister_spread_deg": 22.0},
]

## Colour of the weapon sprite when idle.
const COLOR_IDLE  := Color(1.0, 1.0, 1.0, 1.0)
## Colour of the weapon sprite during the muzzle flash.
const COLOR_FLASH := Color(1.0, 0.90, 0.30, 1.0)

var _weapon_sprite: Sprite2D = null

## Damage per shell; configured via setup().
var _damage: int   = 25
## Pierce count passed to each projectile; configured via setup().
var _pierce: int   = 1
## Armour penetration value; configured via setup().
var _penetration: int = 4
## Ammo type for this autocannon instance.
var _ammo_type: WeaponData.AmmoType = WeaponData.AmmoType.HE
var _fire_interval: float = FIRE_INTERVAL
var _projectile_speed: float = PROJECTILE_SPEED
var _spread_deg: float = 2.0
var _projectile_lifetime: float = AutocannonProjectile.MAX_LIFETIME
var _muzzle_distance: float = 16.0
var _canister_spread_deg: float = CANISTER_SPREAD_DEG
## Countdown timer — goes negative to trigger a shot then resets.
var _cooldown: float = 0.0
## Muzzle-flash timer; >0 while flash is showing.
var _flash_timer: float = 0.0
var _ammo_current: int = MAX_AMMO
## InputMap action name for firing this weapon.
var fire_action: String = "fire"
## Fire source mode (player input or external AI trigger).
var fire_control_mode: FireControlMode = FireControlMode.INPUT
## Which collision layer(s) shells should damage (player uses 2=enemies).
var projectile_target_mask: int = 2
## Which collision layer(s) explosions should damage.
var explosion_target_mask: int = 2

## Solid ammo multipliers.
const SOLID_DAMAGE_MULT := 1.6
const SOLID_PIERCE_BONUS := 2
## Canister ammo settings.
const CANISTER_PELLET_COUNT := 6
const CANISTER_SPREAD_DEG   := 30.0
const CANISTER_DAMAGE_MULT  := 0.4
const CANISTER_SPEED_MULT   := 0.85

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage = data.damage
	_pierce = data.pierce
	_penetration = data.penetration
	_ammo_type = data.ammo_type
	_ammo_current = MAX_AMMO
	_apply_barrel_profile(data.barrel_length)
	WeaponAttachment.mount_from_data(self, data)

func _apply_barrel_profile(length_level: int) -> void:
	var profile: Dictionary = BARREL_PROFILES[WeaponData.clamp_barrel_length(length_level)]
	_fire_interval = float(profile["fire_interval"])
	_projectile_speed = float(profile["projectile_speed"])
	_spread_deg = float(profile["spread_deg"])
	_projectile_lifetime = float(profile["projectile_lifetime"])
	_muzzle_distance = float(profile["muzzle_distance"])
	_canister_spread_deg = float(profile["canister_spread_deg"])

func _process(delta: float) -> void:
	_cooldown -= delta

	var trigger_pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)
	if fire_control_mode == FireControlMode.INPUT and trigger_pressed:
		try_fire_once()

	# Muzzle-flash tint
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_FLASH
	else:
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_IDLE

func can_fire() -> bool:
	return _cooldown <= 0.0 and has_ammo()

func try_fire_once() -> bool:
	if not can_fire():
		return false
	_shoot()
	_ammo_current -= 1
	_cooldown = _fire_interval
	_flash_timer = MUZZLE_FLASH_TIME
	return true

func get_ammo_count() -> int:
	return _ammo_current

func get_ammo_capacity() -> int:
	return MAX_AMMO

func has_ammo() -> bool:
	return _ammo_current > 0

func is_out_of_ammo() -> bool:
	return not has_ammo()

func _shoot() -> void:
	var fire_dir   : Vector2 = global_transform.x
	var spread := deg_to_rad(randf_range(-_spread_deg, _spread_deg))
	fire_dir = fire_dir.rotated(spread)
	var muzzle_pos : Vector2 = global_position + fire_dir * _muzzle_distance

	match _ammo_type:
		WeaponData.AmmoType.SOLID:
			_shoot_solid(fire_dir, muzzle_pos)
		WeaponData.AmmoType.CANISTER:
			_shoot_canister(fire_dir, muzzle_pos)
		_:
			_shoot_he(fire_dir, muzzle_pos)


func _shoot_he(fire_dir: Vector2, muzzle_pos: Vector2) -> void:
	var proj: AutocannonProjectile = PROJECTILE_SCENE.instantiate()
	_configure_projectile_targeting(proj)
	proj.damage   = _damage
	proj.pierce   = _pierce
	proj.penetration = _penetration
	proj.max_lifetime = _projectile_lifetime
	proj.velocity = fire_dir * _projectile_speed
	proj.rotation = fire_dir.angle()
	proj.global_position = muzzle_pos
	get_tree().root.add_child(proj)


func _shoot_solid(fire_dir: Vector2, muzzle_pos: Vector2) -> void:
	var proj: AutocannonProjectile = PROJECTILE_SCENE.instantiate()
	_configure_projectile_targeting(proj)
	proj.damage   = int(_damage * SOLID_DAMAGE_MULT)
	proj.pierce   = _pierce + SOLID_PIERCE_BONUS
	proj.penetration = _penetration
	proj.explodes = false
	proj.shell_color = AutocannonProjectile.COLOR_SOLID
	proj.max_lifetime = _projectile_lifetime
	proj.velocity = fire_dir * _projectile_speed
	proj.rotation = fire_dir.angle()
	proj.global_position = muzzle_pos
	get_tree().root.add_child(proj)


func _shoot_canister(fire_dir: Vector2, muzzle_pos: Vector2) -> void:
	var base_angle := fire_dir.angle()
	var spread_rad := deg_to_rad(_canister_spread_deg)
	var pellet_dmg := int(_damage * CANISTER_DAMAGE_MULT)
	var pellet_speed := _projectile_speed * CANISTER_SPEED_MULT

	for i in CANISTER_PELLET_COUNT:
		var t := float(i) / float(CANISTER_PELLET_COUNT - 1)  # 0..1
		var angle := base_angle - spread_rad * 0.5 + spread_rad * t
		var dir := Vector2.from_angle(angle)

		var proj: AutocannonProjectile = PROJECTILE_SCENE.instantiate()
		_configure_projectile_targeting(proj)
		proj.damage   = pellet_dmg
		proj.pierce   = 1
		proj.penetration = _penetration
		proj.explodes = false
		proj.shell_color = AutocannonProjectile.COLOR_CANISTER
		proj.max_lifetime = _projectile_lifetime
		proj.velocity = dir * pellet_speed
		proj.rotation = angle
		proj.global_position = muzzle_pos
		get_tree().root.add_child(proj)

func _configure_projectile_targeting(proj: AutocannonProjectile) -> void:
	proj.target_collision_mask = projectile_target_mask
	proj.explosion_target_mask = explosion_target_mask
