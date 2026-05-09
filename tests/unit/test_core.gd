# test_core.gd — Compact test suite for core data classes and multi-weapon system
extends GutTest

const _PLAYER_SCENE := preload("res://scenes/player/player.tscn")
var _utility_module_data = preload("res://src/player/utility_module_data.gd").new()

# ── PlayerStats ───────────────────────────────────────────────────────────────

func test_player_stats_defaults():
	var s := PlayerStats.new()
	assert_eq(s.max_integrity, 4)
	assert_eq(s.speed, 200.0)

func test_player_stats_take_damage_and_heal():
	var s := PlayerStats.new()
	s.take_damage()
	assert_eq(s.integrity, 3)
	s.heal()
	assert_eq(s.integrity, 4)

func test_player_stats_is_dead():
	var s := PlayerStats.new()
	s.integrity = 0
	assert_true(s.is_dead())

func test_player_stats_xp_level_up():
	var s := PlayerStats.new()
	var leveled := s.add_experience(999)
	assert_true(leveled)
	assert_gt(s.level, 1)

# ── WeaponData ────────────────────────────────────────────────────────────────

func test_weapon_data_level_up():
	var w := WeaponData.new()
	w.damage = 10
	w.level = 1
	w.level_up()
	assert_eq(w.level, 2)
	assert_gt(w.damage, 10)

func test_weapon_data_max_level():
	var w := WeaponData.new()
	w.level = 8
	w.max_level = 8
	assert_false(w.can_level_up())

func test_weapon_data_thrower_element_defaults_to_fuel():
	var w := WeaponData.new()
	assert_eq(w.thrower_element, WeaponData.ThrowerElement.FUEL)

# ── TorsoData ─────────────────────────────────────────────────────────────────

func test_torso_heavy_has_two_weapon_slots():
	var t := TorsoData.new()
	t.torso_type = TorsoData.TorsoType.HEAVY_ARMOUR
	t.weapon_slots = 2
	assert_eq(t.weapon_slots, 2)

func test_torso_stealth_has_one_slot():
	var t := TorsoData.new()
	t.torso_type = TorsoData.TorsoType.STEALTH
	assert_eq(t.weapon_slots, 1)

# ── LegData ───────────────────────────────────────────────────────────────────

func test_leg_default_torso_slots():
	var leg := LegData.new()
	assert_eq(leg.torso_slots, 1, "Default legs support 1 torso")

func test_leg_custom_torso_slots():
	var leg := LegData.new()
	leg.torso_slots = 2
	assert_eq(leg.torso_slots, 2)

func test_torso_applies_integrity():
	var t := TorsoData.new()
	t.speed_modifier = 1.0
	t.integrity = 8
	var s := PlayerStats.new()
	t.apply_to_stats(s)
	assert_eq(s.max_integrity, 8)
	assert_eq(s.integrity, 8)

# ── MechLoadout (multi-weapon) ────────────────────────────────────────────────

func test_loadout_empty_is_invalid():
	var l := MechLoadout.new()
	assert_false(l.is_valid())

func test_loadout_valid_with_all_parts():
	var l := MechLoadout.new()
	l.selected_legs = LegData.new()
	l.selected_torso = TorsoData.new()
	l.selected_guns = [WeaponData.new()]
	assert_true(l.is_valid())

func test_loadout_multi_gun():
	var l := MechLoadout.new()
	var g1 := WeaponData.new()
	g1.name = "Autocannon"
	var g2 := WeaponData.new()
	g2.name = "Laser"
	l.selected_guns = [g1, g2]
	assert_eq(l.selected_guns.size(), 2)
	assert_eq(l.selected_gun.name, "Autocannon", "Compat getter returns first")

func test_loadout_compat_setter():
	var l := MechLoadout.new()
	var g := WeaponData.new()
	g.name = "Railgun"
	l.selected_gun = g
	assert_eq(l.selected_guns.size(), 1)
	assert_eq(l.selected_guns[0].name, "Railgun")

func test_loadout_compat_setter_null_clears():
	var l := MechLoadout.new()
	l.selected_gun = WeaponData.new()
	l.selected_gun = null
	assert_eq(l.selected_guns.size(), 0)

func test_loadout_multi_torso():
	var l := MechLoadout.new()
	l.selected_legs = LegData.new()
	var t1 := TorsoData.new()
	t1.name = "A"
	t1.weapon_slots = 1
	var t2 := TorsoData.new()
	t2.name = "B"
	t2.weapon_slots = 2
	l.selected_torsos = [t1, t2]
	l.selected_guns = [WeaponData.new()]
	assert_true(l.is_valid(), "Valid with torsos in selected_torsos array")
	assert_eq(l.get_primary_torso().name, "A")
	assert_eq(l.get_total_weapon_slots(), 3, "Sum weapon_slots from all torsos")

