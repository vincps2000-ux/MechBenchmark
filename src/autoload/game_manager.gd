# game_manager.gd — Autoload singleton for game state
extends Node

const _UTILITY_MODULE_DATA_SCRIPT := preload("res://src/player/utility_module_data.gd")

signal wave_started(wave_number: int)
signal game_over
signal level_up(new_level: int)

var player_stats: PlayerStats
var current_loadout: MechLoadout
var current_wave: int = 0
var enemies_alive: int = 0
var game_time: float = 0.0
var is_running: bool = false
var weapon_bindings: Array[InputEvent] = []
var utility_bindings: Array[InputEvent] = []
var movement_bindings: Array[InputEvent] = []

func start_game() -> void:
	player_stats = PlayerStats.new()
	if current_loadout:
		current_loadout.apply_to_stats(player_stats)
	current_wave = 0
	enemies_alive = 0
	game_time = 0.0
	is_running = true

func _process(delta: float) -> void:
	if is_running:
		game_time += delta

func end_game() -> void:
	is_running = false
	game_over.emit()

func on_enemy_killed(xp: int) -> void:
	enemies_alive -= 1
	var leveled_up = player_stats.add_experience(xp)
	if leveled_up:
		level_up.emit(player_stats.level)

func get_game_time_formatted() -> String:
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	return "%02d:%02d" % [minutes, seconds]


## Returns default InputEvent bindings for each weapon in the loadout.
## Order: main guns first, then light guns.
## Defaults: LMB, RMB, MMB, then keys 1-7. Weapons of the same type share a default key.
static func get_default_bindings(loadout: MechLoadout) -> Array[InputEvent]:
	var weapons: Array = []
	weapons.append_array(loadout.selected_guns)
	weapons.append_array(loadout.selected_light_guns)
	var defaults: Array[InputEvent] = []
	var mouse_defaults := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	var key_defaults := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
	var input_by_group := {}
	var next_key_index := 0
	for i in weapons.size():
		var weapon: Variant = weapons[i]
		var group_key := "slot_%d" % i
		if weapon is WeaponData:
			group_key = "weapon_%d" % int((weapon as WeaponData).weapon_type)
		if not input_by_group.has(group_key):
			if next_key_index < mouse_defaults.size():
				input_by_group[group_key] = _make_mouse_button_event(mouse_defaults[next_key_index] as MouseButton)
			else:
				var key_index := mini(next_key_index - mouse_defaults.size(), key_defaults.size() - 1)
				input_by_group[group_key] = _make_key_event(key_defaults[key_index] as Key)
			next_key_index += 1
		defaults.append((input_by_group[group_key] as InputEvent).duplicate())
	return defaults


## Returns default InputEvent bindings for each equipped utility module.
## Defaults: keys 1-0. Utility modules of the same type share a default key.
static func get_default_utility_bindings(loadout: MechLoadout) -> Array[InputEvent]:
	var defaults: Array[InputEvent] = []
	var key_defaults := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	var key_by_group := {}
	var next_key_index := 0
	var utility_module_data = _UTILITY_MODULE_DATA_SCRIPT.new()
	var valid_index := 0
	for module in loadout.selected_utility_modules:
		if not utility_module_data.is_module_empty(module):
			var group_key := _get_utility_group_key(module, utility_module_data, valid_index)
			if not key_by_group.has(group_key):
				var key_index := mini(next_key_index, key_defaults.size() - 1)
				key_by_group[group_key] = key_defaults[key_index]
				next_key_index += 1
			defaults.append(_make_key_event(int(key_by_group[group_key])))
			valid_index += 1
	return defaults


static func _make_key_event(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	return ev


static func _make_mouse_button_event(button_index: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	return ev


static func _get_utility_group_key(module: Variant, utility_module_data: UtilityModuleData, fallback_index: int) -> String:
	var normalized_module = utility_module_data.ensure_module_data(module)
	if normalized_module is Resource and (normalized_module as Resource).get_script() == _UTILITY_MODULE_DATA_SCRIPT:
		return "utility_%d" % int(normalized_module.get("module_type"))
	var module_name := utility_module_data.get_module_name(normalized_module)
	if not module_name.is_empty():
		return module_name.to_lower()
	return "slot_%d" % fallback_index


## Returns a human-readable label for an InputEvent.
static func get_binding_label(ev: InputEvent) -> String:
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:   return "LMB"
			MOUSE_BUTTON_RIGHT:  return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_XBUTTON1: return "MOUSE4"
			MOUSE_BUTTON_XBUTTON2: return "MOUSE5"
			_: return "MOUSE%d" % (ev as InputEventMouseButton).button_index
	elif ev is InputEventKey:
		return OS.get_keycode_string((ev as InputEventKey).keycode).to_upper()
	return "???"


## Registers per-weapon InputMap actions (fire_0, fire_1, …) from weapon_bindings.
func apply_weapon_bindings() -> void:
	for i in weapon_bindings.size():
		var action_name: String = "fire_%d" % i
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
		else:
			InputMap.add_action(action_name)
		InputMap.action_add_event(action_name, weapon_bindings[i])


## Registers per-utility InputMap actions (utility_0, utility_1, …) from utility_bindings.
func apply_utility_bindings() -> void:
	for i in utility_bindings.size():
		var action_name: String = "utility_%d" % i
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
		else:
			InputMap.add_action(action_name)
		InputMap.action_add_event(action_name, utility_bindings[i])


## Returns default InputEvent bindings for movement: Up, Down, Left, Right, Turn Left, Turn Right.
## Defaults: W, S, A, D, Q, E.
static func get_default_movement_bindings() -> Array[InputEvent]:
	var defaults: Array[InputEvent] = []
	var key_defaults := [KEY_W, KEY_S, KEY_A, KEY_D, KEY_Q, KEY_E]
	for key in key_defaults:
		var ev := InputEventKey.new()
		ev.keycode = key as Key
		defaults.append(ev)
	return defaults


## Registers movement InputMap actions (move_up, move_down, move_left, move_right, turn_left, turn_right) from movement_bindings.
func apply_movement_bindings() -> void:
	var action_names: Array[String] = ["move_up", "move_down", "move_left", "move_right", "turn_left", "turn_right"]
	for i in min(movement_bindings.size(), action_names.size()):
		var action_name: String = action_names[i]
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
		else:
			InputMap.add_action(action_name)
		InputMap.action_add_event(action_name, movement_bindings[i])
