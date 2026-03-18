# test_mech_loadout.gd — Unit tests for MechLoadout resource
extends GutTest

var loadout: MechLoadout

func before_each():
	loadout = MechLoadout.new()

func test_initial_state_has_no_selection():
	assert_null(loadout.selected_legs, "Should have no legs selected initially")
	assert_null(loadout.selected_gun, "Should have no gun selected initially")

func test_is_valid_requires_all_three_parts():
	assert_false(loadout.is_valid(), "Empty loadout should not be valid")

	loadout.selected_legs = LegData.new()
	assert_false(loadout.is_valid(), "Loadout with only legs should not be valid")

	loadout.selected_torso = TorsoData.new()
	assert_false(loadout.is_valid(), "Loadout with legs + torso but no gun should not be valid")

	loadout.selected_gun = WeaponData.new()
	assert_true(loadout.is_valid(), "Loadout with all three parts should be valid")

func test_set_legs():
	var legs := LegData.new()
	legs.name = "Tank"
	loadout.selected_legs = legs
	assert_eq(loadout.selected_legs.name, "Tank")

func test_set_gun():
	var gun := WeaponData.new()
	gun.name = "Autocannon"
	loadout.selected_gun = gun
	assert_eq(loadout.selected_gun.name, "Autocannon")

func test_apply_to_stats_applies_leg_modifier():
	var legs := LegData.new()
	legs.speed_modifier  = 0.6
	legs.health_modifier = 1.8

	loadout.selected_legs = legs

	var stats := PlayerStats.new()
	loadout.apply_to_stats(stats)
	assert_eq(stats.speed, 200.0 * 0.6, "Speed should reflect leg modifier")
	assert_eq(stats.max_health, int(100 * 1.8), "Health should reflect leg modifier")

func test_apply_to_stats_compounds_legs_and_torso():
	var legs := LegData.new()
	legs.speed_modifier  = 1.0
	legs.health_modifier = 1.5

	var torso := TorsoData.new()
	torso.speed_modifier  = 1.0
	torso.health_modifier = 0.8

	loadout.selected_legs  = legs
	loadout.selected_torso = torso

	var stats := PlayerStats.new()
	loadout.apply_to_stats(stats)
	# Compound: legs apply first, then torso multiplies the result
	var expected_health := int(int(100 * 1.5) * 0.8)
	assert_eq(stats.max_health, expected_health, "Compound health modifiers should be applied in sequence")