func test_player_mounting_skips_null_medium_weapon_slots():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	var torso := TorsoData.new()
	torso.torso_type = TorsoData.TorsoType.HEAVY_ARMOUR
	torso.weapon_slots = 2
	loadout.selected_torso = torso
	loadout.selected_torsos = [torso]
	var gun := WeaponData.new()
	gun.weapon_type = WeaponData.WeaponType.LASER
	loadout.selected_guns = [null, gun]

	GameManager.current_loadout = loadout
	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_eq(player.get_weapons().size(), 1,
		"Player should mount only the non-null medium weapon entries")


func test_backup_battery_consumes_one_and_restores_ninety_energy():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]
	loadout.selected_utility_modules = ["Backup Battery", "Backup Battery"]

	GameManager.current_loadout = loadout
	GameManager.utility_bindings = GameManager.get_default_utility_bindings(loadout)
	GameManager.apply_utility_bindings()

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	player.consume_energy(95.0)
	assert_eq(player.get_energy(), 5.0)
	assert_eq(player.get_backup_battery_count(), 2)

	assert_true(player._consume_backup_battery_for_action(0),
		"First battery should activate on utility action 0")
	assert_eq(player.get_energy(), 95.0,
		"Backup battery should restore 90 power")
	assert_eq(player.get_backup_battery_count(), 1,
		"Exactly one backup battery should be consumed per activation")

	assert_false(player._consume_backup_battery_for_action(0),
		"Second battery should not be consumed by an unrelated action")
	assert_true(player._consume_backup_battery_for_action(1),
		"Second battery should activate from its own utility action")
	assert_eq(player.get_backup_battery_count(), 0)


func test_booster_action_starts_fast_dash_in_selected_direction():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]
	var booster = _utility_module_data.make_module(_utility_module_data.ModuleType.BOOSTER)
	booster.direction_angle = PI * 0.5
	loadout.selected_utility_modules = [booster]

	GameManager.current_loadout = loadout
	GameManager.utility_bindings = GameManager.get_default_utility_bindings(loadout)
	GameManager.apply_utility_bindings()

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	assert_eq(player.get_consumable_utility_icon_keys(), ["booster"],
		"Unused booster should appear in the consumable utility icon list")

	assert_true(player._activate_booster_for_action(0),
		"Booster should activate from its utility action")
	assert_false(player._activate_booster_for_action(0),
		"Booster should be single use and not activate twice")
	assert_eq(player.get_consumable_utility_icon_keys(), [],
		"Consumed booster should disappear from the consumable utility icon list")
	assert_true(player.is_boosting(), "Booster should remain active right after activation")
	assert_gt(player.get_boost_visual_intensity(), 0.0,
		"Booster activation should enable dash visuals while the boost is active")
	var boost_velocity = player.get_boost_velocity()
	assert_gt(boost_velocity.length(), 600.0, "Booster should move much faster than base movement")
	assert_lt(boost_velocity.normalized().distance_to(player.transform.y.normalized()), 0.01,
		"A 90 degree booster angle should dash to the mech's local right side")


func test_shared_button_boosters_consume_one_per_press():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]
	var booster_a = _utility_module_data.make_module(_utility_module_data.ModuleType.BOOSTER)
	var booster_b = _utility_module_data.make_module(_utility_module_data.ModuleType.BOOSTER)
	loadout.selected_utility_modules = [booster_a, booster_b]

	GameManager.current_loadout = loadout
	var shared_binding := InputEventKey.new()
	shared_binding.keycode = KEY_Q
	GameManager.utility_bindings = [shared_binding, shared_binding.duplicate()]
	GameManager.apply_utility_bindings()

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	assert_eq(player.get_consumable_utility_icon_keys(), ["booster", "booster"])
	var shared_actions: Array[int] = [0, 1]

	player._process_pressed_utility_actions(shared_actions)
	assert_eq(player.get_consumable_utility_icon_keys(), ["booster"],
		"One shared-button press should consume exactly one booster")

	player._process_pressed_utility_actions(shared_actions)
	assert_eq(player.get_consumable_utility_icon_keys(), [],
		"A second press should consume the remaining shared-button booster")


