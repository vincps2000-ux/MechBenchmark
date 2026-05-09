# weapon_data.gd — Data class for weapon configuration
class_name WeaponData
extends Resource

enum WeaponType {
	AUTOCANNON,   # Rapid burst — moderate damage, single projectile
	FLAMETHROWER, # Continuous cone — low damage per ray, high area saturation
	RAILGUN,      # Slow charge — extreme damage, high pierce
	LASER,        # Instant-hit beam — continuous fire on right mouse button
	PLASMA_GUN,   # Arcing plasma lobber — high damage, medium penetration
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

enum ThrowerElement {
	FUEL,          # Classic fuel flame — orange/yellow
	ACID,          # Corrosive spray — green tones
	CRYOGENICS,    # Cryo stream — cyan/blue tones
}

enum TargetingType {
	UNGUIDED,      # Flies straight — default behaviour
	SEEKING,       # Tracks nearest enemy
	WIRE_GUIDED,   # Tracks the cursor position
}

enum BarrelLength {
	VERY_SHORT,
	SHORT,
	STANDARD,
	LONG,
	VERY_LONG,
}

const DEFAULT_BARREL_LENGTH := BarrelLength.STANDARD
const BARREL_LENGTH_COUNT := 5
const MISSILE_SLOT_COUNT := 6
const MISSILE_SPEED_NO_FUEL := 95.0
const MISSILE_SPEED_PER_FUEL := 185.0
const MISSILE_LIFETIME_NO_FUEL := 0.6
const MISSILE_LIFETIME_PER_FUEL := 1.1
const MISSILE_DAMAGE_PER_EXPLOSIVE := 34
const MISSILE_AOE_BASE_WITH_EXPLOSIVE := 1.0
const MISSILE_AOE_PER_EXPLOSIVE := 0.8

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
@export var thrower_element: ThrowerElement = ThrowerElement.FUEL
@export var targeting_type: TargetingType = TargetingType.UNGUIDED
@export var slot_size: SlotSize = SlotSize.MEDIUM
@export var barrel_length: BarrelLength = DEFAULT_BARREL_LENGTH
@export var attachments: Array[AttachmentData] = []
@export var projectile_lifetime: float = 3.0
@export var missile_builder_layout: Array[String] = []
@export var missile_has_explosive: bool = true

# Rocket Pod baseline stats retained for reversible missile-builder recalculation.
@export var _rocket_base_damage: int = -1
@export var _rocket_base_area: float = -1.0
@export var _rocket_base_lifetime: float = -1.0

static func clamp_barrel_length(value: int) -> BarrelLength:
	return clampi(value, BarrelLength.VERY_SHORT, BarrelLength.VERY_LONG) as BarrelLength

static func get_barrel_length_label(value: int) -> String:
	match clamp_barrel_length(value):
		BarrelLength.VERY_SHORT: return "I"
		BarrelLength.SHORT: return "II"
		BarrelLength.STANDARD: return "III"
		BarrelLength.LONG: return "IV"
		BarrelLength.VERY_LONG: return "V"
	return "III"

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
		WeaponType.PLASMA_GUN:               return "res://assets/sprites/weapon_plasma.svg"
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


func apply_missile_builder(layout: Array[String]) -> void:
	if weapon_type != WeaponType.ROCKET_POD:
		return

	_ensure_rocket_base_stats()

	var normalized := _normalize_missile_layout(layout)
	missile_builder_layout = normalized

	var fuel_count := 0
	var explosive_count := 0
	var guidance_type := TargetingType.UNGUIDED

	for part in normalized:
		match part:
			"fuel":
				fuel_count += 1
			"explosive":
				explosive_count += 1
			"wire_guided":
				guidance_type = TargetingType.WIRE_GUIDED
			"homing":
				guidance_type = TargetingType.SEEKING

	projectile_speed = MISSILE_SPEED_NO_FUEL + float(fuel_count) * MISSILE_SPEED_PER_FUEL
	projectile_lifetime = MISSILE_LIFETIME_NO_FUEL + float(fuel_count) * MISSILE_LIFETIME_PER_FUEL

	if explosive_count <= 0:
		missile_has_explosive = false
		damage = 0
		area = 0.0
	else:
		missile_has_explosive = true
		damage = explosive_count * MISSILE_DAMAGE_PER_EXPLOSIVE
		area = MISSILE_AOE_BASE_WITH_EXPLOSIVE + float(explosive_count - 1) * MISSILE_AOE_PER_EXPLOSIVE

	targeting_type = guidance_type


func _ensure_rocket_base_stats() -> void:
	if _rocket_base_damage < 0:
		_rocket_base_damage = damage
	if _rocket_base_area < 0.0:
		_rocket_base_area = area
	if _rocket_base_lifetime < 0.0:
		_rocket_base_lifetime = projectile_lifetime


static func _normalize_missile_layout(layout: Array[String]) -> Array[String]:
	var out: Array[String] = []
	out.resize(MISSILE_SLOT_COUNT)
	for i in MISSILE_SLOT_COUNT:
		out[i] = ""
	for i in mini(layout.size(), MISSILE_SLOT_COUNT):
		out[i] = layout[i]
	return out
