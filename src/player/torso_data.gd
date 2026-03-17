# torso_data.gd — Data class for mech torso configuration
class_name TorsoData
extends Resource

enum TorsoType {
	STEALTH,       # Sleek triangle — fast, fragile
	HEAVY_ARMOUR,  # Half-dome    — slow, very tough
	CARGO,         # Trapezoid    — balanced, extra utility
}

@export var name: String = "Unnamed"
@export var description: String = ""
@export var tutorial_text: String = ""
@export var torso_type: TorsoType = TorsoType.CARGO
@export var speed_modifier: float = 1.0
@export var health_modifier: float = 1.0

## Returns the sprite path for this torso type
func get_sprite_path() -> String:
	match torso_type:
		TorsoType.STEALTH:      return "res://assets/sprites/torso_stealth.svg"
		TorsoType.HEAVY_ARMOUR: return "res://assets/sprites/torso_heavy.svg"
		TorsoType.CARGO:        return "res://assets/sprites/torso_cargo.svg"
		_:                      return "res://assets/sprites/mech_torso.svg"

## Apply this torso's modifiers to the given PlayerStats
func apply_to_stats(stats: PlayerStats) -> void:
	stats.speed      = stats.speed * speed_modifier
	stats.max_health = int(stats.max_health * health_modifier)
	stats.health     = stats.max_health
