# game_manager.gd — Autoload singleton for game state
extends Node

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
## Defaults: LMB, RMB, MMB, then keys 1-7.
static func get_default_bindings(loadout: MechLoadout) -> Array[InputEvent]:
	var total := loadout.selected_guns.size() + loadout.selected_light_guns.size()
	var defaults: Array[InputEvent] = []
	var mouse_defaults := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	var key_defaults := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
	for i in total:
		if i < mouse_defaults.size():
			var ev := InputEventMouseButton.new()
			ev.button_index = mouse_defaults[i] as MouseButton
			defaults.append(ev)
		else:
			var ev := InputEventKey.new()
			ev.keycode = key_defaults[i - mouse_defaults.size()] as Key
			defaults.append(ev)
	return defaults


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
		var action_name := "fire_%d" % i
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
		else:
			InputMap.add_action(action_name)
		InputMap.action_add_event(action_name, weapon_bindings[i])
