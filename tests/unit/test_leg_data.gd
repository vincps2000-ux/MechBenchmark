# test_leg_data.gd — Unit tests for LegData resource
extends GutTest

var legs: LegData

func before_each():
	legs = LegData.new()
	legs.name = "Test Legs"
	legs.speed_modifier = 1.0
	legs.description = "Test legs for testing"

func test_initial_state():
	assert_eq(legs.name, "Test Legs")
	assert_eq(legs.speed_modifier, 1.0)
	assert_eq(legs.description, "Test legs for testing")

func test_tank_legs_are_slow():
	legs.name = "Tank"
	legs.speed_modifier = 0.6
	assert_lt(legs.speed_modifier, 1.0, "Tank should be slower than default")

func test_spider_legs_are_fast():
	legs.name = "Spider"
	legs.speed_modifier = 1.5
	assert_gt(legs.speed_modifier, 1.0, "Spider should be faster than default")

func test_apply_to_stats():
	var stats = PlayerStats.new()
	var base_speed = stats.speed
	legs.speed_modifier = 1.5
	legs.apply_to_stats(stats)
	assert_eq(stats.speed, base_speed * 1.5, "Speed should be multiplied by modifier")
