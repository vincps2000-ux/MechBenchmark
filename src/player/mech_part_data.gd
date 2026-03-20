# mech_part_data.gd — Abstract base class for all equippable mech parts.
# LegData and TorsoData both extend this so shared fields and apply_to_stats()
# live in one place instead of being duplicated across every part type.
class_name MechPartData
extends Resource

@export var name: String = "Unnamed"
@export var description: String = ""
@export var tutorial_text: String = ""
@export var speed_modifier: float = 1.0

## Apply this part's stat modifiers to the given PlayerStats.
## Speed is multiplied by the modifier.
func apply_to_stats(stats: PlayerStats) -> void:
	stats.speed = stats.speed * speed_modifier
