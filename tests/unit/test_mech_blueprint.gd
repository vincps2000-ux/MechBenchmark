# test_mech_blueprint.gd — Verifies the JSON-like MechBlueprint data structure
# and the MechFactory conversions (loadout ↔ blueprint).
extends GutTest

# ── Catalog ids ───────────────────────────────────────────────────────────────

func test_all_catalog_parts_have_unique_ids() -> void:
	var seen := {}
	var parts: Array = []
	parts.append_array(MechCatalog.get_all_legs())
	parts.append_array(MechCatalog.get_all_torsos())
	parts.append_array(MechCatalog.get_all_guns())
	parts.append_array(MechCatalog.get_all_light_guns())
	parts.append_array(MechCatalog.get_all_modules())
	for part in parts:
		assert_ne(part.id, "", "Catalog part '%s' must have an id" % part.name)
		assert_false(seen.has(part.id), "Catalog id '%s' must be unique" % part.id)
		seen[part.id] = true


func test_catalog_lookup_by_id() -> void:
	assert_eq(MechCatalog.get_leg_by_id("spider").name, "Spider")
	assert_eq(MechCatalog.get_torso_by_id("cargo").name, "Cargo")
	assert_eq(MechCatalog.get_gun_by_id("railgun").name, "Railgun")
	assert_eq(MechCatalog.get_gun_by_id("machinegun").slot_size, WeaponData.SlotSize.LIGHT,
		"Light guns should be found too")
	assert_eq(MechCatalog.get_module_by_id("reactor_2x2").name, "Reactor (2x2)")
	assert_null(MechCatalog.get_leg_by_id("nope"), "Unknown id should return null")


func test_ammo_storage_is_a_customizable_1x1_module_defaulting_to_first_weapon() -> void:
	var module = MechCatalog.get_module_by_id("ammo_storage_1x1")
	assert_not_null(module, "Ammo storage should be available in the module catalog")
	assert_eq(module.get_grid_bounds().size, Vector2i.ONE, "Ammo storage should occupy one grid cell")
	assert_true(module.supports_weapon_customization, "Ammo storage should allow weapon selection")
	assert_eq(module.target_weapon_index, 0, "Ammo storage should target the first weapon by default")

# ── Blueprint JSON ────────────────────────────────────────────────────────────

func test_blueprint_json_round_trip() -> void:
	var bp := MechBlueprint.new()
	bp.data["legs"] = "tank"
	var text := bp.to_json_text()
	var restored := MechBlueprint.from_json_text(text)
	assert_not_null(restored, "Serialized blueprint should parse back")
	assert_true(bp.equals(restored), "Round-tripped blueprint should be equal")


func test_blueprint_rejects_foreign_json() -> void:
	assert_null(MechBlueprint.from_json_text("{\"hello\": 1}"), "Foreign JSON should be rejected")
	assert_null(MechBlueprint.from_json_text("not json"), "Garbage should be rejected")


func test_blueprint_duplicate_is_independent() -> void:
	var bp := MechBlueprint.new()
	bp.data["torsos"] = ["stealth"]
	var copy := bp.duplicate_blueprint()
	copy.data["torsos"].append("cargo")
	assert_eq(bp.data["torsos"].size(), 1, "Duplicate must not share nested arrays")

# ── Factory: loadout → blueprint → loadout ────────────────────────────────────

func _customized_loadout() -> MechLoadout:
	var loadout := MechLoadout.new()
	loadout.selected_legs = MechCatalog.get_leg_by_id("landship")
	loadout.selected_torsos = [
		MechCatalog.get_torso_by_id("heavy_armour"),
		MechCatalog.get_torso_by_id("stealth"),
	]
	loadout.selected_torso = loadout.selected_torsos[0]

	var autocannon := MechCatalog.get_gun_by_id("autocannon")
	autocannon.ammo_type = WeaponData.AmmoType.CANISTER
	autocannon.barrel_length = WeaponData.BarrelLength.VERY_LONG
	var laser_att := AttachmentData.new()
	laser_att.attachment_type = AttachmentData.AttachmentType.LASER_POINTER
	autocannon.attachments = [laser_att]
	loadout.selected_guns = [autocannon]

	var rocket_pod := MechCatalog.get_gun_by_id("rocket_pod")
	rocket_pod.apply_missile_builder(["fuel", "explosive", "cluster", "proximity_trigger", "homing", ""] as Array[String])
	rocket_pod.missile_fire_mode = WeaponData.MissileFireMode.ALL_AMMO
	var machinegun := MechCatalog.get_gun_by_id("machinegun")
	machinegun.ammo_type = WeaponData.AmmoType.SMART
	machinegun.barrel_count = 4
	machinegun.barrel_length = WeaponData.BarrelLength.LONG
	loadout.selected_light_guns = [rocket_pod, machinegun]

	return loadout


