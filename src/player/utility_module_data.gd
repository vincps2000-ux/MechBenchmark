class_name UtilityModuleData
extends Resource

enum ModuleType {
	BACKUP_BATTERY,
	DRONE,
	BOOSTER,
}

enum BatteryLayout {
	LARGE,
	DOUBLE_PACKED,
	TRIPLE_PACKED,
	QUAD_PACKED,
}

@export var module_type: ModuleType = ModuleType.BACKUP_BATTERY
@export var backup_battery_layout: BatteryLayout = BatteryLayout.LARGE
@export var direction_angle: float = 0.0
@export var drone_modifications: Variant = null  # DroneModificationData

var name: String:
	get:
		match module_type:
			ModuleType.DRONE:
				return "Drone"
			ModuleType.BOOSTER:
				return "Booster"
			_:
				return "Backup Battery"


func is_empty() -> bool:
	return false


func make_module(new_module_type: ModuleType):
	var module = get_script().new()
	module.module_type = new_module_type
	return module


func from_module_name(module_name: String) -> Variant:
	match module_name:
		"Backup Battery":
			return make_module(ModuleType.BACKUP_BATTERY)
		"Drone":
			return make_module(ModuleType.DRONE)
		"Booster", "Boost-Thruster":
			return make_module(ModuleType.BOOSTER)
		_:
			return null


func ensure_module_data(module: Variant) -> Variant:
	if module == null:
		return null
	if module is Resource and (module as Resource).get_script() == get_script():
		return module
	if module is String:
		return from_module_name(module)
	return module


func get_module_name(module: Variant) -> String:
	module = ensure_module_data(module)
	if module == null:
		return ""
	if module is String:
		return module
	if module is Resource and (module as Resource).get_script() == get_script():
		return module.name
	return str(module)


func is_module_empty(module: Variant) -> bool:
	return get_module_name(module).is_empty()


func get_booster_direction_label(angle: float) -> String:
	var labels := [
		"Forward",
		"Forward-Right",
		"Right",
		"Rear-Right",
		"Rear",
		"Rear-Left",
		"Left",
		"Forward-Left",
	]
	var wrapped := wrapf(angle, 0.0, TAU)
	var index := int(floor((wrapped + PI / 8.0) / (PI / 4.0))) % labels.size()
	return labels[index]


func get_backup_battery_layout(module: Variant) -> int:
	module = ensure_module_data(module)
	if module == null:
		return BatteryLayout.LARGE
	if module is Resource and (module as Resource).get_script() == get_script():
		return clampi(int(module.get("backup_battery_layout")), BatteryLayout.LARGE, BatteryLayout.QUAD_PACKED)
	return BatteryLayout.LARGE


func get_backup_battery_layout_name(layout: int) -> String:
	match layout:
		BatteryLayout.DOUBLE_PACKED:
			return "Double Packed"
		BatteryLayout.TRIPLE_PACKED:
			return "Triple Packed"
		BatteryLayout.QUAD_PACKED:
			return "Quad Packed"
		_:
			return "Large"


func get_backup_battery_layout_uses(layout: int) -> int:
	match layout:
		BatteryLayout.DOUBLE_PACKED:
			return 2
		BatteryLayout.TRIPLE_PACKED:
			return 3
		BatteryLayout.QUAD_PACKED:
			return 4
		_:
			return 1


func get_backup_battery_layout_energy_per_use(layout: int) -> float:
	match layout:
		BatteryLayout.DOUBLE_PACKED:
			return 40.0
		BatteryLayout.TRIPLE_PACKED:
			return 25.0
		BatteryLayout.QUAD_PACKED:
			return 15.0
		_:
			return 90.0


func get_backup_battery_layout_body_color(layout: int) -> Color:
	match layout:
		BatteryLayout.DOUBLE_PACKED:
			return Color(0.58, 0.9, 1.0, 0.95)
		BatteryLayout.TRIPLE_PACKED:
			return Color(0.63, 0.95, 0.6, 0.95)
		BatteryLayout.QUAD_PACKED:
			return Color(1.0, 0.62, 0.62, 0.95)
		_:
			return Color(0.98, 0.9, 0.56, 0.95)


func get_backup_battery_layout_border_color(layout: int) -> Color:
	match layout:
		BatteryLayout.DOUBLE_PACKED:
			return Color(0.24, 0.72, 0.95, 0.95)
		BatteryLayout.TRIPLE_PACKED:
			return Color(0.33, 0.8, 0.3, 0.95)
		BatteryLayout.QUAD_PACKED:
			return Color(0.92, 0.32, 0.32, 0.95)
		_:
			return Color(0.95, 0.74, 0.2, 0.95)


func get_backup_battery_layout_tip_color(layout: int) -> Color:
	match layout:
		BatteryLayout.DOUBLE_PACKED:
			return Color(0.32, 0.82, 1.0, 0.95)
		BatteryLayout.TRIPLE_PACKED:
			return Color(0.45, 0.9, 0.42, 0.95)
		BatteryLayout.QUAD_PACKED:
			return Color(1.0, 0.42, 0.42, 0.95)
		_:
			return Color(0.95, 0.78, 0.28, 0.95)