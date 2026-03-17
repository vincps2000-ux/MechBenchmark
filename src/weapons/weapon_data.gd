# weapon_data.gd — Data class for weapon configuration
class_name WeaponData
extends Resource

@export var name: String = "Unnamed"
@export var damage: int = 10
@export var cooldown: float = 1.0
@export var projectile_speed: float = 300.0
@export var projectile_count: int = 1
@export var pierce: int = 1
@export var area: float = 1.0
@export var level: int = 1
@export var max_level: int = 8

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
