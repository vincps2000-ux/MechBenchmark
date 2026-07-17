# mech_factory.gd — Converts between the JSON-like MechBlueprint (design data)
# and the gameplay MechLoadout (live part Resources).
#
#   blueprint_from_loadout(loadout) -> MechBlueprint   (capture / save)
#   build_loadout(blueprint)        -> MechLoadout     (generate gameplay mech)
#
# All enums are stored as human-readable strings so exported files stay legible.
class_name MechFactory

const _ModuleGridScript := preload("res://src/player/module_grid.gd")
const _UtilityModuleScript := preload("res://src/player/utility_module_data.gd")

# ── Enum ↔ string tables ──────────────────────────────────────────────────────

const AMMO_TYPE_NAMES := {
	WeaponData.AmmoType.HE: "he",
	WeaponData.AmmoType.SOLID: "solid",
	WeaponData.AmmoType.CANISTER: "canister",
	WeaponData.AmmoType.NORMAL: "normal",
	WeaponData.AmmoType.RIOT: "riot",
	WeaponData.AmmoType.SMART: "smart",
}

const THROWER_ELEMENT_NAMES := {
	WeaponData.ThrowerElement.FUEL: "fuel",
	WeaponData.ThrowerElement.ACID: "acid",
	WeaponData.ThrowerElement.CRYOGENICS: "cryogenics",
}

const THROWER_NOZZLE_NAMES := {
	WeaponData.ThrowerNozzle.LONG_NOZZLE: "long",
	WeaponData.ThrowerNozzle.NOZZLE: "standard",
	WeaponData.ThrowerNozzle.WIDE_NOZZLE: "wide",
}

const TARGETING_TYPE_NAMES := {
	WeaponData.TargetingType.UNGUIDED: "unguided",
	WeaponData.TargetingType.SEEKING: "seeking",
	WeaponData.TargetingType.WIRE_GUIDED: "wire_guided",
}

const BARREL_LENGTH_NAMES := {
	WeaponData.BarrelLength.VERY_SHORT: "very_short",
	WeaponData.BarrelLength.SHORT: "short",
	WeaponData.BarrelLength.STANDARD: "standard",
	WeaponData.BarrelLength.LONG: "long",
	WeaponData.BarrelLength.VERY_LONG: "very_long",
}

const ATTACHMENT_TYPE_NAMES := {
	AttachmentData.AttachmentType.LASER_POINTER: "laser_pointer",
}

const UTILITY_TYPE_NAMES := {
	UtilityModuleData.ModuleType.BACKUP_BATTERY: "backup_battery",
	UtilityModuleData.ModuleType.DRONE: "drone",
	UtilityModuleData.ModuleType.BOOSTER: "booster",
}

const BATTERY_LAYOUT_NAMES := {
	UtilityModuleData.BatteryLayout.LARGE: "large",
	UtilityModuleData.BatteryLayout.DOUBLE_PACKED: "double_packed",
	UtilityModuleData.BatteryLayout.TRIPLE_PACKED: "triple_packed",
	UtilityModuleData.BatteryLayout.QUAD_PACKED: "quad_packed",
}

const DRONE_COMPONENT_NAMES := {
	DroneModificationData.ComponentType.EMPTY: "empty",
	DroneModificationData.ComponentType.BATTERY: "battery",
	DroneModificationData.ComponentType.FIRE_CONTROL: "fire_control",
	DroneModificationData.ComponentType.EXPLOSIVE_CHARGE: "explosive_charge",
}

const REACTOR_TYPE_NAMES := {
	ModuleData.ReactorType.NONE: "none",
	ModuleData.ReactorType.CONVENTIONAL_FUEL: "fuel",
	ModuleData.ReactorType.NUCLEAR: "nuclear",
	ModuleData.ReactorType.FUSION: "fusion",
}


static func _enum_to_name(table: Dictionary, value: int, fallback: String) -> String:
	return str(table.get(value, fallback))


static func _name_to_enum(table: Dictionary, name: String, fallback: int) -> int:
	for key in table:
		if table[key] == name:
			return int(key)
	return fallback

