# test_engineering_system.gd — Unit tests for module grid system
extends GutTest

const _ModuleData = preload("res://src/player/module_data.gd")
const _ModuleGrid = preload("res://src/player/module_grid.gd")

var _module_2x2
var _module_1x1

func before_each() -> void:
	# Create test modules
	_module_2x2 = _ModuleData.new()
	_module_2x2.name = "Test 2x2"
	var shape_2x2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	_module_2x2.grid_shape = shape_2x2
	_module_2x2.recharge_rate_bonus = 50.0
	_module_2x2.grid_cell_color = Color.BLUE
	
	_module_1x1 = _ModuleData.new()
	_module_1x1.name = "Test 1x1"
	var shape_1x1: Array[Vector2i] = [Vector2i(0, 0)]
	_module_1x1.grid_shape = shape_1x1
	_module_1x1.recharge_rate_bonus = 25.0
	_module_1x1.grid_cell_color = Color.CYAN

func test_module_grid_bounds() -> void:
	var bounds = _module_2x2.get_grid_bounds()
	assert_eq(bounds, Rect2i(0, 0, 2, 2), "2x2 module bounds should be (0,0,2,2)")
	
	var bounds_1x1 = _module_1x1.get_grid_bounds()
	assert_eq(bounds_1x1, Rect2i(0, 0, 1, 1), "1x1 module bounds should be (0,0,1,1)")

func test_module_grid_data_class() -> void:
	var grid = _ModuleGrid.new()
	
	# Initially empty
	assert_eq(grid.get_recharge_bonus(), 0.0, "Empty grid should have 0 bonus")
	
	# Place module
	grid.place_module(_module_2x2, Vector2i(0, 0))
	assert_eq(grid.get_recharge_bonus(), 50.0, "Grid with 2x2 should have 50 bonus")
	
	# Place another
	grid.place_module(_module_1x1, Vector2i(2, 0))
	assert_eq(grid.get_recharge_bonus(), 75.0, "Grid with both should have 75 bonus")
	assert_eq(grid.get_armor_bonus(), 0, "Grid should have zero armor bonus when modules have none")

func test_mech_loadout_module_grid_creation() -> void:
	var loadout = MechLoadout.new()
	
	# Get or create grid
	var grid = loadout.get_or_create_module_grid(0)
	assert_not_null(grid, "Should create grid")
	
	# Getting same grid again should return same instance
	var grid2 = loadout.get_or_create_module_grid(0)
	assert_eq(grid, grid2, "Should return same grid instance")

func test_mech_loadout_total_recharge_bonus() -> void:
	var loadout = MechLoadout.new()
	
	# Add modules to grid 0
	var grid0 = loadout.get_or_create_module_grid(0)
	grid0.place_module(_module_2x2, Vector2i(0, 0))
	
	# Add modules to grid 1
	var grid1 = loadout.get_or_create_module_grid(1)
	grid1.place_module(_module_1x1, Vector2i(0, 0))
	
	var total = loadout.get_total_recharge_bonus()
	assert_eq(total, 75.0, "Total bonus should be 75 (50 + 25)")

func test_module_bounds_single_cell() -> void:
	var bounds = _module_1x1.get_grid_bounds()
	assert_eq(bounds.size.x, 1, "1x1 width should be 1")
	assert_eq(bounds.size.y, 1, "1x1 height should be 1")

func test_mech_loadout_total_armor_bonus() -> void:
	var loadout = MechLoadout.new()
	var armor_2x1 = _ModuleData.new()
	armor_2x1.name = "Armor 2x1"
	var armor_2x1_shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	armor_2x1.grid_shape = armor_2x1_shape
	armor_2x1.armor_bonus = 3

	var armor_1x1 = _ModuleData.new()
	armor_1x1.name = "Armor 1x1"
	var armor_1x1_shape: Array[Vector2i] = [Vector2i(0, 0)]
	armor_1x1.grid_shape = armor_1x1_shape
	armor_1x1.armor_bonus = 1

	var grid0 = loadout.get_or_create_module_grid(0)
	grid0.place_module(armor_2x1, Vector2i(0, 0))

	var grid1 = loadout.get_or_create_module_grid(1)
	grid1.place_module(armor_1x1, Vector2i(0, 0))

	assert_eq(loadout.get_total_armor_bonus(), 4, "Total armor bonus should be 4 (3 + 1)")

func test_catalog_contains_armor_modules_with_expected_bonuses() -> void:
	var modules = MechCatalog.get_all_modules()
	var armor_2x1 = null
	var armor_1x1 = null
	for module in modules:
		if module.name == "Armor Module (2x1)":
			armor_2x1 = module
		elif module.name == "Armor Module (1x1)":
			armor_1x1 = module

	assert_not_null(armor_2x1, "Catalog should include Armor Module (2x1)")
	assert_not_null(armor_1x1, "Catalog should include Armor Module (1x1)")
	if armor_2x1 != null:
		assert_eq(armor_2x1.armor_bonus, 3, "2x1 armor module should grant +3 armor")
		assert_eq(armor_2x1.grid_shape.size(), 2, "2x1 armor module should use two cells")
	if armor_1x1 != null:
		assert_eq(armor_1x1.armor_bonus, 1, "1x1 armor module should grant +1 armor")
		assert_eq(armor_1x1.grid_shape.size(), 1, "1x1 armor module should use one cell")

func test_loadout_apply_stats_includes_module_armor_bonus() -> void:
	var loadout = MechLoadout.new()
	var armor_2x1 = _ModuleData.new()
	armor_2x1.name = "Armor 2x1"
	var armor_2x1_shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	armor_2x1.grid_shape = armor_2x1_shape
	armor_2x1.armor_bonus = 3
	var armor_1x1 = _ModuleData.new()
	armor_1x1.name = "Armor 1x1"
	var armor_1x1_shape: Array[Vector2i] = [Vector2i(0, 0)]
	armor_1x1.grid_shape = armor_1x1_shape
	armor_1x1.armor_bonus = 1

	var grid = loadout.get_or_create_module_grid(0)
	grid.place_module(armor_2x1, Vector2i(0, 0))
	grid.place_module(armor_1x1, Vector2i(2, 0))

	var stats = PlayerStats.new()
	stats.armor = 5
	loadout.apply_to_stats(stats)

	assert_eq(stats.armor, 9, "Armor modules should add +4 total armor to stats")