func test_round_trip_preserves_structure() -> void:
	var bp := MechFactory.blueprint_from_loadout(_customized_loadout())
	var restored := MechFactory.build_loadout(bp)

	assert_eq(restored.selected_legs.id, "landship", "Legs should round-trip")
	assert_eq(restored.selected_torsos.size(), 2, "Both torsos should round-trip")
	assert_eq(restored.selected_torsos[0].id, "heavy_armour")
	assert_eq(restored.selected_torsos[1].id, "stealth")
	assert_eq(restored.selected_guns.size(), 1)
	assert_eq(restored.selected_light_guns.size(), 2)
	assert_true(restored.is_valid(), "Restored loadout should be playable")


func test_round_trip_preserves_weapon_customizations() -> void:
	var bp := MechFactory.blueprint_from_loadout(_customized_loadout())
	var restored := MechFactory.build_loadout(bp)

	var gun := restored.selected_guns[0]
	assert_eq(gun.ammo_type, WeaponData.AmmoType.CANISTER, "Ammo type should round-trip")
	assert_eq(gun.barrel_length, WeaponData.BarrelLength.VERY_LONG, "Barrel length should round-trip")
	assert_eq(gun.attachments.size(), 1, "Attachments should round-trip")
	assert_eq(gun.attachments[0].attachment_type, AttachmentData.AttachmentType.LASER_POINTER)


func test_round_trip_preserves_missile_builder() -> void:
	var source := _customized_loadout()
	var expected_speed := source.selected_light_guns[0].projectile_speed
	var expected_damage := source.selected_light_guns[0].damage

	var bp := MechFactory.blueprint_from_loadout(source)
	var restored := MechFactory.build_loadout(bp)

	var rocket := restored.selected_light_guns[0]
	assert_eq(rocket.targeting_type, WeaponData.TargetingType.SEEKING, "Homing guidance should round-trip")
	assert_eq(rocket.projectile_speed, expected_speed, "Derived missile speed should be regenerated")
	assert_eq(rocket.damage, expected_damage, "Derived missile damage should be regenerated")
	assert_true(rocket.missile_has_cluster, "Cluster block should round-trip")
	assert_true(rocket.missile_has_proximity_trigger, "Proximity trigger should round-trip")
	assert_eq(rocket.missile_fire_mode, WeaponData.MissileFireMode.ALL_AMMO,
			"Fire-control setting should round-trip")

func test_round_trip_preserves_machinegun_workbench_configuration() -> void:
	var restored := MechFactory.build_loadout(MechFactory.blueprint_from_loadout(_customized_loadout()))
	var machinegun := restored.selected_light_guns[1]
	assert_eq(machinegun.ammo_type, WeaponData.AmmoType.SMART,
			"Machinegun ammo type should round-trip")
	assert_eq(machinegun.barrel_count, 4, "Machinegun barrel count should round-trip")
	assert_eq(machinegun.barrel_length, WeaponData.BarrelLength.LONG,
			"Machinegun barrel length should round-trip")


func test_round_trip_preserves_weapon_level() -> void:
	var loadout := _customized_loadout()
	loadout.selected_guns[0].level_up()
	loadout.selected_guns[0].level_up()
	var expected_damage := loadout.selected_guns[0].damage

	var restored := MechFactory.build_loadout(MechFactory.blueprint_from_loadout(loadout))
	assert_eq(restored.selected_guns[0].level, 3, "Weapon level should round-trip")
	assert_eq(restored.selected_guns[0].damage, expected_damage, "Leveled stats should be regenerated")


