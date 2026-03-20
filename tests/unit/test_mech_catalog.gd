# test_mech_catalog.gd — Unit tests for MechCatalog factory class
extends GutTest

# ── Torsos ───────────────────────────────────────────────────────────────────

func test_get_all_torsos_returns_three():
	var torsos := MechCatalog.get_all_torsos()
	assert_eq(torsos.size(), 3, "Should have 3 torso types")

func test_get_all_torso_names():
	var torsos := MechCatalog.get_all_torsos()
	var names: Array = []
	for t in torsos:
		names.append(t.name)
	assert_has(names, "Stealth",      "Should include Stealth torso")
	assert_has(names, "Heavy Armour", "Should include Heavy Armour torso")
	assert_has(names, "Cargo",        "Should include Cargo torso")

func test_torso_types_are_correct():
	var torsos := MechCatalog.get_all_torsos()
	var type_by_name := {}
	for t in torsos:
		type_by_name[t.name] = t.torso_type
	assert_eq(type_by_name["Stealth"],      TorsoData.TorsoType.STEALTH,      "Stealth has wrong TorsoType")
	assert_eq(type_by_name["Heavy Armour"], TorsoData.TorsoType.HEAVY_ARMOUR, "Heavy Armour has wrong TorsoType")
	assert_eq(type_by_name["Cargo"],        TorsoData.TorsoType.CARGO,        "Cargo has wrong TorsoType")

func test_stealth_torso_is_fast_and_fragile():
	var torsos := MechCatalog.get_all_torsos()
	for t in torsos:
		if t.name == "Stealth":
			assert_gt(t.speed_modifier, 1.0, "Stealth torso should be faster than baseline")
			assert_eq(t.integrity, 2, "Stealth torso should have 2 integrity")
			return
	fail_test("Stealth torso not found in catalog")

func test_heavy_torso_is_slow_and_tanky():
	var torsos := MechCatalog.get_all_torsos()
	for t in torsos:
		if t.name == "Heavy Armour":
			assert_lt(t.speed_modifier, 1.0, "Heavy torso should be slower than baseline")
			assert_eq(t.integrity, 8, "Heavy torso should have 8 integrity")
			return
	fail_test("Heavy Armour torso not found in catalog")

# ── Legs ──────────────────────────────────────────────────────────────────────

func test_get_all_legs_returns_four():
	var legs := MechCatalog.get_all_legs()
	assert_eq(legs.size(), 4, "Should have 4 leg types")

func test_get_all_legs_names():
	var legs := MechCatalog.get_all_legs()
	var names: Array = []
	for leg in legs:
		names.append(leg.name)
	assert_has(names, "Tank",         "Should include Tank legs")
	assert_has(names, "Heavy Walker", "Should include Heavy Walker legs")
	assert_has(names, "Light Walker", "Should include Light Walker legs")
	assert_has(names, "Spider",       "Should include Spider legs")

func test_spider_legs_are_fast_but_fragile():
	var legs := MechCatalog.get_all_legs()
	for leg in legs:
		if leg.name == "Spider":
			assert_gt(leg.speed_modifier, 1.0, "Spider should be faster than baseline")
			return
	fail_test("Spider legs not found in catalog")

func test_tank_legs_are_slow_but_tanky():
	var legs := MechCatalog.get_all_legs()
	for leg in legs:
		if leg.name == "Tank":
			assert_lt(leg.speed_modifier, 1.0, "Tank should be slower than baseline")
			return
	fail_test("Tank legs not found in catalog")

# ── Guns ──────────────────────────────────────────────────────────────────────

func test_get_all_guns_returns_four():
	var guns := MechCatalog.get_all_guns()
	assert_eq(guns.size(), 4, "Should have 4 gun types")

func test_get_all_guns_names():
	var guns := MechCatalog.get_all_guns()
	var names: Array = []
	for gun in guns:
		names.append(gun.name)
	assert_has(names, "Autocannon",  "Should include Autocannon")
	assert_has(names, "Flamethrower","Should include Flamethrower")
	assert_has(names, "Railgun",     "Should include Railgun")
	assert_has(names, "Laser",       "Should include Laser")

func test_guns_have_correct_weapon_types():
	var guns := MechCatalog.get_all_guns()
	var type_by_name := {}
	for gun in guns:
		type_by_name[gun.name] = gun.weapon_type
	assert_eq(type_by_name["Autocannon"],  WeaponData.WeaponType.AUTOCANNON,  "Autocannon has wrong WeaponType")
	assert_eq(type_by_name["Flamethrower"],WeaponData.WeaponType.FLAMETHROWER,"Flamethrower has wrong WeaponType")
	assert_eq(type_by_name["Railgun"],     WeaponData.WeaponType.RAILGUN,     "Railgun has wrong WeaponType")
	assert_eq(type_by_name["Laser"],       WeaponData.WeaponType.LASER,       "Laser has wrong WeaponType")

func test_guns_all_have_positive_damage():
	var guns := MechCatalog.get_all_guns()
	for gun in guns:
		assert_gt(gun.damage, 0, "%s should have positive damage" % gun.name)

func test_each_gun_is_independent_instance():
	var guns_a := MechCatalog.get_all_guns()
	var guns_b := MechCatalog.get_all_guns()
	# Modifying an instance from call A must not affect instances from call B
	guns_a[0].damage = 9999
	assert_ne(guns_b[0].damage, 9999, "factory must return independent Resource instances")
