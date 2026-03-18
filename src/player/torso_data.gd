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

## Returns the sprite path for this torso type
func get_sprite_path() -> String:
	match torso_type:
		TorsoType.STEALTH:      return "res://assets/sprites/torso_stealth.svg"
		TorsoType.HEAVY_ARMOUR: return "res://assets/sprites/torso_heavy.svg"
		TorsoType.CARGO:        return "res://assets/sprites/torso_cargo.svg"
		_:                      return "res://assets/sprites/mech_torso.svg"
