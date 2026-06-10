# module_data.gd — Module definition for grid-based module system.
# Modules are equippable components with grid footprints and stat bonuses.
class_name ModuleData
extends MechPartData

## 2D grid footprint: array of (x, y) offsets from top-left corner
@export var grid_shape: Array[Vector2i] = []

## Recharge rate bonus (added to base energy regen per second)
@export var recharge_rate_bonus: float = 0.0

## Flat energy capacity bonus granted by this module
@export var max_energy_bonus: float = 0.0

## Flat armor bonus granted by this module
@export var armor_bonus: int = 0

## Flat max health bonus granted by this module
@export var max_health_bonus: int = 0

## Icon for visual representation in catalogs and grids
@export var module_icon_path: String = ""

enum ReactorType {
	NONE,
	CONVENTIONAL_FUEL,
	NUCLEAR,
	FUSION,
}

const FUEL_REACTOR_DEFAULT_CAPACITY := 100.0
const FUEL_REACTOR_DRAIN_PER_SECOND := 1.0
## Visual color for grid cells (as hex string or color name)
@export var grid_cell_color: Color = Color.SKY_BLUE
## Whether this module opens a reactor customisation flow before placement.
@export var supports_reactor_customization: bool = false
## Chosen reactor type for customisable 2x2 reactors.
@export var reactor_type: int = ReactorType.NONE
@export var reactor_fuel_current: float = 0.0
@export var reactor_fuel_max: float = 0.0

func duplicate_module() -> ModuleData:
	var copy = duplicate(true) as ModuleData
	copy.grid_shape = grid_shape.duplicate()
	return copy

func is_customizable_reactor() -> bool:
	return supports_reactor_customization

func set_reactor_type(value: int) -> void:
	if not supports_reactor_customization:
		reactor_type = ReactorType.NONE
		return
	reactor_type = clampi(value, ReactorType.CONVENTIONAL_FUEL, ReactorType.FUSION)
	if reactor_type == ReactorType.CONVENTIONAL_FUEL:
		if reactor_fuel_max <= 0.0:
			reactor_fuel_max = FUEL_REACTOR_DEFAULT_CAPACITY
		if reactor_fuel_current <= 0.0:
			reactor_fuel_current = reactor_fuel_max

func get_reactor_type_name() -> String:
	match reactor_type:
		ReactorType.CONVENTIONAL_FUEL:
			return "Fuel Reactor"
		ReactorType.NUCLEAR:
			return "Nuclear Reactor"
		ReactorType.FUSION:
			return "Fusion Reactor"
		_:
			return "Standard Reactor"

func get_reactor_core_color() -> Color:
	match reactor_type:
		ReactorType.CONVENTIONAL_FUEL:
			return Color(0.96, 0.62, 0.22, 1.0)
		ReactorType.NUCLEAR:
			return Color(0.67, 0.96, 0.26, 1.0)
		ReactorType.FUSION:
			return Color(0.95, 0.38, 0.82, 1.0)
		_:
			return grid_cell_color.lightened(0.35)

func get_effective_recharge_rate_bonus() -> float:
	if not supports_reactor_customization:
		return recharge_rate_bonus
	if reactor_type == ReactorType.CONVENTIONAL_FUEL:
		if reactor_fuel_current <= 0.0:
			return 0.0
		return recharge_rate_bonus * 2.0
	if reactor_type == ReactorType.FUSION:
		return recharge_rate_bonus * 3.0
	return recharge_rate_bonus

func has_fusion_regen_cooldown() -> bool:
	return supports_reactor_customization and reactor_type == ReactorType.FUSION

func is_fuel_reactor() -> bool:
	return supports_reactor_customization and reactor_type == ReactorType.CONVENTIONAL_FUEL

func get_reactor_fuel_current() -> float:
	return reactor_fuel_current if is_fuel_reactor() else 0.0

func get_reactor_fuel_max() -> float:
	return reactor_fuel_max if is_fuel_reactor() else 0.0

func consume_reactor_fuel(delta: float) -> void:
	if not is_fuel_reactor() or delta <= 0.0 or reactor_fuel_current <= 0.0:
		return
	reactor_fuel_current = maxf(0.0, reactor_fuel_current - FUEL_REACTOR_DRAIN_PER_SECOND * delta)

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
	if max_health_bonus != 0:
		stats.max_health += max_health_bonus
		stats.health += max_health_bonus
	if armor_bonus != 0:
		stats.armor += armor_bonus
	# Recharge rate bonus will be handled in PlayerController
	# This is here for stat consistency
