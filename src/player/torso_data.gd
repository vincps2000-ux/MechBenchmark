# torso_data.gd — Data class for mech torso configuration.
# Extends MechPartData for shared stat-modifier fields and apply_to_stats().
class_name TorsoData
extends MechPartData

enum TorsoType {
	STEALTH,       # Sleek triangle — fast, fragile
	HEAVY_ARMOUR,  # Half-dome    — slow, very tough
	CARGO,         # Trapezoid    — balanced, extra utility
}

@export var torso_type: TorsoType = TorsoType.CARGO
## Number of weapon mount points this torso supports (Heavy=2, others=1)
@export var weapon_slots: int = 1
## Number of light weapon mount points (Stealth=1, Cargo=2, Heavy=0)
@export var light_weapon_slots: int = 0

## Apply torso stat modifiers.
func apply_to_stats(stats: PlayerStats) -> void:
	super.apply_to_stats(stats)

## Returns the sprite path for this torso type
func get_sprite_path() -> String:
	match torso_type:
		TorsoType.STEALTH:      return "res://assets/sprites/torso_stealth.svg"
		TorsoType.HEAVY_ARMOUR: return "res://assets/sprites/torso_heavy.svg"
		TorsoType.CARGO:        return "res://assets/sprites/torso_cargo.svg"
		_:                      return "res://assets/sprites/mech_torso.svg"
