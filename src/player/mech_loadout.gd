# mech_loadout.gd — Pure data container: holds the player's part selections.
# Use MechCatalog to obtain the available parts to fill a loadout with.
class_name MechLoadout
extends Resource

@export var selected_legs: LegData = null
@export var selected_torso: TorsoData = null
@export var selected_gun: WeaponData = null

## Returns true if the loadout has legs, a torso, and a gun selected
func is_valid() -> bool:
	return selected_legs != null and selected_torso != null and selected_gun != null

## Apply the loadout modifiers to the given PlayerStats
func apply_to_stats(stats: PlayerStats) -> void:
	if selected_legs:
		selected_legs.apply_to_stats(stats)
	if selected_torso:
		selected_torso.apply_to_stats(stats)
