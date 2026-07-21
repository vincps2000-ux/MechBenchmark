# rocket_pod.gd — Light multi-rocket launcher.
# Fires a burst of small rockets in quick succession.
# Fits both medium and light weapon slots.
class_name RocketPod
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/weapons/rocket_projectile.tscn")

const FIRE_INTERVAL     := 1.2
const DEFAULT_PROJECTILE_SPEED := 400.0
const MUZZLE_FLASH_TIME := 0.04
const BURST_DELAY       := 0.08
const SPREAD_DEG        := 8.0
const MAX_AMMO          := 12

const COLOR_IDLE  := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_FLASH := Color(1.0, 0.6, 0.2, 1.0)

var _weapon_sprite: Sprite2D = null
var _damage: int       = 15
var _pierce: int       = 1
var _penetration: int  = 3
var _targeting_type: WeaponData.TargetingType = WeaponData.TargetingType.UNGUIDED
var _projectile_speed: float = DEFAULT_PROJECTILE_SPEED
var _projectile_lifetime: float = 3.0
var _aoe_scale: float = 1.0
var _has_explosive: bool = true
var _has_cluster: bool = false
var _has_proximity_trigger: bool = false
var _fire_mode: WeaponData.MissileFireMode = WeaponData.MissileFireMode.TRIPLE
var _cooldown: float   = 0.0
var _flash_timer: float = 0.0
var _burst_remaining: int = 0
var _burst_timer: float   = 0.0
var _ammo_current: int = MAX_AMMO
var _ammo_capacity: int = MAX_AMMO
## InputMap action name for firing this weapon.
var fire_action: String = "fire"

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D

func setup(data: WeaponData) -> void:
	_damage         = data.damage
	_pierce         = data.pierce
	_penetration    = data.penetration
	_targeting_type = data.targeting_type
	_projectile_speed = data.projectile_speed
	_projectile_lifetime = data.projectile_lifetime
	_aoe_scale = data.area
	_has_explosive = data.missile_has_explosive
	_has_cluster = data.missile_has_cluster
	_has_proximity_trigger = data.missile_has_proximity_trigger
	_fire_mode = data.missile_fire_mode
	_ammo_capacity = MAX_AMMO
	_ammo_current = _ammo_capacity
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	_burst_remaining = 0

func _process(delta: float) -> void:
	_cooldown -= delta

	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			if _fire_rocket():
				_burst_remaining -= 1
				_burst_timer = BURST_DELAY
				_flash_timer = MUZZLE_FLASH_TIME
			else:
				_burst_remaining = 0

	var trigger_pressed := InputMap.has_action(fire_action) and Input.is_action_pressed(fire_action)
	if trigger_pressed and can_start_burst():
		_burst_remaining = _get_burst_size()
		_burst_timer = 0.0
		_cooldown = FIRE_INTERVAL

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_FLASH
	else:
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_IDLE

func can_start_burst() -> bool:
	return _cooldown <= 0.0 and _burst_remaining <= 0 and has_ammo()

func _get_burst_size() -> int:
	match _fire_mode:
		WeaponData.MissileFireMode.SINGLE:
			return mini(1, _ammo_current)
		WeaponData.MissileFireMode.ALL_AMMO:
			return _ammo_current
		_:
			return mini(3, _ammo_current)

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

func _fire_rocket() -> bool:
	if not has_ammo():
		return false
	_ammo_current -= 1
	var fire_dir: Vector2 = global_transform.x
	var spread := deg_to_rad(randf_range(-SPREAD_DEG, SPREAD_DEG))
	fire_dir = fire_dir.rotated(spread)
	var muzzle_pos: Vector2 = global_position + fire_dir * 10.0

	AudioEventSystem.play_weapon_fire(muzzle_pos, AudioEventSystem.WeaponSound.ROCKET)

	var proj = PROJECTILE_SCENE.instantiate()
	proj.damage   = _damage
	proj.pierce   = _pierce
	proj.penetration = _penetration
	proj.targeting_type = _targeting_type
	proj.velocity = fire_dir * _projectile_speed
	proj.aoe_scale = _aoe_scale
	proj.max_lifetime = _projectile_lifetime
	proj.explosive_enabled = _has_explosive
	proj.cluster_enabled = _has_cluster
	proj.proximity_trigger_enabled = _has_proximity_trigger
	proj.rotation = fire_dir.angle()
	proj.global_position = muzzle_pos
	get_tree().root.add_child(proj)
	return true
