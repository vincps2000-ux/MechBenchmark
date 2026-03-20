# test_mech_part_data.gd — Unit tests for MechPartData base class
extends GutTest

var part: MechPartData

func before_each():
	part = MechPartData.new()

func test_default_speed_modifier():
	assert_eq(part.speed_modifier, 1.0, "Default speed modifier should be 1.0 (no change)")

func test_apply_to_stats_multiplies_speed():
	var stats := PlayerStats.new()
	part.speed_modifier = 1.5
	part.apply_to_stats(stats)
	assert_eq(stats.speed, 200.0 * 1.5, "Speed should be multiplied by modifier")

func test_apply_to_stats_does_not_change_integrity():
	var stats := PlayerStats.new()
	part.apply_to_stats(stats)
	assert_eq(stats.max_integrity, 4, "Base part should not change integrity")

func test_identity_modifier_leaves_speed_unchanged():
	var stats := PlayerStats.new()
	var orig_speed := stats.speed
	part.apply_to_stats(stats)
	assert_eq(stats.speed, orig_speed, "Speed should be unchanged with modifier 1.0")

func test_leg_data_inherits_apply_to_stats():
	var legs := LegData.new()
	legs.speed_modifier = 1.3
	var stats := PlayerStats.new()
	legs.apply_to_stats(stats)
	assert_eq(stats.speed, 200.0 * 1.3, "LegData should inherit apply_to_stats from MechPartData")

func test_torso_data_sets_integrity():
	var torso := TorsoData.new()
	torso.speed_modifier = 0.7
	torso.integrity = 8
	var stats := PlayerStats.new()
	torso.apply_to_stats(stats)
	assert_eq(stats.max_integrity, 8, "TorsoData should set integrity on stats")
	assert_eq(stats.integrity, 8, "TorsoData should set current integrity to max")
