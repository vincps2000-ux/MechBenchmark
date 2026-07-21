# test_core.gd — Compact test suite for core data classes and multi-weapon system
extends GutTest

const _PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const _SHOOT_TARGET_SCENE := preload("res://scenes/enemies/shoot_target.tscn")
var _utility_module_data = preload("res://src/player/utility_module_data.gd").new()
var _drone_modification_data = preload("res://src/player/drone_modification_data.gd")

# ── PlayerStats ───────────────────────────────────────────────────────────────

func test_player_stats_defaults():
	var s := PlayerStats.new()
	assert_eq(s.max_health, 30)
	assert_eq(s.speed, 200.0)

func test_player_stats_take_damage_and_heal():
	var s := PlayerStats.new()
	s.take_damage()
	assert_eq(s.health, 29)
	s.heal()
	assert_eq(s.health, 30)

func test_player_stats_is_dead():
	var s := PlayerStats.new()
	s.health = 0
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


func test_weapon_data_thrower_nozzle_defaults_to_standard():
	var w := WeaponData.new()
	assert_eq(w.thrower_nozzle, WeaponData.ThrowerNozzle.NOZZLE)

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

func test_catalog_cyclone_torso():
	var t := MechCatalog.get_torso_by_id("cyclone")
	assert_not_null(t, "Cyclone torso should exist in catalog")
	assert_eq(t.torso_type, TorsoData.TorsoType.CYCLONE)
	assert_eq(t.weapon_slots, 2)
	assert_eq(t.light_weapon_slots, 0)

func test_catalog_bastion_torso():
	var t := MechCatalog.get_torso_by_id("bastion")
	assert_not_null(t, "Bastion torso should exist in catalog")
	assert_eq(t.torso_type, TorsoData.TorsoType.BASTION)
	assert_eq(t.weapon_slots, 2)

func test_cyclone_mounts_are_opposed():
	var offsets := MechAssembler.get_weapon_offsets(TorsoData.TorsoType.CYCLONE)
	var rotations := MechAssembler.get_weapon_mount_rotations(TorsoData.TorsoType.CYCLONE)
	assert_eq(offsets.size(), 2, "Cyclone has two mounts")
	assert_eq(rotations.size(), 2)
	assert_almost_eq(rotations[0], 0.0, 0.001)
	assert_almost_eq(rotations[1], PI, 0.001, "Rear mount points backward")

func test_default_mount_rotations_are_zero():
	var rotations := MechAssembler.get_weapon_mount_rotations(TorsoData.TorsoType.HEAVY_ARMOUR)
	assert_eq(rotations.size(), 2)
	for r in rotations:
		assert_almost_eq(r, 0.0, 0.001)

func test_bastion_has_four_utility_slots():
	assert_eq(MechAssembler.get_utility_slots(TorsoData.TorsoType.BASTION), 4)

func test_cyclone_grid_is_ring_without_centre():
	assert_eq(GridLayout.get_grid_type(TorsoData.TorsoType.CYCLONE), GridLayout.GridType.CYCLONE_RING)
	var cells := GridLayout.get_grid_shape(GridLayout.GridType.CYCLONE_RING)
	assert_eq(cells.size(), 8, "Ring has 8 cells")
	assert_false(cells.has(Vector2i(1, 1)), "Centre spindle cell is blocked")

func test_bastion_grid_is_4x2_block():
	assert_eq(GridLayout.get_grid_type(TorsoData.TorsoType.BASTION), GridLayout.GridType.BASTION_BLOCK)
	var cells := GridLayout.get_grid_shape(GridLayout.GridType.BASTION_BLOCK)
	assert_eq(cells.size(), 8, "Block has 8 cells")
	assert_eq(GridLayout.get_grid_dimensions(GridLayout.GridType.BASTION_BLOCK), Vector2i(4, 2))

# ── LegData ───────────────────────────────────────────────────────────────────

func test_leg_default_torso_slots():
	var leg := LegData.new()
	assert_eq(leg.torso_slots, 1, "Default legs support 1 torso")

func test_leg_custom_torso_slots():
	var leg := LegData.new()
	leg.torso_slots = 2
	assert_eq(leg.torso_slots, 2)

func test_torso_does_not_override_structure_health():
	var t := TorsoData.new()
	t.speed_modifier = 1.0
	var s := PlayerStats.new()
	t.apply_to_stats(s)
	assert_eq(s.max_health, 30)
	assert_eq(s.health, 30)

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


