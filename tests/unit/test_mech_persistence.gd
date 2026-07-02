# test_mech_persistence.gd — Verifies a mech survives a save/load round-trip
# through the readable JSON blueprint format (keep mech after mission +
# download/upload feature).
extends GutTest

const _TEST_PATH := "user://test_mech_persistence.json"

var _saved_loadout: MechLoadout
var _saved_weapon_bindings: Array[InputEvent]
var _saved_utility_bindings: Array[InputEvent]
var _saved_movement_bindings: Array[InputEvent]


func before_each() -> void:
	# Stash GameManager state so the test doesn't disturb a real session.
	_saved_loadout = GameManager.current_loadout
	_saved_weapon_bindings = GameManager.weapon_bindings.duplicate()
	_saved_utility_bindings = GameManager.utility_bindings.duplicate()
	_saved_movement_bindings = GameManager.movement_bindings.duplicate()


func after_each() -> void:
	GameManager.current_loadout = _saved_loadout
	GameManager.weapon_bindings = _saved_weapon_bindings
	GameManager.utility_bindings = _saved_utility_bindings
	GameManager.movement_bindings = _saved_movement_bindings
	if FileAccess.file_exists(_TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_TEST_PATH))


func _build_loadout() -> MechLoadout:
	var loadout := MechLoadout.new()
	loadout.selected_legs = MechCatalog.get_all_legs()[0]
	loadout.selected_torsos = [MechCatalog.get_all_torsos()[1]]  # Heavy = 2 weapon slots
	loadout.selected_guns = [MechCatalog.get_all_guns()[0]]
	return loadout


func test_save_creates_file() -> void:
	GameManager.current_loadout = _build_loadout()
	var ok := MechPersistence.save_current(_TEST_PATH)
	assert_true(ok, "save_current should succeed for a valid loadout")
	assert_true(FileAccess.file_exists(_TEST_PATH), "Save file should exist on disk")


func test_save_fails_without_loadout() -> void:
	GameManager.current_loadout = null
	assert_false(MechPersistence.save_current(_TEST_PATH), "Saving with no loadout should fail")


func test_saved_file_is_readable_json() -> void:
	GameManager.current_loadout = _build_loadout()
	assert_true(MechPersistence.save_current(_TEST_PATH), "Save should succeed")

	var file := FileAccess.open(_TEST_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "Saved mech file should be valid JSON")
	assert_string_contains(text, "\"legs\": \"tank\"", "Part ids should be human-readable")
	assert_string_contains(text, "heavy_armour", "Torso id should be human-readable")
	assert_string_contains(text, "autocannon", "Weapon id should be human-readable")


func test_round_trip_preserves_parts() -> void:
	var loadout := _build_loadout()
	var legs_movement := loadout.selected_legs.movement_type
	var torso_type := loadout.selected_torsos[0].torso_type
	var gun_type := loadout.selected_guns[0].weapon_type
	GameManager.current_loadout = loadout

	assert_true(MechPersistence.save_current(_TEST_PATH), "Save should succeed")

	var bp := MechPersistence.load_blueprint(_TEST_PATH)
	assert_not_null(bp, "load_blueprint should return a MechBlueprint")
	var restored := MechFactory.build_loadout(bp)
	assert_true(restored.is_valid(), "Restored loadout should be valid")
	assert_eq(restored.selected_legs.movement_type, legs_movement, "Legs should round-trip")
	assert_eq(restored.selected_torsos[0].torso_type, torso_type, "Torso should round-trip")
	assert_eq(restored.selected_guns[0].weapon_type, gun_type, "Weapon should round-trip")


func test_round_trip_preserves_module_grids() -> void:
	var loadout := _build_loadout()
	var grid = loadout.get_or_create_module_grid(0)
	var module = MechCatalog.get_module_by_id("armor_2x1")  # +3 armor
	grid.place_module(module, Vector2i(1, 1))
	GameManager.current_loadout = loadout

	assert_true(MechPersistence.save_current(_TEST_PATH), "Save should succeed")

	var bp := MechPersistence.load_blueprint(_TEST_PATH)
	assert_not_null(bp, "load_blueprint should return a blueprint")
	var restored := MechFactory.build_loadout(bp)
	assert_eq(restored.module_grids.size(), 1, "Module grid count should round-trip")
	assert_eq(int(restored.get_total_armor_bonus()), 3, "Module armor bonus should round-trip")
	assert_eq(restored.get_module_grid(0).get_module_at(Vector2i(1, 1)).id, "armor_2x1",
		"Module position should round-trip")


func test_round_trip_preserves_bindings() -> void:
	GameManager.current_loadout = _build_loadout()
	var ev := InputEventKey.new()
	ev.keycode = KEY_5
	GameManager.weapon_bindings = [ev] as Array[InputEvent]

	assert_true(MechPersistence.save_current(_TEST_PATH), "Save should succeed")
	GameManager.weapon_bindings = [] as Array[InputEvent]

	assert_true(MechPersistence.load_into_game_manager(_TEST_PATH), "Load should succeed")
	assert_eq(GameManager.weapon_bindings.size(), 1, "Binding count should round-trip")
	assert_true(GameManager.weapon_bindings[0] is InputEventKey, "Binding type should round-trip")
	assert_eq((GameManager.weapon_bindings[0] as InputEventKey).keycode, KEY_5, "Keycode should round-trip")


func test_apply_to_game_manager_restores_loadout() -> void:
	GameManager.current_loadout = _build_loadout()
	assert_true(MechPersistence.save_current(_TEST_PATH), "Save should succeed")
	GameManager.current_loadout = null

	assert_true(MechPersistence.load_into_game_manager(_TEST_PATH), "Load into GameManager should succeed")
	assert_not_null(GameManager.current_loadout, "GameManager loadout should be restored")
	assert_true(GameManager.current_loadout.is_valid(), "Restored loadout should be valid")


func test_load_missing_file_returns_null() -> void:
	assert_null(MechPersistence.load_blueprint("user://does_not_exist_12345.json"), "Missing file should load as null")
	assert_false(MechPersistence.has_save("user://does_not_exist_12345.json"), "has_save should be false for missing file")


func test_load_invalid_json_returns_null() -> void:
	var file := FileAccess.open(_TEST_PATH, FileAccess.WRITE)
	file.store_string("this is not a mech {")
	file.close()
	assert_null(MechPersistence.load_blueprint(_TEST_PATH), "Corrupt file should load as null")


func test_binding_codec_round_trip() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	assert_eq(MechPersistence.binding_to_string(key), "key:E", "Key binding should serialize readably")
	var restored_key := MechPersistence.binding_from_string("key:E")
	assert_true(restored_key is InputEventKey, "Key binding should parse back")
	assert_eq((restored_key as InputEventKey).keycode, KEY_E, "Keycode should round-trip")

	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	assert_eq(MechPersistence.binding_to_string(mouse), "mouse:left", "Mouse binding should serialize readably")
	var restored_mouse := MechPersistence.binding_from_string("mouse:left")
	assert_true(restored_mouse is InputEventMouseButton, "Mouse binding should parse back")
	assert_eq((restored_mouse as InputEventMouseButton).button_index, MOUSE_BUTTON_LEFT, "Button should round-trip")

	assert_null(MechPersistence.binding_from_string("garbage"), "Unknown binding text should parse to null")
