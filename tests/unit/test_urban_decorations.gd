# tests/unit/test_urban_decorations.gd — Unit tests for UrbanDecorations
extends GutTest

var _sut: UrbanDecorations

func before_each():
	_sut = UrbanDecorations.new()

func after_each():
	_sut.free()

func test_default_arena_half_size():
	assert_eq(_sut.arena_half_size, 1200.0, "Default arena half size should be 1200")

func test_default_puddle_count():
	assert_eq(_sut.puddle_count, 18, "Default puddle count should be 18")

func test_default_skid_count():
	assert_eq(_sut.skid_count, 10, "Default skid count should be 10")

func test_default_trash_count():
	assert_eq(_sut.trash_count, 20, "Default trash count should be 20")

func test_default_light_count():
	assert_eq(_sut.light_count, 12, "Default light count should be 12")

func test_decorations_generated_on_ready():
	add_child(_sut)
	# After _ready, internal arrays should be populated
	assert_eq(_sut._puddles.size(), 18, "Should generate 18 puddles")
	assert_eq(_sut._skids.size(), 10, "Should generate 10 skid marks")
	assert_eq(_sut._trash.size(), 20, "Should generate 20 trash piles")
	assert_eq(_sut._lights.size(), 12, "Should generate 12 street lights")

func test_z_index_is_negative():
	add_child(_sut)
	assert_eq(_sut.z_index, -1, "Z-index should be -1 to draw behind world objects")

func test_deterministic_generation():
	# Same seed (77) should produce same decorations every time
	add_child(_sut)
	var first_puddle_pos: Vector2 = _sut._puddles[0]["pos"]
	remove_child(_sut)
	_sut.free()

	_sut = UrbanDecorations.new()
	add_child(_sut)
	var second_puddle_pos: Vector2 = _sut._puddles[0]["pos"]
	assert_eq(first_puddle_pos, second_puddle_pos, "Decorations should be deterministic (same seed)")

func test_parking_lots_exist():
	add_child(_sut)
	assert_gt(_sut._parking_lots.size(), 0, "Should have at least one parking lot")
