# plasma_gun.gd — Medium plasma cannon that lobs dense energy spheres.
class_name PlasmaGun
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/weapons/plasma_projectile.tscn")

const FIRE_INTERVAL := 1.10
const PROJECTILE_SPEED := 360.0
const PROJECTILE_LIFETIME := 2.2
const LOB_HEIGHT := 28.0
const MUZZLE_FLASH_TIME := 0.05

const COLOR_IDLE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_FLASH := Color(0.75, 0.9, 1.0, 1.0)
const ENERGY_COST_PER_SHOT := 5.0

var _weapon_sprite: Sprite2D = null
var _damage: int = 24
var _pierce: int = 2
var _penetration: int = 5
var _projectile_speed: float = PROJECTILE_SPEED
var _projectile_lifetime: float = PROJECTILE_LIFETIME
var _lob_height: float = LOB_HEIGHT
var _cooldown: float = 0.0
var _flash_timer: float = 0.0
var fire_action: String = "fire"

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D

func setup(data: WeaponData) -> void:
	_damage = data.damage
	_pierce = data.pierce
	_penetration = data.penetration
	_projectile_speed = data.projectile_speed
	_projectile_lifetime = data.projectile_lifetime
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	pass

func _process(delta: float) -> void:
	_cooldown -= delta

	var trigger_pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)
	if trigger_pressed:
		try_fire_once()

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_FLASH
	else:
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_IDLE

func can_fire() -> bool:
	return _cooldown <= 0.0

func _find_energy_owner() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("has_energy_for") and node.has_method("consume_energy"):
			return node
		node = node.get_parent()
	return null

func try_fire_once() -> bool:
	if not can_fire():
		return false
	var owner := _find_energy_owner()
	if owner != null and not owner.call("has_energy_for", ENERGY_COST_PER_SHOT):
		return false
	if owner != null:
		owner.call("consume_energy", ENERGY_COST_PER_SHOT)
	_shoot()
	_cooldown = FIRE_INTERVAL
	_flash_timer = MUZZLE_FLASH_TIME
	return true

func _shoot() -> void:
	var fire_dir: Vector2 = global_transform.x
	var muzzle_pos: Vector2 = global_position + fire_dir * 12.0

	var proj = PROJECTILE_SCENE.instantiate()
	proj.damage = _damage
	proj.pierce = _pierce
	proj.penetration = _penetration
	proj.max_lifetime = _projectile_lifetime
	proj.lob_height = _lob_height
	proj.velocity = fire_dir * _projectile_speed
	proj.rotation = fire_dir.angle()
	proj.global_position = muzzle_pos
	get_tree().root.add_child(proj)