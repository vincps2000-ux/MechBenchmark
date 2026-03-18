# weapon_data.gd — Data class for weapon configuration
class_name WeaponData
extends Resource

enum WeaponType {
	AUTOCANNON,   # Rapid burst — moderate damage, single projectile
	FLAMETHROWER, # Continuous cone — low damage per ray, high area saturation
	RAILGUN,      # Slow charge — extreme damage, high pierce
	LASER,        # Instant-hit beam — continuous fire on right mouse button
}

@export var name: String = "Unnamed"
@export var weapon_type: WeaponType = WeaponType.AUTOCANNON
@export var damage: int = 10
@export var cooldown: float = 1.0
@export var projectile_speed: float = 300.0
@export var projectile_count: int = 1
@export var pierce: int = 1
@export var area: float = 1.0
@export var level: int = 1
@export var max_level: int = 8

## Returns a preview sprite path for this weapon
func get_sprite_path() -> String:
	match weapon_type:
		WeaponType.LASER, WeaponType.RAILGUN: return "res://assets/sprites/weapon_laser.svg"
		_:                                    return "res://assets/sprites/weapon_gun.svg"

func can_level_up() -> bool:
	return level < max_level

func level_up() -> void:
	if can_level_up():
		level += 1
		# Scale stats per level
		damage += int(damage * 0.2)
		if level % 2 == 0:
			projectile_count += 1
		if level % 3 == 0:
			pierce += 1
