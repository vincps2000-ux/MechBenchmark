# test_core.gd — Compact test suite for core data classes and multi-weapon system
extends GutTest

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

func test_scale_offsets_doubles_at_128():
	var raw: Array[Vector2] = [Vector2(4.0, 17.0)]
	var scaled := MechAssembler.scale_offsets(raw, 128.0)
	assert_eq(scaled.size(), 1)
	# 128/64 = 2x
	assert_eq(scaled[0], Vector2(8.0, 34.0))

func test_weapon_rect_size_proportional():
	# 48/64 * 220 = 165
	assert_eq(MechAssembler.weapon_rect_size(220.0), 220.0 * 48.0 / 64.0)

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
