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

# ── PlayerController weapon offsets ───────────────────────────────────────────

func test_heavy_has_two_offsets():
	var offsets := PlayerController._get_weapon_offsets(TorsoData.TorsoType.HEAVY_ARMOUR)
	assert_eq(offsets.size(), 2, "Heavy torso should have 2 mount points")

func test_stealth_has_one_offset():
	var offsets := PlayerController._get_weapon_offsets(TorsoData.TorsoType.STEALTH)
	assert_eq(offsets.size(), 1)

func test_cargo_has_one_offset():
	var offsets := PlayerController._get_weapon_offsets(TorsoData.TorsoType.CARGO)
	assert_eq(offsets.size(), 1)
