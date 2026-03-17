# leg_data.gd — Data class for mech leg configuration
class_name LegData
extends Resource

enum MovementType {
	SPIDER,  # WASD world-space strafe; Q/E rotate slowly
	TANK,    # W/S forward/back (fast); Q/E rotate slowly
	LEGS,    # WASD world-space; robot always faces mouse
}

@export var name: String = "Unnamed"
@export var description: String = ""
@export var tutorial_text: String = ""
@export var movement_type: MovementType = MovementType.LEGS
@export var speed_modifier: float = 1.0
@export var health_modifier: float = 1.0

## Apply this leg type's modifiers to the given PlayerStats
func apply_to_stats(stats: PlayerStats) -> void:
	stats.speed = stats.speed * speed_modifier
	stats.max_health = int(stats.max_health * health_modifier)
	stats.health = stats.max_health