# ── Loadout → blueprint ──────────────────────────────────────────────────────

## Captures the entire mech design as a JSON-like blueprint.
static func blueprint_from_loadout(loadout: MechLoadout) -> MechBlueprint:
	var bp := MechBlueprint.new()
	if loadout == null:
		return bp

	bp.data["legs"] = loadout.selected_legs.id if loadout.selected_legs else null

	var torsos: Array = []
	if loadout.selected_torsos.size() > 0:
		for torso in loadout.selected_torsos:
			torsos.append(torso.id if torso else null)
	elif loadout.selected_torso:
		torsos.append(loadout.selected_torso.id)
	bp.data["torsos"] = torsos

	var weapons: Array = []
	for gun in loadout.selected_guns:
		weapons.append(weapon_to_dict(gun) if gun else null)
	bp.data["weapons"] = weapons

	var light_weapons: Array = []
	for gun in loadout.selected_light_guns:
		light_weapons.append(weapon_to_dict(gun) if gun else null)
	bp.data["light_weapons"] = light_weapons

	var utility: Array = []
	var util_helper = _UtilityModuleScript.new()
	for module in loadout.selected_utility_modules:
		var normalized = util_helper.ensure_module_data(module)
		utility.append(utility_module_to_dict(normalized) if normalized != null else null)
	bp.data["utility_modules"] = utility

	var grids: Array = []
	for grid in loadout.module_grids:
		if grid:
			grids.append(module_grid_to_dict(grid))
	bp.data["module_grids"] = grids

	return bp

# ── Blueprint → loadout ──────────────────────────────────────────────────────

## Generates a fresh gameplay MechLoadout from a blueprint.
static func build_loadout(bp: MechBlueprint) -> MechLoadout:
	var loadout := MechLoadout.new()
	if bp == null:
		return loadout
	return build_loadout_from_dict(bp.data)


## Same as build_loadout but straight from the raw blueprint dictionary.
static func build_loadout_from_dict(data: Dictionary) -> MechLoadout:
	var loadout := MechLoadout.new()

	var legs_id: Variant = data.get("legs")
	if legs_id is String:
		loadout.selected_legs = MechCatalog.get_leg_by_id(legs_id)

	var torsos: Array[TorsoData] = []
	for entry in data.get("torsos", []):
		torsos.append(MechCatalog.get_torso_by_id(entry) if entry is String else null)
	while torsos.size() > 0 and torsos.back() == null:
		torsos.pop_back()
	loadout.selected_torsos = torsos
	for torso in torsos:
		if torso:
			loadout.selected_torso = torso
			break

	var guns: Array[WeaponData] = []
	for entry in data.get("weapons", []):
		guns.append(weapon_from_dict(entry) if entry is Dictionary else null)
	while guns.size() > 0 and guns.back() == null:
		guns.pop_back()
	loadout.selected_guns = guns

	var light_guns: Array[WeaponData] = []
	for entry in data.get("light_weapons", []):
		light_guns.append(weapon_from_dict(entry) if entry is Dictionary else null)
	while light_guns.size() > 0 and light_guns.back() == null:
		light_guns.pop_back()
	loadout.selected_light_guns = light_guns

	var utility: Array = []
	for entry in data.get("utility_modules", []):
		utility.append(utility_module_from_dict(entry) if entry is Dictionary else null)
	loadout.selected_utility_modules = utility

	for entry in data.get("module_grids", []):
		if entry is Dictionary:
			var grid = module_grid_from_dict(entry)
			var index := int(entry.get("torso", 0))
			while loadout.module_grids.size() <= index:
				loadout.module_grids.append(null)
			loadout.module_grids[index] = grid

	return loadout

# ── Weapons ───────────────────────────────────────────────────────────────────

