# test_walker_rotation.gd — Tests for walker (LEGS) Q-to-rotate and DirectionArrow
extends GutTest

const _Arrow := preload("res://src/player/direction_arrow.gd")

# ── DirectionArrow — instantiation & visual constants ─────────────────────────

func test_direction_arrow_instantiates():
	var arrow = _Arrow.new()
	assert_not_null(arrow, "DirectionArrow should instantiate via preload")
	arrow.free()

func test_direction_arrow_is_node2d():
	var arrow = _Arrow.new()
	assert_true(arrow is Node2D, "DirectionArrow must extend Node2D")
	arrow.free()

func test_direction_arrow_color_is_red():
	assert_eq(_Arrow.ARROW_COLOR.r, Color(0.95, 0.15, 0.15, 0.55).r,
		"Arrow red channel should match")
	assert_eq(_Arrow.ARROW_COLOR.g, Color(0.95, 0.15, 0.15, 0.55).g,
		"Arrow green channel should match")
	assert_eq(_Arrow.ARROW_COLOR.b, Color(0.95, 0.15, 0.15, 0.55).b,
		"Arrow blue channel should match")

func test_direction_arrow_is_semi_transparent():
	assert_lt(_Arrow.ARROW_COLOR.a, 1.0, "Arrow should be semi-transparent")
	assert_gt(_Arrow.ARROW_COLOR.a, 0.0, "Arrow should still be visible")

func test_direction_arrow_offset_positive():
	assert_gt(_Arrow.ARROW_OFFSET, 0.0,
		"Arrow should be offset in front of the legs")

func test_direction_arrow_length_positive():
	assert_gt(_Arrow.ARROW_LENGTH, 0.0, "Shaft length must be > 0")

func test_direction_arrow_head_length_positive():
	assert_gt(_Arrow.ARROW_HEAD_LENGTH, 0.0, "Head length must be > 0")

func test_direction_arrow_width_positive():
	assert_gt(_Arrow.ARROW_WIDTH, 0.0, "Shaft width must be > 0")

func test_direction_arrow_head_wider_than_shaft():
	assert_gt(_Arrow.ARROW_HEAD_HALF_WIDTH * 2.0, _Arrow.ARROW_WIDTH,
		"Arrowhead should be wider than shaft for visibility")

func test_direction_arrow_head_shorter_than_shaft():
	assert_lt(_Arrow.ARROW_HEAD_LENGTH, _Arrow.ARROW_LENGTH,
		"Arrowhead should be shorter than the shaft")

func test_direction_arrow_has_draw_method():
	var arrow = _Arrow.new()
	assert_true(arrow.has_method("_draw"),
		"DirectionArrow must override _draw()")
	arrow.free()

# ── Walker rotation speed constant ────────────────────────────────────────────

func test_walker_rotation_speed_positive():
	assert_gt(PlayerController.ROTATION_SPEED_WALKER, 0.0,
		"Walker rotation speed must be positive")

func test_walker_rotation_speed_below_full_circle():
	assert_lt(PlayerController.ROTATION_SPEED_WALKER, TAU,
		"Should not rotate a full circle per second (too instant)")

func test_walker_rotation_speed_value():
	assert_eq(PlayerController.ROTATION_SPEED_WALKER, 3.0,
		"Walker rotation speed should be 3.0 rad/s")

# ── Rotation speed relationships across movement types ────────────────────────

func test_walker_faster_than_tank():
	assert_gt(PlayerController.ROTATION_SPEED_WALKER, PlayerController.ROTATION_SPEED_TANK,
		"Walker body should rotate faster than tank treads")

func test_walker_faster_than_spider():
	assert_gt(PlayerController.ROTATION_SPEED_WALKER, PlayerController.ROTATION_SPEED_SPIDER,
		"Walker Q-to-mouse should feel snappier than spider manual rotate")

func test_torso_rotation_fastest():
	assert_gt(PlayerController.TORSO_ROTATION_SPEED, PlayerController.ROTATION_SPEED_WALKER,
		"Torso tracking mouse should be fastest rotation")
	assert_gt(PlayerController.TORSO_ROTATION_SPEED, PlayerController.ROTATION_SPEED_LANDSHIP,
		"Torso tracking mouse should also be faster than landship hull turning")

