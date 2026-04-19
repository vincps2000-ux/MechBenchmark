# weapon_data.gd — Data class for weapon configuration
class_name WeaponData
extends Resource

enum WeaponType {
	AUTOCANNON,   # Rapid burst — moderate damage, single projectile
	FLAMETHROWER, # Continuous cone — low damage per ray, high area saturation
	RAILGUN,      # Slow charge — extreme damage, high pierce
	LASER,        # Instant-hit beam — continuous fire on right mouse button
	ROCKET_POD,   # Light multi-rocket launcher — fits medium & light slots
	MACHINEGUN,   # Light rapid-fire — high fire rate, low damage per bullet
}

enum SlotSize {
	MEDIUM,  # Standard weapon mount
	LIGHT,   # Small weapon mount — light weapons also fit in medium slots
}

enum AmmoType {
	HE,            # High-Explosive — red round tip
	SOLID,         # Solid shot — pointed tip
	CANISTER,      # Canister shot — boxy blue shell
}

enum TargetingType {
	UNGUIDED,      # Flies straight — default behaviour
	SEEKING,       # Tracks nearest enemy
	WIRE_GUIDED,   # Tracks the cursor position
}

@export var name: String = "Unnamed"
@export var weapon_type: WeaponType = WeaponType.AUTOCANNON
@export var damage: int = 10
@export var cooldown: float = 1.0
@export var projectile_speed: float = 300.0
@export var projectile_count: int = 1
@export var pierce: int = 1
@export var penetration: int = 5
@export var area: float = 1.0
@export var level: int = 1
@export var max_level: int = 8
@export var ammo_type: AmmoType = AmmoType.HE
@export var targeting_type: TargetingType = TargetingType.UNGUIDED
@export var slot_size: SlotSize = SlotSize.MEDIUM
@export var attachments: Array[AttachmentData] = []

## Returns true if this weapon can be placed in the given slot size.
func fits_slot(slot: SlotSize) -> bool:
	if slot_size == SlotSize.LIGHT:
		return true  # Light weapons fit in any slot
	return slot == SlotSize.MEDIUM  # Medium weapons only fit medium slots

## Returns a preview sprite path for this weapon
func get_sprite_path() -> String:
	match weapon_type:
		WeaponType.LASER, WeaponType.RAILGUN: return "res://assets/sprites/weapon_laser.svg"
		WeaponType.AUTOCANNON:               return "res://assets/sprites/weapon_autocannon.svg"
		WeaponType.ROCKET_POD:               return "res://assets/sprites/weapon_rocket_pod.svg"
		WeaponType.MACHINEGUN:               return "res://assets/sprites/weapon_gun.svg"
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