func test_player_applies_ammo_storage_to_selected_weapon():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	var torso := TorsoData.new()
	torso.torso_type = TorsoData.TorsoType.STEALTH
	torso.weapon_slots = 1
	loadout.selected_torso = torso
	loadout.selected_torsos = [torso]
	loadout.selected_guns = [MechCatalog.get_gun_by_id("autocannon")]
	var storage = MechCatalog.get_module_by_id("ammo_storage_1x1")
	loadout.get_or_create_module_grid(0).place_module(storage, Vector2i.ZERO)

	GameManager.current_loadout = loadout
	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var weapon = player.get_weapons()[0]

	assert_eq(weapon.get_ammo_capacity(), Autocannon.MAX_AMMO * 2,
		"Selected mounted weapon should receive +100% ammo")
	assert_eq(weapon.get_ammo_count(), Autocannon.MAX_AMMO * 2,
		"Selected mounted weapon should start with its increased capacity full")


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


func test_backup_battery_layout_stats_match_expected_values():
	assert_eq(_utility_module_data.get_backup_battery_layout_uses(_utility_module_data.BatteryLayout.LARGE), 1)
	assert_eq(_utility_module_data.get_backup_battery_layout_energy_per_use(_utility_module_data.BatteryLayout.LARGE), 90.0)
	assert_eq(_utility_module_data.get_backup_battery_layout_uses(_utility_module_data.BatteryLayout.DOUBLE_PACKED), 2)
	assert_eq(_utility_module_data.get_backup_battery_layout_energy_per_use(_utility_module_data.BatteryLayout.DOUBLE_PACKED), 40.0)
	assert_eq(_utility_module_data.get_backup_battery_layout_uses(_utility_module_data.BatteryLayout.TRIPLE_PACKED), 3)
	assert_eq(_utility_module_data.get_backup_battery_layout_energy_per_use(_utility_module_data.BatteryLayout.TRIPLE_PACKED), 25.0)
	assert_eq(_utility_module_data.get_backup_battery_layout_uses(_utility_module_data.BatteryLayout.QUAD_PACKED), 4)
	assert_eq(_utility_module_data.get_backup_battery_layout_energy_per_use(_utility_module_data.BatteryLayout.QUAD_PACKED), 15.0)


func test_double_packed_battery_has_two_charges_and_restores_forty_each():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]
	var battery = _utility_module_data.make_module(_utility_module_data.ModuleType.BACKUP_BATTERY)
	battery.backup_battery_layout = _utility_module_data.BatteryLayout.DOUBLE_PACKED
	loadout.selected_utility_modules = [battery]

	GameManager.current_loadout = loadout
	GameManager.utility_bindings = GameManager.get_default_utility_bindings(loadout)
	GameManager.apply_utility_bindings()

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	player.consume_energy(100.0)
	assert_eq(player.get_energy(), 0.0)
	assert_eq(player.get_backup_battery_count(), 2)

	assert_true(player._consume_backup_battery_for_action(0),
		"First double-packed charge should consume")
	assert_eq(player.get_energy(), 40.0)
	assert_eq(player.get_backup_battery_count(), 1)

	assert_true(player._consume_backup_battery_for_action(0),
		"Second double-packed charge should consume")
	assert_eq(player.get_energy(), 80.0)
	assert_eq(player.get_backup_battery_count(), 0)

	assert_false(player._consume_backup_battery_for_action(0),
		"No charges should remain after consuming both double-packed uses")


func test_battery_bank_module_increases_player_max_energy():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]

	var module_grid = loadout.get_or_create_module_grid(0)
	for module in MechCatalog.get_all_modules():
		if module.name == "Battery Bank Module":
			module_grid.place_module(module, Vector2i(0, 0))
			break

	GameManager.current_loadout = loadout

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_eq(player.get_max_energy(), 200.0,
		"Battery bank should increase player max energy by 100")
	assert_eq(player.get_energy(), 200.0,
		"Player should start filled to the increased max energy")


func test_fusion_reactor_triples_nuclear_output_after_two_second_drain_lockout():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]

	var module_grid = loadout.get_or_create_module_grid(0)
	var nuclear_reactor = null
	var fusion_reactor = null
	for module in MechCatalog.get_all_modules():
		if module.name != "Reactor (2x2)":
			continue
		nuclear_reactor = module.duplicate_module()
		nuclear_reactor.set_reactor_type(nuclear_reactor.ReactorType.NUCLEAR)
		fusion_reactor = module.duplicate_module()
		fusion_reactor.set_reactor_type(fusion_reactor.ReactorType.FUSION)
		break

	assert_not_null(nuclear_reactor, "Catalog should provide a 2x2 reactor for runtime tests")
	assert_not_null(fusion_reactor, "Catalog should provide a 2x2 reactor for runtime tests")
	module_grid.place_module(nuclear_reactor, Vector2i(0, 0))
	module_grid.place_module(fusion_reactor, Vector2i(2, 0))

	GameManager.current_loadout = loadout
	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_eq(player.get_max_energy(), 100.0)
	assert_true(player.consume_energy(40.0), "Player should be able to spend energy before regen test")
	assert_eq(player.get_energy(), 60.0)

	player._regen_energy(1.0)
	assert_eq(player.get_energy(), 65.0,
		"During the fusion cooldown, only the nuclear reactor should contribute energy")

	player._regen_energy(0.9)
	assert_eq(player.get_energy(), 69.5,
		"Fusion output should remain blocked until 2 seconds have elapsed since the drain")

	player._regen_energy(0.2)
	assert_eq(player.get_energy(), 73.5,
		"After cooldown expires, fusion should add triple the nuclear reactor output")


