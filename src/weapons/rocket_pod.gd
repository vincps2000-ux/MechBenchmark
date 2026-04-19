# rocket_pod.gd — Light multi-rocket launcher.
# Fires a burst of small rockets in quick succession.
# Fits both medium and light weapon slots.
class_name RocketPod
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/weapons/rocket_projectile.tscn")

const FIRE_INTERVAL     := 1.2
const PROJECTILE_SPEED  := 400.0
const MUZZLE_FLASH_TIME := 0.04
const BURST_COUNT       := 3
const BURST_DELAY       := 0.08
const SPREAD_DEG        := 8.0

const COLOR_IDLE  := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_FLASH := Color(1.0, 0.6, 0.2, 1.0)

var _weapon_sprite: Sprite2D = null
var _damage: int       = 15
var _pierce: int       = 1
var _penetration: int  = 3
var _targeting_type: WeaponData.TargetingType = WeaponData.TargetingType.UNGUIDED
var _cooldown: float   = 0.0
var _flash_timer: float = 0.0
var _burst_remaining: int = 0
var _burst_timer: float   = 0.0
## InputMap action name for firing this weapon.
var fire_action: String = "fire"

func _ready() -> void:
	_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D

func setup(data: WeaponData) -> void:
	_damage         = data.damage
	_pierce         = data.pierce
	_penetration    = data.penetration
	_targeting_type = data.targeting_type
	WeaponAttachment.mount_from_data(self, data)

func stop_firing() -> void:
	_burst_remaining = 0

func _process(delta: float) -> void:
	_cooldown -= delta

	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire_rocket()
			_burst_remaining -= 1
			_burst_timer = BURST_DELAY
			_flash_timer = MUZZLE_FLASH_TIME

	if Input.is_action_pressed(fire_action) and _cooldown <= 0.0 and _burst_remaining <= 0:
		_burst_remaining = BURST_COUNT
		_burst_timer = 0.0
		_cooldown = FIRE_INTERVAL

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_FLASH
	else:
		if is_instance_valid(_weapon_sprite):
			_weapon_sprite.modulate = COLOR_IDLE

func _fire_rocket() -> void:
	var fire_dir: Vector2 = global_transform.x
	var spread := deg_to_rad(randf_range(-SPREAD_DEG, SPREAD_DEG))
	fire_dir = fire_dir.rotated(spread)
	var muzzle_pos: Vector2 = global_position + fire_dir * 10.0

	var proj = PROJECTILE_SCENE.instantiate()
	proj.damage   = _damage
	proj.pierce   = _pierce
	proj.penetration = _penetration
	proj.targeting_type = _targeting_type
	proj.velocity = fire_dir * PROJECTILE_SPEED
	proj.rotation = fire_dir.angle()
	proj.global_position = muzzle_pos
	get_tree().root.add_child(proj)
