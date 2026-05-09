# module_grid.gd — Represents the state of modules placed on a single torso's grid.
class_name ModuleGrid
extends Resource

const _ModuleData = preload("res://src/player/module_data.gd")

## The torso this grid belongs to (reference to identify which torso)
@export var torso_index: int = 0

## Serialized grid state: array of (module_data, position) pairs
## Each entry is: {"module": ModuleData, "position": Vector2i}
@export var placements: Array[Dictionary] = []

## Initialize an empty grid for a specific torso
func _init(p_torso_index: int = 0) -> void:
	torso_index = p_torso_index
	placements = []

## Add a module placement at the given position
func place_module(module, position: Vector2i) -> void:
	placements.append({
		"module": module,
		"position": position
	})

## Remove a module placement at the given position
func remove_module_at(position: Vector2i):
	for i in range(placements.size()):
		if placements[i]["position"] == position:
			var module = placements[i]["module"]
			placements.remove_at(i)
			return module
	return null

## Get the module at the given position (if any)
func get_module_at(position: Vector2i):
	for placement in placements:
		if placement["position"] == position:
			return placement["module"]
	return null

## Check if a module occupies any of the given positions
func is_occupied_at_any(positions: Array[Vector2i]) -> bool:
	for pos in positions:
		if get_module_at(pos) != null:
			return true
	return false

## Get total recharge rate bonus from all placed modules
func get_recharge_bonus() -> float:
	var total := 0.0
	for placement in placements:
		var module = placement["module"]
		if module:
			total += module.recharge_rate_bonus
	return total

## Get total armor bonus from all placed modules
func get_armor_bonus() -> int:
	var total := 0
	for placement in placements:
		var module = placement["module"]
		if module:
			total += int(module.armor_bonus)
	return total

## Clear all placements
func clear() -> void:
	placements.clear()

## Get all unique modules currently placed
func get_placed_modules() -> Array:
	var modules: Array = []
	for placement in placements:
		var module = placement["module"]
		if module and module not in modules:
			modules.append(module)
	return modules
