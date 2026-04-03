# mech_loadout.gd — Pure data container: holds the player's part selections.
# Use MechCatalog to obtain the available parts to fill a loadout with.
class_name MechLoadout
extends Resource

@export var selected_legs: LegData = null
@export var selected_torso: TorsoData = null
@export var selected_guns: Array[WeaponData] = []

## Backward-compat property: get/set the first weapon.
var selected_gun: WeaponData:
	get:
		return selected_guns[0] if selected_guns.size() > 0 else null
	set(value):
		if value == null:
			selected_guns.clear()
		elif selected_guns.size() == 0:
			selected_guns.append(value)
		else:
			selected_guns[0] = value

## Returns true if the loadout has legs, a torso, and at least one gun
func is_valid() -> bool:
	return selected_legs != null and selected_torso != null and selected_guns.size() > 0

## Apply the loadout modifiers to the given PlayerStats
func apply_to_stats(stats: PlayerStats) -> void:
	if selected_legs:
		selected_legs.apply_to_stats(stats)
	if selected_torso:
		selected_torso.apply_to_stats(stats)