func test_round_trip_preserves_utility_modules() -> void:
	var loadout := _customized_loadout()
	var util := UtilityModuleData.new()

	var battery = util.make_module(UtilityModuleData.ModuleType.BACKUP_BATTERY)
	battery.backup_battery_layout = UtilityModuleData.BatteryLayout.TRIPLE_PACKED

	var booster = util.make_module(UtilityModuleData.ModuleType.BOOSTER)
	booster.direction_angle = PI * 0.5

	var drone = util.make_module(UtilityModuleData.ModuleType.DRONE)
	drone.drone_modifications = DroneModificationData.new([
		DroneModificationData.ComponentType.BATTERY,
		DroneModificationData.ComponentType.EXPLOSIVE_CHARGE,
		DroneModificationData.ComponentType.EMPTY,
	])

	loadout.selected_utility_modules = [battery, null, booster, drone]

	var restored := MechFactory.build_loadout(MechFactory.blueprint_from_loadout(loadout))
	assert_eq(restored.selected_utility_modules.size(), 4, "Slot count (incl. empty) should round-trip")
	assert_null(restored.selected_utility_modules[1], "Empty slots should stay empty")
	assert_eq(int(restored.selected_utility_modules[0].backup_battery_layout),
		int(UtilityModuleData.BatteryLayout.TRIPLE_PACKED), "Battery layout should round-trip")
	assert_almost_eq(float(restored.selected_utility_modules[2].direction_angle), PI * 0.5, 0.001,
		"Booster direction should round-trip")
	var restored_drone = restored.selected_utility_modules[3]
	assert_eq(restored_drone.drone_modifications.get_explosive_charge_count(), 1,
		"Drone modifications should round-trip")


func test_round_trip_preserves_reactor_customization() -> void:
	var loadout := _customized_loadout()
	var grid = loadout.get_or_create_module_grid(0)
	var reactor = MechCatalog.get_module_by_id("reactor_2x2")
	reactor.set_reactor_type(ModuleData.ReactorType.FUSION)
	grid.place_module(reactor, Vector2i(0, 1))

	var restored := MechFactory.build_loadout(MechFactory.blueprint_from_loadout(loadout))
	var restored_reactor = restored.get_module_grid(0).get_module_at(Vector2i(0, 1))
	assert_not_null(restored_reactor, "Reactor placement should round-trip")
	assert_eq(int(restored_reactor.reactor_type), int(ModuleData.ReactorType.FUSION),
		"Reactor type should round-trip")


func test_round_trip_preserves_ammo_storage_weapon_selection() -> void:
	var loadout := _customized_loadout()
	var grid = loadout.get_or_create_module_grid(0)
	var storage = MechCatalog.get_module_by_id("ammo_storage_1x1")
	storage.target_weapon_index = 2
	grid.place_module(storage, Vector2i(0, 0))

	var restored := MechFactory.build_loadout(MechFactory.blueprint_from_loadout(loadout))
	var restored_storage = restored.get_module_grid(0).get_module_at(Vector2i(0, 0))
	assert_eq(restored_storage.target_weapon_index, 2, "Selected weapon slot should round-trip")


func test_ammo_storage_bonus_is_additive_for_selected_weapon() -> void:
	var loadout := _customized_loadout()
	var first_grid = loadout.get_or_create_module_grid(0)
	var second_grid = loadout.get_or_create_module_grid(1)
	var first_storage = MechCatalog.get_module_by_id("ammo_storage_1x1")
	var second_storage = MechCatalog.get_module_by_id("ammo_storage_1x1")
	first_storage.target_weapon_index = 1
	second_storage.target_weapon_index = 1
	first_grid.place_module(first_storage, Vector2i(0, 0))
	second_grid.place_module(second_storage, Vector2i(0, 0))

	assert_eq(loadout.get_weapon_ammo_multiplier(0), 1.0, "Other weapons should keep base ammo")
	assert_eq(loadout.get_weapon_ammo_multiplier(1), 3.0, "Each storage should add 100% base ammo")


func test_blueprint_contains_only_json_types() -> void:
	var bp := MechFactory.blueprint_from_loadout(_customized_loadout())
	assert_true(_is_json_value(bp.data), "Blueprint must only contain JSON-compatible values")


func _is_json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for entry in value:
				if not _is_json_value(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _is_json_value(value[key]):
					return false
			return true
	return false