func test_spider_faster_than_tank():
	assert_gt(PlayerController.ROTATION_SPEED_SPIDER, PlayerController.ROTATION_SPEED_TANK,
		"Spider legs should turn faster than tank treads")

func test_landship_slower_than_tank():
	assert_lt(PlayerController.ROTATION_SPEED_LANDSHIP, PlayerController.ROTATION_SPEED_TANK,
		"Landship should rotate slower than tank")

# ── All PlayerController movement constants ───────────────────────────────────

func test_base_speed_exists():
	assert_eq(PlayerController.BASE_SPEED, 200.0)

func test_tank_forward_multiplier():
	assert_gt(PlayerController.TANK_FORWARD_MULT, 1.0,
		"Tank should have a forward speed bonus")

# ── LegData movement types & sprite paths ────────────────────────────────────

func test_leg_default_is_walker():
	var leg := LegData.new()
	assert_eq(leg.movement_type, LegData.MovementType.LEGS,
		"Default movement type should be LEGS (walker)")

func test_legs_sprite_path_walker():
	var leg := LegData.new()
	leg.movement_type = LegData.MovementType.LEGS
	assert_eq(leg.get_sprite_path(), "res://assets/sprites/legs_bipedal.svg")

func test_legs_sprite_path_spider():
	var leg := LegData.new()
	leg.movement_type = LegData.MovementType.SPIDER
	assert_eq(leg.get_sprite_path(), "res://assets/sprites/legs_spider.svg")

func test_legs_sprite_path_tank():
	var leg := LegData.new()
	leg.movement_type = LegData.MovementType.TANK
	assert_eq(leg.get_sprite_path(), "res://assets/sprites/legs_tank.svg")

func test_legs_sprite_path_landship():
	var leg := LegData.new()
	leg.movement_type = LegData.MovementType.LANDSHIP
	assert_eq(leg.get_sprite_path(), "res://assets/sprites/legs_landship.svg")

func test_each_movement_type_has_unique_sprite():
	var paths := {}
	for mt in [LegData.MovementType.SPIDER, LegData.MovementType.TANK, LegData.MovementType.LEGS]:
		var leg := LegData.new()
		leg.movement_type = mt
		var p := leg.get_sprite_path()
		assert_false(paths.has(p), "Sprite path '%s' reused for type %s" % [p, mt])
		paths[p] = true

func test_leg_default_torso_slots():
	var leg := LegData.new()
	assert_eq(leg.torso_slots, 1, "Walker legs should support 1 torso by default")

func test_leg_speed_modifier_default():
	var leg := LegData.new()
	assert_eq(leg.speed_modifier, 1.0, "Default speed modifier should be 1.0")

# - Torso deadspot clamping -

func test_torso_deadspot_half_angle_is_reasonable():
	assert_gt(PlayerController.TORSO_DEADSPOT_HALF_ANGLE, 0.0)
	assert_lt(PlayerController.TORSO_DEADSPOT_HALF_ANGLE, PI * 0.5)

func test_apply_torso_deadspot_none_keeps_angle():
	var desired := deg_to_rad(90.0)
	var out := PlayerController.apply_torso_deadspot(
		desired,
		PlayerController.TorsoDeadspotSide.NONE
	)
	assert_eq(out, desired, "No deadspot should not modify desired angle")

func test_apply_torso_deadspot_front_blocks_forward_arc():
	var desired := deg_to_rad(0.0)
	var out := PlayerController.apply_torso_deadspot(
		desired,
		PlayerController.TorsoDeadspotSide.FRONT,
		deg_to_rad(30.0)
	)
	assert_true(absf(out - deg_to_rad(-30.0)) < 0.0001,
		"Front deadspot should clamp to boundary")

func test_apply_torso_deadspot_rear_blocks_rear_arc():
	var desired := PI
	var out := PlayerController.apply_torso_deadspot(
		desired,
		PlayerController.TorsoDeadspotSide.REAR,
		deg_to_rad(30.0)
	)
	assert_true(absf(absf(out) - deg_to_rad(150.0)) < 0.0001,
		"Rear deadspot should clamp to boundary")

func test_apply_torso_deadspot_does_not_affect_side_arc():
	var desired := deg_to_rad(90.0)
	var out := PlayerController.apply_torso_deadspot(
		desired,
		PlayerController.TorsoDeadspotSide.FRONT,
		deg_to_rad(30.0)
	)
	assert_eq(out, desired, "Deadspot should not affect side aiming")
