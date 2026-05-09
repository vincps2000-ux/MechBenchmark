# grid_layout.gd — Utility class for torso-specific grid configurations.
# Each torso type has a unique grid layout for module placement.
class_name GridLayout

enum GridType {
	HEAVY_3X3,
	STEALTH_T,
	CARGO_PYRAMID
}

## Get the grid type for a torso type string
static func get_grid_type(torso_type) -> GridType:
	match torso_type:
		TorsoData.TorsoType.HEAVY_ARMOUR:
			return GridType.HEAVY_3X3
		TorsoData.TorsoType.STEALTH:
			return GridType.STEALTH_T
		TorsoData.TorsoType.CARGO:
			return GridType.CARGO_PYRAMID
	return GridType.HEAVY_3X3  # Default

## Get all valid grid cells for a given grid type
static func get_grid_shape(grid_type: GridType) -> Array[Vector2i]:
	match grid_type:
		GridType.HEAVY_3X3:
			return get_heavy_grid()
		GridType.STEALTH_T:
			return get_stealth_grid()
		GridType.CARGO_PYRAMID:
			return get_cargo_grid()
	return []

## Heavy: 3x3 grid (all 9 cells)
static func get_heavy_grid() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(3):
		for x in range(3):
			cells.append(Vector2i(x, y))
	return cells

## Stealth: T-shaped (5 cells)
## Layout:
##   X
##  XXX
##   X
static func get_stealth_grid() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),  # top
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),  # middle row
		Vector2i(1, 2),  # bottom
	]

## Cargo: Pyramid (5 cells top, 3 middle, 1 bottom = 9 cells)
## Layout:
##  XXXXX
##   XXX
##    X
static func get_cargo_grid() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	# Top row: 5 cells (x=0 to 4, y=0)
	for x in range(5):
		cells.append(Vector2i(x, 0))
	# Middle row: 3 cells (x=1 to 3, y=1)
	for x in range(1, 4):
		cells.append(Vector2i(x, 1))
	# Bottom row: 1 cell (x=2, y=2)
	cells.append(Vector2i(2, 2))
	return cells

## Get the grid dimensions (width, height) for a given grid type
static func get_grid_dimensions(grid_type: GridType) -> Vector2i:
	match grid_type:
		GridType.HEAVY_3X3:
			return Vector2i(3, 3)
		GridType.STEALTH_T:
			return Vector2i(3, 3)
		GridType.CARGO_PYRAMID:
			return Vector2i(5, 3)
	return Vector2i(1, 1)

## Create an empty grid (2D array of nulls) for the given grid type
static func create_empty_grid(grid_type: GridType) -> Array[Array]:
	var dims := get_grid_dimensions(grid_type)
	var grid: Array[Array] = []
	for y in range(dims.y):
		var row: Array = []
		for x in range(dims.x):
			row.append(null)
		grid.append(row)
	return grid

## Check if a position is valid within the grid bounds
static func is_position_valid(grid_type: GridType, position: Vector2i) -> bool:
	var dims := get_grid_dimensions(grid_type)
	return position.x >= 0 and position.x < dims.x and position.y >= 0 and position.y < dims.y

## Get a visual representation of the grid (for debugging)
static func grid_to_string(grid: Array[Array]) -> String:
	var result := ""
	for row in grid:
		for cell in row:
			if cell == null:
				result += "."
			else:
				result += "#"
		result += "\n"
	return result
