# test_leg_data.gd — Unit tests for LegData resource
extends GutTest

var legs: LegData

func before_each():
	legs = LegData.new()
	legs.name = "Test Legs"
	legs.speed_modifier = 1.0
	legs.health_modifier = 1.0
	legs.description = "Test legs for testing"

func test_initial_state():
	assert_eq(legs.name, "Test Legs")
	assert_eq(legs.speed_modifier, 1.0)
	assert_eq(legs.health_modifier, 1.0)
	assert_eq(legs.description, "Test legs for testing")

func test_tank_legs_are_slow_but_tanky():
	legs.name = "Tank"
	legs.speed_modifier = 0.6
	legs.health_modifier = 1.8
	assert_lt(legs.speed_modifier, 1.0, "Tank should be slower than default")
	assert_gt(legs.health_modifier, 1.0, "Tank should have more health than default")

func test_spider_legs_are_fast_but_fragile():
	legs.name = "Spider"
	legs.speed_modifier = 1.5
	legs.health_modifier = 0.7
	assert_gt(legs.speed_modifier, 1.0, "Spider should be faster than default")
	assert_lt(legs.health_modifier, 1.0, "Spider should have less health than default")

func test_apply_to_stats():
	var stats = PlayerStats.new()
	var base_speed = stats.speed
	var base_health = stats.max_health
	legs.speed_modifier = 1.5
	legs.health_modifier = 0.8
	legs.apply_to_stats(stats)
	assert_eq(stats.speed, base_speed * 1.5, "Speed should be multiplied by modifier")
	assert_eq(stats.max_health, int(base_health * 0.8), "Max health should be multiplied by modifier")
	assert_eq(stats.health, stats.max_health, "Current health should equal max health after apply")