func test_drone_action_spawns_recon_drone_and_switches_view():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]
	loadout.selected_utility_modules = ["Drone"]

	GameManager.current_loadout = loadout
	GameManager.utility_bindings = GameManager.get_default_utility_bindings(loadout)
	GameManager.apply_utility_bindings()

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_eq(player.get_consumable_utility_icon_keys(), ["drone"],
		"Unused drone should appear in utility consumable icons")
	assert_false(player.is_drone_view_active(), "Drone view should start inactive")

	assert_true(player._activate_drone_for_action(0),
		"Drone should activate from its utility action")
	assert_true(player.is_drone_view_active(),
		"Drone activation should switch player to drone camera view")
	assert_gt(player.get_drone_battery(), 0.0, "Active drone should report battery")
	assert_eq(player.get_consumable_utility_icon_keys(), [],
		"Consumed drone module should be removed from utility consumables")


func test_drone_is_single_use_and_returns_camera_on_depletion():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]
	loadout.selected_utility_modules = ["Drone"]

	GameManager.current_loadout = loadout
	GameManager.utility_bindings = GameManager.get_default_utility_bindings(loadout)
	GameManager.apply_utility_bindings()

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_true(player._activate_drone_for_action(0))
	assert_false(player._activate_drone_for_action(0),
		"Drone utility should not activate twice")

	var drone: Variant = player.get_active_drone()
	assert_not_null(drone, "Active drone node should be available after activation")
	if drone != null and drone.has_method("debug_deplete_battery"):
		drone.call("debug_deplete_battery")

	assert_false(player.is_drone_view_active(),
		"Player camera control should return after drone battery is depleted")

func test_loadout_apply_stats():
	var l := MechLoadout.new()
	var legs := LegData.new()
	legs.speed_modifier = 0.6
	var torso := TorsoData.new()
	torso.speed_modifier = 1.0
	torso.integrity = 8
	l.selected_legs = legs
	l.selected_torso = torso
	var s := PlayerStats.new()
	l.apply_to_stats(s)
	assert_eq(s.speed, 200.0 * 0.6)
	assert_eq(s.max_integrity, 8)

# ── MechCatalog ───────────────────────────────────────────────────────────────

func test_catalog_returns_parts():
	assert_gt(MechCatalog.get_all_legs().size(), 0)
	assert_gt(MechCatalog.get_all_torsos().size(), 0)
	assert_gt(MechCatalog.get_all_guns().size(), 0)

func test_catalog_has_landship_with_two_torso_slots():
	for leg in MechCatalog.get_all_legs():
		if leg.movement_type == LegData.MovementType.LANDSHIP:
			assert_eq(leg.torso_slots, 2)
			return
	fail_test("No LANDSHIP leg type found in catalog")

func test_catalog_has_chemical_thrower_name():
	for gun in MechCatalog.get_all_guns():
		if gun.weapon_type == WeaponData.WeaponType.FLAMETHROWER:
			assert_eq(gun.name, "Chemical thrower")
			return
	fail_test("No FLAMETHROWER weapon found in catalog")

func test_catalog_heavy_torso_has_two_slots():
	for t in MechCatalog.get_all_torsos():
		if t.torso_type == TorsoData.TorsoType.HEAVY_ARMOUR:
			assert_eq(t.weapon_slots, 2)
			return
	fail_test("No HEAVY_ARMOUR torso found in catalog")

# ── MechAssembler weapon offsets ──────────────────────────────────────────────

func test_heavy_has_two_offsets():
	var offsets := MechAssembler.get_weapon_offsets(TorsoData.TorsoType.HEAVY_ARMOUR)
	assert_eq(offsets.size(), 2, "Heavy torso should have 2 mount points")

func test_stealth_has_one_offset():
	var offsets := MechAssembler.get_weapon_offsets(TorsoData.TorsoType.STEALTH)
	assert_eq(offsets.size(), 1)

func test_cargo_has_one_offset():
	var offsets := MechAssembler.get_weapon_offsets(TorsoData.TorsoType.CARGO)
	assert_eq(offsets.size(), 1)

func test_single_torso_offset_is_centered():
	var offsets := MechAssembler.get_torso_offsets(1)
	assert_eq(offsets.size(), 1)
	assert_eq(offsets[0], Vector2.ZERO)

func test_dual_torso_offsets_are_split():
	var offsets := MechAssembler.get_torso_offsets(2)
	assert_eq(offsets.size(), 2)
	assert_ne(offsets[0], offsets[1])
	assert_gt(absf(offsets[0].x), 0.0)
	assert_eq(offsets[0].y, 0.0)
	assert_eq(offsets[1].y, 0.0)

func test_scale_offsets_doubles_at_128():
	var raw: Array[Vector2] = [Vector2(4.0, 17.0)]
	var scaled := MechAssembler.scale_offsets(raw, 128.0)
	assert_eq(scaled.size(), 1)
	# 128/64 = 2x
	assert_eq(scaled[0], Vector2(8.0, 34.0))

