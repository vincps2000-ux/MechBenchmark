# test_arena_decorations.gd — Unit tests for ArenaDecorations
extends GutTest

var _sut: ArenaDecorations

func before_each():
	_sut = ArenaDecorations.new()

func after_each():
	if is_instance_valid(_sut) and _sut.is_inside_tree():
		_sut.queue_free()
	elif is_instance_valid(_sut):
		_sut.free()

func test_default_arena_half_size():
	assert_eq(_sut.arena_half_size, 1000.0)

func test_z_index_is_negative_after_ready():
	add_child_autofree(_sut)
	assert_lt(_sut.z_index, 0, "Decorations should draw behind world objects")

func test_stains_generated():
	add_child_autofree(_sut)
	assert_eq(_sut._stains.size(), _sut.stain_count, "Should generate stain_count stains")

func test_scorches_generated():
	add_child_autofree(_sut)
	assert_eq(_sut._scorches.size(), _sut.scorch_count, "Should generate scorch_count scorches")

func test_debris_generated():
	add_child_autofree(_sut)
	assert_eq(_sut._debris.size(), _sut.debris_count, "Should generate debris_count debris")

func test_deterministic_generation():
	# Both instances use seed 42, so they should produce identical stain positions
	add_child_autofree(_sut)
	var other := ArenaDecorations.new()
	add_child_autofree(other)
	assert_eq(_sut._stains.size(), other._stains.size())
	if _sut._stains.size() > 0 and other._stains.size() > 0:
		assert_eq(_sut._stains[0]["pos"], other._stains[0]["pos"],
			"Same seed should produce same positions")
