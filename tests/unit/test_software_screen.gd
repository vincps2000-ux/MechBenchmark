# tests/unit/test_software_screen.gd — Tests for weapon keybind configuration
extends GutTest

var _loadout: MechLoadout


func before_each():
	_loadout = MechLoadout.new()


func test_default_bindings_for_single_weapon():
	var gun := WeaponData.new()
	gun.name = "Autocannon"
	gun.weapon_type = WeaponData.WeaponType.AUTOCANNON
	_loadout.selected_guns.append(gun)

	var bindings := GameManager.get_default_bindings(_loadout)
	assert_eq(bindings.size(), 1, "Should have 1 binding for 1 weapon")
	assert_true(bindings[0] is InputEventMouseButton, "First weapon defaults to mouse button")
	assert_eq((bindings[0] as InputEventMouseButton).button_index, MOUSE_BUTTON_LEFT,
		"First weapon defaults to left mouse button")


func test_default_bindings_for_two_weapons():
	var gun1 := WeaponData.new()
	gun1.name = "Autocannon"
	_loadout.selected_guns.append(gun1)
	var gun2 := WeaponData.new()
	gun2.name = "Laser"
	_loadout.selected_guns.append(gun2)

	var bindings := GameManager.get_default_bindings(_loadout)
	assert_eq(bindings.size(), 2, "Should have 2 bindings for 2 weapons")
	assert_eq((bindings[0] as InputEventMouseButton).button_index, MOUSE_BUTTON_LEFT)
	assert_eq((bindings[1] as InputEventMouseButton).button_index, MOUSE_BUTTON_RIGHT)


func test_default_bindings_includes_light_weapons():
	var gun := WeaponData.new()
	gun.name = "Autocannon"
	_loadout.selected_guns.append(gun)
	var light := WeaponData.new()
	light.name = "Machinegun"
	light.slot_size = WeaponData.SlotSize.LIGHT
	_loadout.selected_light_guns.append(light)

	var bindings := GameManager.get_default_bindings(_loadout)
	assert_eq(bindings.size(), 2, "Should include main + light weapons")


func test_register_and_retrieve_weapon_bindings():
	var gun := WeaponData.new()
	gun.name = "Autocannon"
	_loadout.selected_guns.append(gun)
	GameManager.current_loadout = _loadout

	GameManager.weapon_bindings = GameManager.get_default_bindings(_loadout)
	assert_eq(GameManager.weapon_bindings.size(), 1)

	# Override binding with a key event
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_SPACE
	GameManager.weapon_bindings[0] = key_event

	assert_true(GameManager.weapon_bindings[0] is InputEventKey)
	assert_eq((GameManager.weapon_bindings[0] as InputEventKey).keycode, KEY_SPACE)


func test_get_binding_label_mouse():
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	assert_eq(GameManager.get_binding_label(ev), "LMB")
	ev.button_index = MOUSE_BUTTON_RIGHT
	assert_eq(GameManager.get_binding_label(ev), "RMB")
	ev.button_index = MOUSE_BUTTON_MIDDLE
	assert_eq(GameManager.get_binding_label(ev), "MMB")


func test_get_binding_label_key():
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	assert_eq(GameManager.get_binding_label(ev), "SPACE")
	ev.keycode = KEY_Q
	assert_eq(GameManager.get_binding_label(ev), "Q")


func test_apply_bindings_to_input_map():
	var gun := WeaponData.new()
	gun.name = "Autocannon"
	_loadout.selected_guns.append(gun)
	GameManager.current_loadout = _loadout
	GameManager.weapon_bindings = GameManager.get_default_bindings(_loadout)

	GameManager.apply_weapon_bindings()

	assert_true(InputMap.has_action("fire_0"), "fire_0 action should exist")
	var events := InputMap.action_get_events("fire_0")
	assert_eq(events.size(), 1, "fire_0 should have exactly 1 event")
	assert_true(events[0] is InputEventMouseButton)

	# Cleanup
	if InputMap.has_action("fire_0"):
		InputMap.erase_action("fire_0")


func test_default_bindings_for_utility_modules():
	_loadout.selected_utility_modules = ["Backup Battery", "Drone", ""]

	var utility_bindings := GameManager.get_default_utility_bindings(_loadout)
	assert_eq(utility_bindings.size(), 2, "Should create bindings for non-empty utility modules")
	assert_true(utility_bindings[0] is InputEventKey)
	assert_true(utility_bindings[1] is InputEventKey)
	assert_eq((utility_bindings[0] as InputEventKey).keycode, KEY_Q)
	assert_eq((utility_bindings[1] as InputEventKey).keycode, KEY_E)


func test_default_bindings_for_customizable_utility_modules():
	var utility_script: Script = load("res://src/player/utility_module_data.gd")
	var battery = utility_script.new()
	battery.module_type = 0
	var booster = utility_script.new()
	booster.module_type = 2
	booster.direction_angle = PI * 0.5
	_loadout.selected_utility_modules = [battery, booster]

	var utility_bindings := GameManager.get_default_utility_bindings(_loadout)
	assert_eq(utility_bindings.size(), 2, "Configured utility modules should still get bindings")
	assert_eq((utility_bindings[0] as InputEventKey).keycode, KEY_Q)
	assert_eq((utility_bindings[1] as InputEventKey).keycode, KEY_E)


func test_apply_utility_bindings_to_input_map():
	_loadout.selected_utility_modules = ["Backup Battery"]
	GameManager.utility_bindings = GameManager.get_default_utility_bindings(_loadout)

	GameManager.apply_utility_bindings()

	assert_true(InputMap.has_action("utility_0"), "utility_0 action should exist")
	var events := InputMap.action_get_events("utility_0")
	assert_eq(events.size(), 1, "utility_0 should have exactly 1 event")
	assert_true(events[0] is InputEventKey)


func after_each():
	# Clean up any dynamic actions
	for i in range(10):
		var action_name := "fire_%d" % i
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		var utility_action_name := "utility_%d" % i
		if InputMap.has_action(utility_action_name):
			InputMap.erase_action(utility_action_name)
	GameManager.weapon_bindings = []
	GameManager.utility_bindings = []
