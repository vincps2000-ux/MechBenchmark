# mech_part_data.gd — Abstract base class for all equippable mech parts.
# LegData and TorsoData both extend this so shared fields and apply_to_stats()
# live in one place instead of being duplicated across every part type.
class_name MechPartData
extends Resource

@export var name: String = "Unnamed"
@export var description: String = ""
@export var tutorial_text: String = ""
@export var speed_modifier: float = 1.0
@export var health_modifier: float = 1.0

## Apply this part's stat modifiers to the given PlayerStats.
## Speed and health are multiplied by the respective modifier;
## current health is reset to the new max.
func apply_to_stats(stats: PlayerStats) -> void:
	stats.speed      = stats.speed * speed_modifier
	stats.max_health = int(stats.max_health * health_modifier)
	stats.health     = stats.max_health
