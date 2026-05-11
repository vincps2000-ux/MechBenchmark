# mech_loadout.gd — Pure data container: holds the player's part selections.
# Use MechCatalog to obtain the available parts to fill a loadout with.
class_name MechLoadout
extends Resource

@export var selected_legs: LegData = null
@export var selected_torso: TorsoData = null
@export var selected_torsos: Array[TorsoData] = []
@export var selected_guns: Array[WeaponData] = []
@export var selected_light_guns: Array[WeaponData] = []
@export var selected_utility_modules: Array = []

## Module grids per torso (not exported to avoid type resolution issues)
var module_grids: Array = []  # Array of ModuleGrid objects

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

## Total utility slots across all equipped torsos.
## Cargo = +2, Stealth = +3, all others = +1.
func get_total_utility_slots() -> int:
	var total := 0
	for t in selected_torsos:
		if t:
			total += MechAssembler.get_utility_slots(t.torso_type)
	if total == 0 and selected_torso:
		total = MechAssembler.get_utility_slots(selected_torso.torso_type)
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
	
	# Apply module bonuses
	var total_recharge_bonus := 0.0
	var total_armor_bonus := 0
	var total_max_health_bonus := 0
	for grid in module_grids:
		if grid:
			total_recharge_bonus += grid.get_recharge_bonus()
			total_armor_bonus += grid.get_armor_bonus()
			total_max_health_bonus += grid.get_max_health_bonus()
	if total_recharge_bonus > 0:
		stats.recharge_rate_bonus = total_recharge_bonus
	if total_armor_bonus > 0:
		stats.armor += total_armor_bonus
	if total_max_health_bonus > 0:
		stats.max_health += total_max_health_bonus
		stats.health += total_max_health_bonus

## Get or create the module grid for a specific torso index
func get_or_create_module_grid(torso_index: int):
	# Ensure we have enough grids
	while module_grids.size() <= torso_index:
		module_grids.append(null)
	
	# Create if missing
	if module_grids[torso_index] == null:
		var _ModuleGrid = load("res://src/player/module_grid.gd")
		module_grids[torso_index] = _ModuleGrid.new(torso_index)
	
	return module_grids[torso_index]

## Get the module grid for a specific torso index (returns null if not created)
func get_module_grid(torso_index: int):
	if torso_index >= 0 and torso_index < module_grids.size():
		return module_grids[torso_index]
	return null

## Calculate total recharge rate bonus from all modules
func get_total_recharge_bonus() -> float:
	var total := 0.0
	for grid in module_grids:
		if grid:
			total += grid.get_recharge_bonus()
	return total

## Calculate total armor bonus from all modules
func get_total_armor_bonus() -> int:
	var total := 0
	for grid in module_grids:
		if grid:
			total += grid.get_armor_bonus()
	return total

## Calculate total max health bonus from all modules
func get_total_max_health_bonus() -> int:
	var total := 0
	for grid in module_grids:
		if grid:
			total += grid.get_max_health_bonus()
	return total

