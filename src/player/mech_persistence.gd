# mech_persistence.gd — Saves/loads the player's mech so it survives between
# missions, and supports exporting (download) / importing (upload) mech files.
#
# The mech is stored as a pretty-printed JSON document built from a
# MechBlueprint (see mech_blueprint.gd / mech_factory.gd), so a downloaded
# mech file can be opened and read in any text editor. Input bindings are
# stored as readable strings ("key:E", "mouse:left").
class_name MechPersistence
extends RefCounted

## Default slot kept between missions (in the user data dir).
const SAVE_PATH := "user://last_mech.json"

## True if a persisted mech exists at the given path.
static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## Build a blueprint snapshot (mech design + bindings) from GameManager state.
static func capture_from_game_manager() -> MechBlueprint:
	var bp := MechFactory.blueprint_from_loadout(GameManager.current_loadout)
	bp.data["bindings"] = {
		"weapons": _bindings_to_strings(GameManager.weapon_bindings),
		"utility": _bindings_to_strings(GameManager.utility_bindings),
		"movement": _bindings_to_strings(GameManager.movement_bindings),
	}
	return bp


## Persist the current GameManager mech to disk. Returns true on success.
static func save_current(path: String = SAVE_PATH) -> bool:
	if GameManager.current_loadout == null:
		return false
	return save_blueprint(capture_from_game_manager(), path)


## Persist an explicit blueprint to disk as readable JSON.
static func save_blueprint(bp: MechBlueprint, path: String = SAVE_PATH) -> bool:
	if bp == null:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("MechPersistence: cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(bp.to_json_text())
	file.close()
	return true


## Load a blueprint from disk. Returns null if missing or invalid.
static func load_blueprint(path: String = SAVE_PATH) -> MechBlueprint:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var bp := MechBlueprint.from_json_text(text)
	if bp == null:
		push_warning("MechPersistence: file is not a valid mech blueprint: %s" % path)
	return bp


## Apply a blueprint to GameManager (generated loadout + input bindings).
static func apply_to_game_manager(bp: MechBlueprint) -> void:
	if bp == null:
		return
	GameManager.current_loadout = MechFactory.build_loadout(bp)
	var bindings: Dictionary = bp.data.get("bindings", {})
	GameManager.weapon_bindings = _bindings_from_strings(bindings.get("weapons", []))
	GameManager.utility_bindings = _bindings_from_strings(bindings.get("utility", []))
	GameManager.movement_bindings = _bindings_from_strings(bindings.get("movement", []))
	GameManager.apply_weapon_bindings()
	GameManager.apply_utility_bindings()
	GameManager.apply_movement_bindings()


## Load the persisted mech and apply it to GameManager. Returns true on success.
static func load_into_game_manager(path: String = SAVE_PATH) -> bool:
	var bp := load_blueprint(path)
	if bp == null:
		return false
	apply_to_game_manager(bp)
	return true


## Export (download) the persisted mech to an arbitrary path.
## Falls back to the live GameManager state if no save file exists yet.
static func export_to(path: String) -> bool:
	var bp := load_blueprint(SAVE_PATH)
	if bp == null:
		bp = capture_from_game_manager()
	return save_blueprint(bp, path)


## Import (upload) a mech file: validate it, make it the active + persisted mech.
## Returns the loaded MechBlueprint on success, or null on failure.
static func import_from(path: String) -> MechBlueprint:
	var bp := load_blueprint(path)
	if bp == null:
		return null
	save_blueprint(bp, SAVE_PATH)
	apply_to_game_manager(bp)
	return bp

# ── Input binding codec ───────────────────────────────────────────────────────

const _MOUSE_BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "left",
	MOUSE_BUTTON_RIGHT: "right",
	MOUSE_BUTTON_MIDDLE: "middle",
}


## Serializes an InputEvent as a readable string, e.g. "key:E" or "mouse:left".
static func binding_to_string(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "key:%s" % OS.get_keycode_string((ev as InputEventKey).keycode)
	if ev is InputEventMouseButton:
		var button := (ev as InputEventMouseButton).button_index
		return "mouse:%s" % str(_MOUSE_BUTTON_NAMES.get(button, str(int(button))))
	return ""


## Parses a binding string back into an InputEvent. Returns null when unknown.
static func binding_from_string(text: String) -> InputEvent:
	var parts := text.split(":", true, 1)
	if parts.size() != 2:
		return null
	match parts[0]:
		"key":
			var keycode := OS.find_keycode_from_string(parts[1])
			if keycode == KEY_NONE:
				return null
			var key_event := InputEventKey.new()
			key_event.keycode = keycode
			return key_event
		"mouse":
			var mouse_event := InputEventMouseButton.new()
			for button in _MOUSE_BUTTON_NAMES:
				if _MOUSE_BUTTON_NAMES[button] == parts[1]:
					mouse_event.button_index = button as MouseButton
					return mouse_event
			if parts[1].is_valid_int():
				mouse_event.button_index = int(parts[1]) as MouseButton
				return mouse_event
	return null


static func _bindings_to_strings(bindings: Array[InputEvent]) -> Array:
	var out: Array = []
	for ev in bindings:
		out.append(binding_to_string(ev))
	return out


static func _bindings_from_strings(entries: Variant) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if entries is Array:
		for entry in entries:
			var ev := binding_from_string(str(entry))
			if ev:
				out.append(ev)
	return out