func test_weapon_rect_size_proportional():
	# 48/64 * 220 = 165
	assert_eq(MechAssembler.weapon_rect_size(220.0), 220.0 * 48.0 / 64.0)

func test_utility_slots_per_torso_type():
	assert_eq(MechAssembler.get_utility_slots(TorsoData.TorsoType.CARGO), 2)
	assert_eq(MechAssembler.get_utility_slots(TorsoData.TorsoType.STEALTH), 3)
	assert_eq(MechAssembler.get_utility_slots(TorsoData.TorsoType.HEAVY_ARMOUR), 1)

func test_loadout_total_utility_slots_multi_torso():
	var l := MechLoadout.new()
	var cargo := TorsoData.new()
	cargo.torso_type = TorsoData.TorsoType.CARGO
	var stealth := TorsoData.new()
	stealth.torso_type = TorsoData.TorsoType.STEALTH
	l.selected_torsos = [cargo, stealth]
	assert_eq(l.get_total_utility_slots(), 5)

# ── Light weapon slots ────────────────────────────────────────────────────────

func test_stealth_has_one_light_slot():
	for t in MechCatalog.get_all_torsos():
		if t.torso_type == TorsoData.TorsoType.STEALTH:
			assert_eq(t.light_weapon_slots, 1)
			return
	fail_test("No STEALTH torso found")

func test_cargo_has_two_light_slots():
	for t in MechCatalog.get_all_torsos():
		if t.torso_type == TorsoData.TorsoType.CARGO:
			assert_eq(t.light_weapon_slots, 2)
			return
	fail_test("No CARGO torso found")

func test_heavy_has_no_light_slots():
	for t in MechCatalog.get_all_torsos():
		if t.torso_type == TorsoData.TorsoType.HEAVY_ARMOUR:
			assert_eq(t.light_weapon_slots, 0)
			return
	fail_test("No HEAVY_ARMOUR torso found")

func test_light_weapon_offsets_stealth():
	var offsets := MechAssembler.get_light_weapon_offsets(TorsoData.TorsoType.STEALTH)
	assert_eq(offsets.size(), 1, "Stealth should have 1 light mount")

func test_light_weapon_offsets_cargo():
	var offsets := MechAssembler.get_light_weapon_offsets(TorsoData.TorsoType.CARGO)
	assert_eq(offsets.size(), 2, "Cargo should have 2 light mounts")

func test_light_weapon_offsets_heavy():
	var offsets := MechAssembler.get_light_weapon_offsets(TorsoData.TorsoType.HEAVY_ARMOUR)
	assert_eq(offsets.size(), 0, "Heavy should have 0 light mounts")

func test_rocket_pod_in_catalog():
	var guns := MechCatalog.get_all_light_guns()
	assert_gt(guns.size(), 0, "Should have at least one light gun")
	assert_eq(guns[0].name, "Rocket Pod")
	assert_eq(guns[0].weapon_type, WeaponData.WeaponType.ROCKET_POD)
	assert_eq(guns[0].slot_size, WeaponData.SlotSize.LIGHT)

func test_light_weapon_fits_medium_slot():
	var rocket := WeaponData.new()
	rocket.slot_size = WeaponData.SlotSize.LIGHT
	assert_true(rocket.fits_slot(WeaponData.SlotSize.MEDIUM), "Light weapon fits medium slot")
	assert_true(rocket.fits_slot(WeaponData.SlotSize.LIGHT), "Light weapon fits light slot")

func test_medium_weapon_only_fits_medium():
	var autocannon := WeaponData.new()
	autocannon.slot_size = WeaponData.SlotSize.MEDIUM
	assert_true(autocannon.fits_slot(WeaponData.SlotSize.MEDIUM), "Medium fits medium")
	assert_false(autocannon.fits_slot(WeaponData.SlotSize.LIGHT), "Medium doesn't fit light")

func test_loadout_light_guns():
	var l := MechLoadout.new()
	var g := WeaponData.new()
	g.name = "Rocket Pod"
	l.selected_light_guns = [g]
	assert_eq(l.selected_light_guns.size(), 1)

func test_loadout_total_light_weapon_slots():
	var l := MechLoadout.new()
	var t := TorsoData.new()
	t.light_weapon_slots = 2
	l.selected_torsos = [t]
	assert_eq(l.get_total_light_weapon_slots(), 2)

func test_light_weapon_rect_size():
	# 32/64 * 220 = 110
	assert_eq(MechAssembler.light_weapon_rect_size(220.0), 220.0 * 32.0 / 64.0)