## Serializes a weapon as its catalog id plus human-readable customizations.
static func weapon_to_dict(gun: WeaponData) -> Dictionary:
	var dict := {"id": gun.id}
	if gun.level > 1:
		dict["level"] = gun.level

	var baseline := MechCatalog.get_gun_by_id(gun.id)

	if baseline == null or gun.ammo_type != baseline.ammo_type:
		dict["ammo_type"] = _enum_to_name(AMMO_TYPE_NAMES, gun.ammo_type, "he")
	if baseline == null or gun.thrower_element != baseline.thrower_element:
		dict["thrower_element"] = _enum_to_name(THROWER_ELEMENT_NAMES, gun.thrower_element, "fuel")
	if baseline == null or gun.thrower_nozzle != baseline.thrower_nozzle:
		dict["thrower_nozzle"] = _enum_to_name(THROWER_NOZZLE_NAMES, gun.thrower_nozzle, "standard")
	if baseline == null or gun.targeting_type != baseline.targeting_type:
		dict["targeting"] = _enum_to_name(TARGETING_TYPE_NAMES, gun.targeting_type, "unguided")
	if baseline == null or gun.barrel_length != baseline.barrel_length:
		dict["barrel_length"] = _enum_to_name(BARREL_LENGTH_NAMES, gun.barrel_length, "standard")
	if baseline == null or gun.barrel_count != baseline.barrel_count:
		dict["barrel_count"] = WeaponData.clamp_barrel_count(gun.barrel_count)
	if baseline == null or gun.laser_intensity != baseline.laser_intensity:
		dict["laser_intensity"] = gun.laser_intensity

	var missile_layout: Array = []
	var has_missile_part := false
	for part in gun.missile_builder_layout:
		missile_layout.append(part)
		if part != "":
			has_missile_part = true
	if has_missile_part:
		dict["missile_layout"] = missile_layout

	if gun.attachments.size() > 0:
		var attachments: Array = []
		for att in gun.attachments:
			if att:
				attachments.append({
					"type": _enum_to_name(ATTACHMENT_TYPE_NAMES, att.attachment_type, "laser_pointer"),
					"color": att.color.to_html(false),
					"enabled": att.enabled,
				})
		dict["attachments"] = attachments

	return dict


## Rebuilds a weapon from the catalog and re-applies its customizations.
static func weapon_from_dict(dict: Dictionary) -> WeaponData:
	var gun := MechCatalog.get_gun_by_id(str(dict.get("id", "")))
	if gun == null:
		return null

	var level := int(dict.get("level", 1))
	while gun.level < level and gun.can_level_up():
		gun.level_up()

	if dict.has("ammo_type"):
		gun.ammo_type = _name_to_enum(AMMO_TYPE_NAMES, str(dict["ammo_type"]), gun.ammo_type) as WeaponData.AmmoType
	if dict.has("thrower_element"):
		gun.thrower_element = _name_to_enum(THROWER_ELEMENT_NAMES, str(dict["thrower_element"]), gun.thrower_element) as WeaponData.ThrowerElement
	if dict.has("thrower_nozzle"):
		gun.thrower_nozzle = _name_to_enum(THROWER_NOZZLE_NAMES, str(dict["thrower_nozzle"]), gun.thrower_nozzle) as WeaponData.ThrowerNozzle
	if dict.has("targeting"):
		gun.targeting_type = _name_to_enum(TARGETING_TYPE_NAMES, str(dict["targeting"]), gun.targeting_type) as WeaponData.TargetingType
	if dict.has("barrel_length"):
		gun.barrel_length = WeaponData.clamp_barrel_length(
			_name_to_enum(BARREL_LENGTH_NAMES, str(dict["barrel_length"]), gun.barrel_length))
	if dict.has("barrel_count"):
		gun.barrel_count = WeaponData.clamp_barrel_count(int(dict["barrel_count"]))
	if dict.has("laser_intensity"):
		gun.laser_intensity = clampi(int(dict["laser_intensity"]), 0, 4)

	if dict.has("missile_layout"):
		var layout: Array[String] = []
		for part in dict["missile_layout"]:
			layout.append(str(part))
		gun.apply_missile_builder(layout)

	if dict.has("attachments"):
		var attachments: Array[AttachmentData] = []
		for entry in dict["attachments"]:
			if entry is Dictionary:
				var att := AttachmentData.new()
				att.attachment_type = _name_to_enum(ATTACHMENT_TYPE_NAMES, str(entry.get("type", "")), AttachmentData.AttachmentType.LASER_POINTER) as AttachmentData.AttachmentType
				att.color = Color.from_string(str(entry.get("color", "ff0000")), Color.RED)
				att.enabled = bool(entry.get("enabled", true))
				attachments.append(att)
		gun.attachments = attachments

	return gun

