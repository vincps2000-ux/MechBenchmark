# test_arena_obstacle.gd — Unit tests for ArenaObstacle
extends GutTest

var _sut: ArenaObstacle

func before_each():
	_sut = ArenaObstacle.new()

func after_each():
	_sut.free()

func test_default_shape_is_crate():
	assert_eq(_sut.shape_type, ArenaObstacle.Shape.CRATE)

func test_collision_layer_set_on_ready():
	# We need to add to tree for _ready to fire
	add_child_autofree(_sut)
	assert_eq(_sut.collision_layer, 16, "Obstacles should be on environment layer 5 (bit 16)")

func test_collision_mask_is_zero():
	add_child_autofree(_sut)
	assert_eq(_sut.collision_mask, 0, "Obstacles should not detect collisions themselves")

func test_crate_creates_collision_shape():
	_sut.shape_type = ArenaObstacle.Shape.CRATE
	add_child_autofree(_sut)
	var shapes := _count_collision_shapes(_sut)
	assert_eq(shapes, 1, "Crate should have 1 collision shape")

func test_barrel_creates_circle_shape():
	_sut.shape_type = ArenaObstacle.Shape.BARREL
	add_child_autofree(_sut)
	var shapes := _count_collision_shapes(_sut)
	assert_eq(shapes, 1, "Barrel should have 1 collision shape")

func test_l_shape_creates_two_collision_shapes():
	_sut.shape_type = ArenaObstacle.Shape.L_SHAPE
	add_child_autofree(_sut)
	var shapes := _count_collision_shapes(_sut)
	assert_eq(shapes, 2, "L-shape should have 2 collision shapes")

func test_wall_h_creates_collision_shape():
	_sut.shape_type = ArenaObstacle.Shape.WALL_H
	_sut.rect_size = Vector2(200, 30)
	add_child_autofree(_sut)
	var shapes := _count_collision_shapes(_sut)
	assert_eq(shapes, 1, "Horizontal wall should have 1 collision shape")

func test_custom_rect_size():
	_sut.rect_size = Vector2(120, 40)
	assert_eq(_sut.rect_size, Vector2(120, 40))

func _count_collision_shapes(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is CollisionShape2D:
			count += 1
	return count
