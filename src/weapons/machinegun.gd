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
const MAX_AMMO         := 500
const RIOT_KNOCKBACK_FORCE := 320.0
const ENEMY_COLLISION_MASK := 2
const BARREL_PROFILES := [
	{"fire_interval": 0.07, "projectile_speed": 520.0, "spread_deg": 10.0, "projectile_lifetime": 1.4, "muzzle_distance": 8.0},
	{"fire_interval": 0.085, "projectile_speed": 560.0, "spread_deg": 7.0, "projectile_lifetime": 1.7, "muzzle_distance": 10.0},
	{"fire_interval": FIRE_INTERVAL, "projectile_speed": PROJECTILE_SPEED, "spread_deg": SPREAD_DEG, "projectile_lifetime": MachinegunProjectile.MAX_LIFETIME, "muzzle_distance": 10.0},
	{"fire_interval": 0.12, "projectile_speed": 660.0, "spread_deg": 3.5, "projectile_lifetime": 2.3, "muzzle_distance": 14.0},
	{"fire_interval": 0.14, "projectile_speed": 720.0, "spread_deg": 2.0, "projectile_lifetime": 2.7, "muzzle_distance": 16.0},
]
const BARREL_COUNT_PROFILES := [
	{"interval_factor": 1.0, "speed_factor": 1.0, "spread_factor": 1.0},
	{"interval_factor": 0.92, "speed_factor": 0.98, "spread_factor": 1.15},
	{"interval_factor": 0.84, "speed_factor": 0.95, "spread_factor": 1.30},
	{"interval_factor": 0.76, "speed_factor": 0.92, "spread_factor": 1.50},
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
var _barrel_count: int = WeaponData.MIN_BARREL_COUNT
var _barrel_length: WeaponData.BarrelLength = WeaponData.DEFAULT_BARREL_LENGTH
var _ammo_type: WeaponData.AmmoType = WeaponData.AmmoType.NORMAL
var _knockback_force := 0.0
var _weapon_visuals: Array[Sprite2D] = []
## Countdown timer — goes negative to trigger a shot then resets.
var _cooldown: float = 0.0
## Muzzle-flash timer; >0 while flash is showing.
var _flash_timer: float = 0.0
var _ammo_current: int = MAX_AMMO
## InputMap action name for firing this weapon.
var fire_action: String = "fire"

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponVisuals/WeaponSprite") as Sprite2D
	_rebuild_weapon_visual()

## Called by PlayerController immediately after instantiation.
func setup(data: WeaponData) -> void:
	_damage      = data.damage
	_pierce      = data.pierce
	_penetration = data.penetration
	_ammo_current = MAX_AMMO
	_apply_barrel_profile(data.barrel_length)
	_apply_ammo_behavior(data.ammo_type)
	_apply_barrel_count_profile(data.barrel_count)
	_rebuild_weapon_visual()
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	pass

func _apply_barrel_profile(length_level: int) -> void:
	_barrel_length = WeaponData.clamp_barrel_length(length_level)
	var profile: Dictionary = BARREL_PROFILES[_barrel_length]
	_fire_interval = float(profile["fire_interval"])
	_projectile_speed = float(profile["projectile_speed"])
	_spread_deg = float(profile["spread_deg"])
	_projectile_lifetime = float(profile["projectile_lifetime"])
	_muzzle_distance = float(profile["muzzle_distance"])

func _apply_ammo_behavior(ammo_type: WeaponData.AmmoType) -> void:
	_ammo_type = ammo_type
	_knockback_force = 0.0
	if _ammo_type == WeaponData.AmmoType.RIOT:
		_damage = 0
		_knockback_force = RIOT_KNOCKBACK_FORCE

func _apply_barrel_count_profile(count: int) -> void:
	_barrel_count = WeaponData.clamp_barrel_count(count)
	var profile: Dictionary = BARREL_COUNT_PROFILES[_barrel_count - 1]
	_fire_interval *= float(profile["interval_factor"])
	_projectile_speed *= float(profile["speed_factor"])
	_spread_deg *= float(profile["spread_factor"])

func _rebuild_weapon_visual() -> void:
	if not is_instance_valid(_weapon_sprite):
		return
	var visual_root := _weapon_sprite.get_parent()
	for child in visual_root.get_children():
		if child != _weapon_sprite:
			child.free()
	_weapon_visuals.clear()

	var length_scale := 0.45 + float(_barrel_length) * 0.1
	for barrel_index in _barrel_count:
		var visual := _weapon_sprite if barrel_index == 0 else _weapon_sprite.duplicate() as Sprite2D
		visual.name = "WeaponSprite" if barrel_index == 0 else "WeaponSprite%d" % (barrel_index + 1)
		visual.position.y = (float(barrel_index) - float(_barrel_count - 1) * 0.5) * 5.0
		visual.scale = Vector2(0.65, length_scale)
		visual.visible = true
		if barrel_index > 0:
			visual_root.add_child(visual)
		_weapon_visuals.append(visual)

func _process(delta: float) -> void:
	_cooldown -= delta

	var trigger_pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)
	if trigger_pressed:
		try_fire_once()

	# Muzzle-flash tint
	if _flash_timer > 0.0:
		_flash_timer -= delta
		for visual in _weapon_visuals:
			if is_instance_valid(visual):
				visual.modulate = COLOR_FLASH
	else:
		for visual in _weapon_visuals:
			if is_instance_valid(visual):
				visual.modulate = COLOR_IDLE

func can_fire() -> bool:
	return _cooldown <= 0.0 and has_ammo() \
			and (not uses_smart_rounds() or _has_smart_target())

func uses_smart_rounds() -> bool:
	return _ammo_type == WeaponData.AmmoType.SMART

func has_smart_lock() -> bool:
	return uses_smart_rounds() and _has_smart_target()

func _has_smart_target() -> bool:
	if not is_inside_tree() or get_world_2d() == null:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collision_mask = ENEMY_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	for hit in get_world_2d().direct_space_state.intersect_point(query, 8):
		var collider := hit.get("collider") as Node
		if collider != null and (
				collider.is_in_group("enemies")
				or collider.has_method("take_damage")
				or (collider.get_parent() != null and collider.get_parent().is_in_group("enemies"))):
			return true
	return false

func try_fire_once() -> bool:
	if not can_fire():
		return false
	var rounds_to_fire := mini(_barrel_count, _ammo_current)
	_shoot(rounds_to_fire)
	_ammo_current -= rounds_to_fire
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

func _shoot(round_count: int) -> void:
	var aim_direction: Vector2 = global_transform.x
	var muzzle_center: Vector2 = global_position + aim_direction * _muzzle_distance
	AudioEventSystem.play_weapon_fire(muzzle_center, AudioEventSystem.WeaponSound.MACHINEGUN)

	for barrel_index in round_count:
		var fire_dir := aim_direction.rotated(deg_to_rad(randf_range(-_spread_deg, _spread_deg)))
		var lateral_offset := (float(barrel_index) - float(round_count - 1) * 0.5) * 3.0
		var muzzle_pos := global_position + fire_dir * _muzzle_distance + global_transform.y * lateral_offset

		var proj: MachinegunProjectile = PROJECTILE_SCENE.instantiate()
		proj.damage = _damage
		proj.pierce = _pierce
		proj.penetration = _penetration
		proj.max_lifetime = _projectile_lifetime
		proj.knockback_force = _knockback_force
		proj.velocity = fire_dir * _projectile_speed
		proj.rotation = fire_dir.angle()
		proj.global_position = muzzle_pos
		get_tree().root.add_child(proj)
