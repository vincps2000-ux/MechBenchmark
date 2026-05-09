# module_data.gd — Module definition for grid-based module system.
# Modules are equippable components with grid footprints and stat bonuses.
class_name ModuleData
extends MechPartData

## 2D grid footprint: array of (x, y) offsets from top-left corner
@export var grid_shape: Array[Vector2i] = []

## Recharge rate bonus (added to base energy regen per second)
@export var recharge_rate_bonus: float = 0.0

## Flat armor bonus granted by this module
@export var armor_bonus: int = 0

## Icon for visual representation in catalogs and grids
@export var module_icon_path: String = ""

## Visual color for grid cells (as hex string or color name)
@export var grid_cell_color: Color = Color.SKY_BLUE

## Get the bounding box of this module's grid shape
func get_grid_bounds() -> Rect2i:
	if grid_shape.is_empty():
		return Rect2i(0, 0, 0, 0)
	
	var min_x := grid_shape[0].x
	var max_x := grid_shape[0].x
	var min_y := grid_shape[0].y
	var max_y := grid_shape[0].y
	
	for pos in grid_shape:
		min_x = mini(min_x, pos.x)
		max_x = maxi(max_x, pos.x)
		min_y = mini(min_y, pos.y)
		max_y = maxi(max_y, pos.y)
	
	var width := max_x - min_x + 1
	var height := max_y - min_y + 1
	
	return Rect2i(min_x, min_y, width, height)

## Check if this module can fit in the given grid at the specified position
func can_fit_at(grid: Array[Array], position: Vector2i, grid_bounds: Vector2i) -> bool:
	for cell_offset in grid_shape:
		var world_pos := position + cell_offset
		
		# Out of bounds?
		if world_pos.x < 0 or world_pos.x >= grid_bounds.x:
			return false
		if world_pos.y < 0 or world_pos.y >= grid_bounds.y:
			return false
		
		# Cell already occupied?
		if grid[world_pos.y][world_pos.x] != null:
			return false
	
	return true

## Place this module on the grid at the specified position
func place_on_grid(grid: Array[Array], position: Vector2i) -> void:
	for cell_offset in grid_shape:
		var world_pos := position + cell_offset
		grid[world_pos.y][world_pos.x] = self

## Remove this module from the grid (all its cells)
func remove_from_grid(grid: Array[Array], position: Vector2i) -> void:
	for cell_offset in grid_shape:
		var world_pos := position + cell_offset
		grid[world_pos.y][world_pos.x] = null

## Apply this module's bonuses to PlayerStats
func apply_to_stats(stats: PlayerStats) -> void:
	super.apply_to_stats(stats)
	if armor_bonus != 0:
		stats.armor += armor_bonus
	# Recharge rate bonus will be handled in PlayerController
	# This is here for stat consistency
