# tests/unit/test_urban_obstacle.gd — Unit tests for UrbanObstacle
extends GutTest

var _sut: UrbanObstacle

func before_each():
	_sut = UrbanObstacle.new()

func after_each():
	_sut.free()

func test_default_shape_is_building():
	assert_eq(_sut.shape_type, UrbanObstacle.Shape.BUILDING, "Default shape should be BUILDING")

func test_default_rect_size():
	assert_eq(_sut.rect_size, Vector2(120, 100), "Default rect_size should be 120x100")

func test_shape_enum_values():
	assert_eq(UrbanObstacle.Shape.BUILDING, 0, "BUILDING should be 0")
	assert_eq(UrbanObstacle.Shape.CAR, 1, "CAR should be 1")
	assert_eq(UrbanObstacle.Shape.DUMPSTER, 2, "DUMPSTER should be 2")
	assert_eq(UrbanObstacle.Shape.BARRICADE, 3, "BARRICADE should be 3")
	assert_eq(UrbanObstacle.Shape.BUS_STOP, 4, "BUS_STOP should be 4")
	assert_eq(UrbanObstacle.Shape.LAMPPOST, 5, "LAMPPOST should be 5")

func test_collision_layer_set_on_ready():
	# Need to add to scene tree for _ready to fire
	add_child(_sut)
	assert_eq(_sut.collision_layer, 16, "Collision layer should be 16 (env layer 5)")
	assert_eq(_sut.collision_mask, 0, "Collision mask should be 0")

func test_building_creates_rect_collision():
	_sut.shape_type = UrbanObstacle.Shape.BUILDING
	_sut.rect_size = Vector2(180, 150)
	add_child(_sut)
	var collision_shapes := []
	for child in _sut.get_children():
		if child is CollisionShape2D:
			collision_shapes.append(child)
	assert_eq(collision_shapes.size(), 1, "Building should have 1 CollisionShape2D")
	var shape: RectangleShape2D = collision_shapes[0].shape as RectangleShape2D
	assert_not_null(shape, "Shape should be RectangleShape2D")
	assert_eq(shape.size, Vector2(180, 150), "Shape size should match rect_size")

func test_car_creates_rect_collision():
	_sut.shape_type = UrbanObstacle.Shape.CAR
	_sut.rect_size = Vector2(80, 40)
	add_child(_sut)
	var collision_shapes := []
	for child in _sut.get_children():
		if child is CollisionShape2D:
			collision_shapes.append(child)
	assert_eq(collision_shapes.size(), 1, "Car should have 1 CollisionShape2D")

func test_lamppost_creates_circle_collision():
	_sut.shape_type = UrbanObstacle.Shape.LAMPPOST
	add_child(_sut)
	var collision_shapes := []
	for child in _sut.get_children():
		if child is CollisionShape2D:
			collision_shapes.append(child)
	assert_eq(collision_shapes.size(), 1, "Lamppost should have 1 CollisionShape2D")
	var shape: CircleShape2D = collision_shapes[0].shape as CircleShape2D
	assert_not_null(shape, "Lamppost shape should be CircleShape2D")
	assert_eq(shape.radius, 8.0, "Lamppost radius should be 8.0")