func test_fuel_reactor_doubles_nuclear_output_and_stops_when_empty():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]

	var module_grid = loadout.get_or_create_module_grid(0)
	var nuclear_reactor = null
	var fuel_reactor = null
	for module in MechCatalog.get_all_modules():
		if module.name != "Reactor (2x2)":
			continue
		nuclear_reactor = module.duplicate_module()
		nuclear_reactor.set_reactor_type(nuclear_reactor.ReactorType.NUCLEAR)
		fuel_reactor = module.duplicate_module()
		fuel_reactor.set_reactor_type(fuel_reactor.ReactorType.CONVENTIONAL_FUEL)
		fuel_reactor.reactor_fuel_current = 1.0
		break

	assert_not_null(nuclear_reactor, "Catalog should provide a 2x2 reactor for fuel runtime tests")
	assert_not_null(fuel_reactor, "Catalog should provide a 2x2 reactor for fuel runtime tests")
	module_grid.place_module(nuclear_reactor, Vector2i(0, 0))
	module_grid.place_module(fuel_reactor, Vector2i(2, 0))

	GameManager.current_loadout = loadout
	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_eq(player.get_max_reactor_fuel(), 100.0, "Fuel reactor should expose a default 100 fuel capacity")
	assert_eq(player.get_reactor_fuel(), 1.0, "Fuel reactor test setup should start nearly empty")
	assert_true(player.consume_energy(40.0), "Player should be able to spend energy before testing reactor regen")

	player._regen_energy(1.0)
	assert_eq(player.get_energy(), 75.0,
		"Fuel reactor should add double the nuclear output while fuel remains")

	player._update_fuel_reactors(1.0)
	assert_eq(player.get_reactor_fuel(), 0.0, "Fuel reactor should burn 1 fuel per second")

	assert_true(player.consume_energy(10.0), "Player should still be able to spend energy after the reactor runs dry")
	player._regen_energy(1.0)
	assert_eq(player.get_energy(), 70.0,
		"Once fuel is empty, only the nuclear reactor should continue generating energy")


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


func test_drone_explosion_uses_explosion_system_and_damages_target():
	var loadout := MechLoadout.new()
	loadout.selected_legs = LegData.new()
	loadout.selected_torso = TorsoData.new()
	loadout.selected_torsos = [loadout.selected_torso]
	loadout.selected_guns = [WeaponData.new()]

	var drone_module = _utility_module_data.make_module(_utility_module_data.ModuleType.DRONE)
	var drone_mods = _drone_modification_data.new()
	var placed: bool = drone_mods.try_place_component(0, _drone_modification_data.ComponentType.EXPLOSIVE_CHARGE)
	assert_true(placed, "Explosive Charge should fit into drone builder slot 1")
	drone_module.drone_modifications = drone_mods
	loadout.selected_utility_modules = [drone_module]

	GameManager.current_loadout = loadout
	GameManager.utility_bindings = GameManager.get_default_utility_bindings(loadout)
	GameManager.apply_utility_bindings()
	GameManager.movement_bindings = GameManager.get_default_movement_bindings()
	GameManager.apply_movement_bindings()

	var player = _PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	assert_true(player._activate_drone_for_action(0), "Drone should activate from utility action")

	var drone: Variant = player.get_active_drone()
	assert_not_null(drone, "Drone should exist before self-destruct")

	var target = _SHOOT_TARGET_SCENE.instantiate()
	add_child_autofree(target)
	target.global_position = drone.global_position + Vector2(12.0, 0.0)

	var explosions_before: int = _count_autocannon_explosions()
	player.trigger_drone_explode()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.18).timeout
	await get_tree().process_frame

	assert_eq(_count_autocannon_explosions(), explosions_before + 1,
		"Drone self-destruct should spawn one autocannon explosion")
	assert_false(is_instance_valid(target),
		"Target inside blast should be destroyed by drone explosion")


func _count_autocannon_explosions() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path.ends_with("autocannon_explosion.gd"):
			count += 1
	return count

func test_loadout_apply_stats():
	var l := MechLoadout.new()
	var legs := LegData.new()
	legs.speed_modifier = 0.6
	var torso := TorsoData.new()
	torso.speed_modifier = 1.0
	l.selected_legs = legs
	l.selected_torso = torso
	var s := PlayerStats.new()
	l.apply_to_stats(s)
	assert_eq(s.speed, 200.0 * 0.6)
	assert_eq(s.max_health, 30)

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
