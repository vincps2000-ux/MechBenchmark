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
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	pass

func _process(delta: float) -> void:
	_cooldown -= delta

	if Input.is_action_pressed(fire_action) and _cooldown <= 0.0:
		_shoot()
		_cooldown = FIRE_INTERVAL
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
	var spread := deg_to_rad(randf_range(-SPREAD_DEG, SPREAD_DEG))
	fire_dir = fire_dir.rotated(spread)
	var muzzle_pos: Vector2 = global_position + fire_dir * 10.0

	var proj: MachinegunProjectile = PROJECTILE_SCENE.instantiate()
	proj.damage      = _damage
	proj.pierce      = _pierce
	proj.penetration = _penetration
	proj.velocity    = fire_dir * PROJECTILE_SPEED
	proj.rotation    = fire_dir.angle()
	proj.global_position = muzzle_pos
	get_tree().root.add_child(proj)
