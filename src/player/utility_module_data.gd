class_name UtilityModuleData
extends Resource

enum ModuleType {
	BACKUP_BATTERY,
	DRONE,
	BOOSTER,
}

@export var module_type: ModuleType = ModuleType.BACKUP_BATTERY
@export var direction_angle: float = 0.0

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