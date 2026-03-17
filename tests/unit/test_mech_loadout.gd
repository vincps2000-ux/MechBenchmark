# test_mech_loadout.gd — Unit tests for MechLoadout resource
extends GutTest

var loadout: MechLoadout

func before_each():
	loadout = MechLoadout.new()

func test_initial_state_has_no_selection():
	assert_null(loadout.selected_legs, "Should have no legs selected initially")
	assert_null(loadout.selected_gun, "Should have no gun selected initially")

func test_is_valid_requires_both_selections():
	assert_false(loadout.is_valid(), "Empty loadout should not be valid")

	loadout.selected_legs = LegData.new()
	assert_false(loadout.is_valid(), "Loadout with only legs should not be valid")

	loadout.selected_gun = WeaponData.new()
	assert_true(loadout.is_valid(), "Loadout with legs and gun should be valid")

func test_set_legs():
	var legs = LegData.new()
	legs.name = "Tank"
	loadout.selected_legs = legs
	assert_eq(loadout.selected_legs.name, "Tank")

func test_set_gun():
	var gun = WeaponData.new()
	gun.name = "Autocannon"
	loadout.selected_gun = gun
	assert_eq(loadout.selected_gun.name, "Autocannon")

func test_apply_to_stats():
	var legs = LegData.new()
	legs.speed_modifier = 0.6
	legs.health_modifier = 1.8

	loadout.selected_legs = legs
	loadout.selected_gun = WeaponData.new()

	var stats = PlayerStats.new()
	loadout.apply_to_stats(stats)
	assert_eq(stats.speed, 200.0 * 0.6, "Stats speed should reflect leg modifier")
	assert_eq(stats.max_health, int(100 * 1.8), "Stats health should reflect leg modifier")

func test_get_all_legs_returns_four():
	var all_legs = MechLoadout.get_all_legs()
	assert_eq(all_legs.size(), 4, "Should have 4 leg types")

func test_get_all_legs_names():
	var all_legs = MechLoadout.get_all_legs()
	var names = []
	for leg in all_legs:
		names.append(leg.name)
	assert_has(names, "Tank", "Should include Tank legs")
	assert_has(names, "Heavy Walker", "Should include Heavy Walker legs")
	assert_has(names, "Light Walker", "Should include Light Walker legs")
	assert_has(names, "Spider", "Should include Spider legs")

func test_get_all_guns_returns_four():
	var all_guns = MechLoadout.get_all_guns()
	assert_eq(all_guns.size(), 4, "Should have 4 gun types")

func test_get_all_guns_names():
	var all_guns = MechLoadout.get_all_guns()
	var names = []
	for gun in all_guns:
		names.append(gun.name)
	assert_has(names, "Autocannon", "Should include Autocannon")
	assert_has(names, "Flamethrower", "Should include Flamethrower")
	assert_has(names, "Railgun", "Should include Railgun")
	assert_has(names, "Laser", "Should include Laser")
