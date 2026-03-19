# autocannon.gd — Slow-firing automatic cannon with high-speed exploding shells.
#
# Fires one round per FIRE_INTERVAL seconds while the fire action is held.
# Each shell travels at high speed and detonates on the first enemy it strikes,
# dealing damage through the explosion.  There is a brief muzzle-flash visual
# on the weapon sprite to give tactile feedback on each shot.
class_name Autocannon
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/weapons/autocannon_projectile.tscn")

## Seconds between automatic shots (lower = faster firing).
const FIRE_INTERVAL  := 0.80
## Speed of the fired shell in pixels per second.
const PROJECTILE_SPEED := 700.0
## How long the muzzle-flash sprite tint lasts in seconds.
const MUZZLE_FLASH_TIME := 0.06

## Colour of the weapon sprite when idle.
const COLOR_IDLE  := Color(1.0, 1.0, 1.0, 1.0)
## Colour of the weapon sprite during the muzzle flash.
const COLOR_FLASH := Color(1.0, 0.90, 0.30, 1.0)

var _weapon_sprite: Sprite2D = null

## Damage per shell; configured via setup().
var _damage: int   = 25
## Pierce count passed to each projectile; configured via setup().
var _pierce: int   = 1
## Countdown timer — goes negative to trigger a shot then resets.
var _cooldown: float = 0.0
## Muzzle-flash timer; >0 while flash is showing.
var _flash_timer: float = 0.0

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage = data.damage
	_pierce = data.pierce

func _process(delta: float) -> void:
	_cooldown -= delta

	if Input.is_action_pressed("fire") and _cooldown <= 0.0:
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
	var fire_dir   : Vector2 = global_transform.x
	var muzzle_pos : Vector2 = global_position + fire_dir * 16.0

	var proj: AutocannonProjectile = PROJECTILE_SCENE.instantiate()
	proj.damage   = _damage
	proj.pierce   = _pierce
	proj.velocity = fire_dir * PROJECTILE_SPEED
	proj.rotation = fire_dir.angle()
	proj.global_position = muzzle_pos

	get_tree().root.add_child(proj)
