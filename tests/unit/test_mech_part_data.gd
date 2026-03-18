# test_mech_part_data.gd — Unit tests for MechPartData base class
extends GutTest

var part: MechPartData

func before_each():
	part = MechPartData.new()

func test_default_speed_modifier():
	assert_eq(part.speed_modifier, 1.0, "Default speed modifier should be 1.0 (no change)")

func test_default_health_modifier():
	assert_eq(part.health_modifier, 1.0, "Default health modifier should be 1.0 (no change)")

func test_apply_to_stats_multiplies_speed():
	var stats := PlayerStats.new()
	part.speed_modifier = 1.5
	part.health_modifier = 1.0
	part.apply_to_stats(stats)
	assert_eq(stats.speed, 200.0 * 1.5, "Speed should be multiplied by modifier")

func test_apply_to_stats_multiplies_health():
	var stats := PlayerStats.new()
	part.speed_modifier  = 1.0
	part.health_modifier = 0.8
	part.apply_to_stats(stats)
	assert_eq(stats.max_health, int(100 * 0.8), "Max health should be multiplied by modifier")

func test_apply_to_stats_resets_health_to_max():
	var stats := PlayerStats.new()
	stats.take_damage(50)
	part.apply_to_stats(stats)
	assert_eq(stats.health, stats.max_health, "Current health should be reset to max after apply")

func test_identity_modifier_leaves_stats_unchanged():
	var stats := PlayerStats.new()
	var orig_speed  := stats.speed
	var orig_health := stats.max_health
	part.apply_to_stats(stats)
	assert_eq(stats.speed, orig_speed, "Speed should be unchanged with modifier 1.0")
	assert_eq(stats.max_health, orig_health, "Health should be unchanged with modifier 1.0")

func test_leg_data_inherits_apply_to_stats():
	var legs := LegData.new()
	legs.speed_modifier  = 1.3
	legs.health_modifier = 0.9
	var stats := PlayerStats.new()
	legs.apply_to_stats(stats)
	assert_eq(stats.speed, 200.0 * 1.3, "LegData should inherit apply_to_stats from MechPartData")

func test_torso_data_inherits_apply_to_stats():
	var torso := TorsoData.new()
	torso.speed_modifier  = 0.7
	torso.health_modifier = 1.6
	var stats := PlayerStats.new()
	torso.apply_to_stats(stats)
	assert_eq(stats.max_health, int(100 * 1.6), "TorsoData should inherit apply_to_stats from MechPartData")
