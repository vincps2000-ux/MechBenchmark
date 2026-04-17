# mech_loadout.gd — Pure data container: holds the player's part selections.
# Use MechCatalog to obtain the available parts to fill a loadout with.
class_name MechLoadout
extends Resource

@export var selected_legs: LegData = null
@export var selected_torso: TorsoData = null
@export var selected_torsos: Array[TorsoData] = []
@export var selected_guns: Array[WeaponData] = []
@export var selected_light_guns: Array[WeaponData] = []

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
	var has_torso: bool = selected_torso != null or selected_torsos.size() > 0
	return selected_legs != null and has_torso and selected_guns.size() > 0

## Convenience: first torso (from selected_torsos or legacy selected_torso).
func get_primary_torso() -> TorsoData:
	if selected_torsos.size() > 0:
		return selected_torsos[0]
	return selected_torso

## Total weapon slots across all equipped torsos.
func get_total_weapon_slots() -> int:
	var total := 0
	for t in selected_torsos:
		if t:
			total += t.weapon_slots
	if total == 0 and selected_torso:
		total = selected_torso.weapon_slots
	return max(total, 1)

## Total light weapon slots across all equipped torsos.
func get_total_light_weapon_slots() -> int:
	var total := 0
	for t in selected_torsos:
		if t:
			total += t.light_weapon_slots
	if total == 0 and selected_torso:
		total = selected_torso.light_weapon_slots
	return total

## Apply the loadout modifiers to the given PlayerStats
func apply_to_stats(stats: PlayerStats) -> void:
	if selected_legs:
		selected_legs.apply_to_stats(stats)
	if selected_torsos.size() > 0:
		for t in selected_torsos:
			if t:
				t.apply_to_stats(stats)
	elif selected_torso:
		selected_torso.apply_to_stats(stats)
