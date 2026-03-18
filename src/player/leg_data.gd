# leg_data.gd — Data class for mech leg configuration.
# Extends MechPartData for shared stat-modifier fields and apply_to_stats().
class_name LegData
extends MechPartData

enum MovementType {
	SPIDER,  # WASD world-space strafe; Q/E rotate slowly
	TANK,    # W/S forward/back (fast); Q/E rotate slowly
	LEGS,    # WASD world-space; robot always faces mouse
}

@export var movement_type: MovementType = MovementType.LEGS

## Returns the sprite path for this leg type
func get_sprite_path() -> String:
	match movement_type:
		MovementType.SPIDER: return "res://assets/sprites/legs_spider.svg"
		MovementType.TANK:   return "res://assets/sprites/legs_tank.svg"
		MovementType.LEGS:   return "res://assets/sprites/legs_bipedal.svg"
		_:                   return "res://assets/sprites/mech_legs.svg"