# ── Utility modules ───────────────────────────────────────────────────────────

static func utility_module_to_dict(module) -> Dictionary:
	var dict := {
		"type": _enum_to_name(UTILITY_TYPE_NAMES, int(module.module_type), "backup_battery"),
	}
	match int(module.module_type):
		UtilityModuleData.ModuleType.BACKUP_BATTERY:
			dict["battery_layout"] = _enum_to_name(BATTERY_LAYOUT_NAMES, int(module.backup_battery_layout), "large")
		UtilityModuleData.ModuleType.BOOSTER:
			dict["direction_angle"] = float(module.direction_angle)
		UtilityModuleData.ModuleType.DRONE:
			var mods = module.drone_modifications
			if mods != null:
				var layout: Array = []
				for component in mods.modification_layout:
					layout.append(_enum_to_name(DRONE_COMPONENT_NAMES, int(component), "empty"))
				dict["drone_mods"] = layout
	return dict


static func utility_module_from_dict(dict: Dictionary):
	var module = _UtilityModuleScript.new()
	module.module_type = _name_to_enum(UTILITY_TYPE_NAMES, str(dict.get("type", "")), UtilityModuleData.ModuleType.BACKUP_BATTERY) as UtilityModuleData.ModuleType
	if dict.has("battery_layout"):
		module.backup_battery_layout = _name_to_enum(BATTERY_LAYOUT_NAMES, str(dict["battery_layout"]), UtilityModuleData.BatteryLayout.LARGE) as UtilityModuleData.BatteryLayout
	if dict.has("direction_angle"):
		module.direction_angle = float(dict["direction_angle"])
	if dict.has("drone_mods"):
		var layout: Array = []
		for entry in dict["drone_mods"]:
			layout.append(_name_to_enum(DRONE_COMPONENT_NAMES, str(entry), DroneModificationData.ComponentType.EMPTY))
		module.drone_modifications = DroneModificationData.new(layout)
	return module

# ── Module grids ──────────────────────────────────────────────────────────────

static func module_grid_to_dict(grid) -> Dictionary:
	var placements: Array = []
	for placement in grid.placements:
		var module = placement.get("module")
		if module == null:
			continue
		var pos: Vector2i = placement.get("position", Vector2i.ZERO)
		var entry := {
			"module": module.id,
			"x": pos.x,
			"y": pos.y,
		}
		if module.supports_reactor_customization:
			entry["reactor_type"] = _enum_to_name(REACTOR_TYPE_NAMES, int(module.reactor_type), "none")
			if module.is_fuel_reactor():
				entry["fuel_max"] = float(module.reactor_fuel_max)
				entry["fuel_current"] = float(module.reactor_fuel_current)
		placements.append(entry)
	return {
		"torso": int(grid.torso_index),
		"placements": placements,
	}


static func module_grid_from_dict(dict: Dictionary):
	var grid = _ModuleGridScript.new(int(dict.get("torso", 0)))
	for entry in dict.get("placements", []):
		if not (entry is Dictionary):
			continue
		var module = MechCatalog.get_module_by_id(str(entry.get("module", "")))
		if module == null:
			continue
		if entry.has("reactor_type") and module.supports_reactor_customization:
			module.set_reactor_type(_name_to_enum(REACTOR_TYPE_NAMES, str(entry["reactor_type"]), ModuleData.ReactorType.NONE))
			if entry.has("fuel_max"):
				module.reactor_fuel_max = float(entry["fuel_max"])
			if entry.has("fuel_current"):
				module.reactor_fuel_current = float(entry["fuel_current"])
		grid.place_module(module, Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	return grid
