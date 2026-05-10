extends GutTest

const DMD = preload("res://src/player/drone_modification_data.gd")
var _sut: Variant


func before_each():
	_sut = DMD.new()


func test_default_modification_layout_is_empty():
	assert_eq(_sut.modification_layout.size(), 3, "Should have 3 slots")
	for component in _sut.modification_layout:
		assert_eq(component, DMD.ComponentType.EMPTY, "All slots should be empty")


func test_is_empty_returns_true_for_new_data():
	assert_true(_sut.is_empty(), "New modification data should be empty")


func test_battery_bonus_starts_at_zero():
	assert_eq(_sut.get_battery_bonus(), 0, "No battery bonus without battery modules")


func test_explosive_charge_count_starts_at_zero():
	assert_eq(_sut.get_explosive_charge_count(), 0, "No explosive charges without modules")


func test_place_battery_in_slot_zero():
	var placed = _sut.try_place_component(0, DMD.ComponentType.BATTERY)
	assert_true(placed, "Should place battery in empty slot")
	assert_eq(_sut.modification_layout[0], DMD.ComponentType.BATTERY)


func test_cannot_place_in_occupied_slot():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	var placed = _sut.try_place_component(0, DMD.ComponentType.BATTERY)
	assert_false(placed, "Should not place in occupied slot")


func test_battery_bonus_from_single_module():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	var bonus = _sut.get_battery_bonus()
	assert_eq(bonus, DMD.BATTERY_HEALTH_PER_MODULE, "One battery module gives base bonus")


func test_battery_bonus_from_multiple_modules():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	_sut.try_place_component(1, DMD.ComponentType.BATTERY)
	var bonus = _sut.get_battery_bonus()
	assert_eq(bonus, DMD.BATTERY_HEALTH_PER_MODULE * 2, "Two battery modules give double bonus")


func test_fire_control_takes_two_slots():
	var placed = _sut.try_place_component(0, DMD.ComponentType.FIRE_CONTROL)
	assert_true(placed, "Should place fire control in slot 0")
	assert_eq(_sut.modification_layout[0], DMD.ComponentType.FIRE_CONTROL)
	assert_eq(_sut.modification_layout[1], DMD.ComponentType.FIRE_CONTROL, "Fire control should occupy slot 1 too")


func test_fire_control_fails_if_not_enough_space():
	var placed = _sut.try_place_component(2, DMD.ComponentType.FIRE_CONTROL)
	assert_false(placed, "Should fail to place fire control at slot 2 (not enough space)")


func test_fire_control_fails_if_slot_occupied():
	_sut.try_place_component(1, DMD.ComponentType.BATTERY)
	var placed = _sut.try_place_component(0, DMD.ComponentType.FIRE_CONTROL)
	assert_false(placed, "Should fail if next slot is occupied")


func test_has_fire_control_module_when_present():
	_sut.try_place_component(0, DMD.ComponentType.FIRE_CONTROL)
	assert_true(_sut.has_fire_control_module(), "Should have fire control when module is installed")


func test_has_fire_control_module_when_absent():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	assert_false(_sut.has_fire_control_module(), "Should not have fire control without module")


func test_explosive_charge_count_single():
	_sut.try_place_component(0, DMD.ComponentType.EXPLOSIVE_CHARGE)
	assert_eq(_sut.get_explosive_charge_count(), 1, "Should count one explosive charge")


func test_explosion_damage_without_charges():
	assert_eq(_sut.get_explosion_damage(), 0, "No damage without charges")


func test_explosion_damage_with_single_charge():
	_sut.try_place_component(0, DMD.ComponentType.EXPLOSIVE_CHARGE)
	var damage = _sut.get_explosion_damage()
	var expected = DMD.EXPLOSIVE_CHARGE_BASE_DAMAGE + DMD.EXPLOSIVE_CHARGE_DAMAGE_PER_MODULE
	assert_eq(damage, expected, "Single charge gives scaled damage")


func test_explosion_damage_with_multiple_charges():
	_sut.try_place_component(0, DMD.ComponentType.EXPLOSIVE_CHARGE)
	_sut.try_place_component(1, DMD.ComponentType.EXPLOSIVE_CHARGE)
	var damage = _sut.get_explosion_damage()
	var expected = (
		DMD.EXPLOSIVE_CHARGE_BASE_DAMAGE +
		DMD.EXPLOSIVE_CHARGE_DAMAGE_PER_MODULE * 2
	)
	assert_eq(damage, expected, "Two charges give base + 2x per-module damage")


func test_explosion_radius_without_charges():
	assert_eq(_sut.get_explosion_radius(), 0.0, "No radius without charges")


func test_explosion_radius_with_single_charge():
	_sut.try_place_component(0, DMD.ComponentType.EXPLOSIVE_CHARGE)
	var radius = _sut.get_explosion_radius()
	var expected = DMD.EXPLOSIVE_CHARGE_BASE_RADIUS + DMD.EXPLOSIVE_CHARGE_RADIUS_PER_MODULE
	assert_eq(radius, expected, "Single charge gives scaled radius")


func test_explosion_radius_with_multiple_charges():
	_sut.try_place_component(0, DMD.ComponentType.EXPLOSIVE_CHARGE)
	_sut.try_place_component(1, DMD.ComponentType.EXPLOSIVE_CHARGE)
	var radius = _sut.get_explosion_radius()
	var expected = (
		DMD.EXPLOSIVE_CHARGE_BASE_RADIUS +
		DMD.EXPLOSIVE_CHARGE_RADIUS_PER_MODULE * 2
	)
	assert_eq(radius, expected, "Two charges give base + 2x per-module radius")


func test_clear_slot_battery():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	_sut.clear_slot(0)
	assert_eq(_sut.modification_layout[0], DMD.ComponentType.EMPTY)


func test_clear_slot_fire_control_clears_both():
	_sut.try_place_component(0, DMD.ComponentType.FIRE_CONTROL)
	_sut.clear_slot(0)
	assert_eq(_sut.modification_layout[0], DMD.ComponentType.EMPTY)
	assert_eq(_sut.modification_layout[1], DMD.ComponentType.EMPTY)


func test_clear_all_slots():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	_sut.try_place_component(1, DMD.ComponentType.EXPLOSIVE_CHARGE)
	_sut.clear_all()
	assert_true(_sut.is_empty(), "All slots should be empty after clear_all")


func test_get_component_slot_cost_battery():
	var cost: int = DMD.get_component_slot_cost(DMD.ComponentType.BATTERY)
	assert_eq(cost, 1, "Battery costs 1 slot")


func test_get_component_slot_cost_fire_control():
	var cost: int = DMD.get_component_slot_cost(DMD.ComponentType.FIRE_CONTROL)
	assert_eq(cost, 2, "Fire control costs 2 slots")


func test_get_component_slot_cost_explosive_charge():
	var cost: int = DMD.get_component_slot_cost(DMD.ComponentType.EXPLOSIVE_CHARGE)
	assert_eq(cost, 1, "Explosive charge costs 1 slot")


func test_get_component_name_battery():
	var name_str: String = DMD.get_component_name(DMD.ComponentType.BATTERY)
	assert_eq(name_str, "Battery")


func test_get_component_name_fire_control():
	var name_str: String = DMD.get_component_name(DMD.ComponentType.FIRE_CONTROL)
	assert_eq(name_str, "Fire Control")


func test_get_component_name_explosive_charge():
	var name_str: String = DMD.get_component_name(DMD.ComponentType.EXPLOSIVE_CHARGE)
	assert_eq(name_str, "Explosive Charge")


func test_maximum_three_battery_modules():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	_sut.try_place_component(1, DMD.ComponentType.BATTERY)
	_sut.try_place_component(2, DMD.ComponentType.BATTERY)
	assert_false(_sut.is_empty(), "Should have 3 battery modules")
	var bonus: float = _sut.get_battery_bonus()
	assert_eq(bonus, DMD.BATTERY_HEALTH_PER_MODULE * 3, "Three batteries give triple bonus")


func test_mixed_configuration():
	_sut.try_place_component(0, DMD.ComponentType.BATTERY)
	_sut.try_place_component(1, DMD.ComponentType.FIRE_CONTROL)
	# Fire control already took slot 2, so we can't add more
	assert_eq(_sut.get_battery_bonus(), DMD.BATTERY_HEALTH_PER_MODULE)
	assert_true(_sut.has_fire_control_module())
	assert_eq(_sut.get_explosive_charge_count(), 0)


func test_custom_initialization():
	var custom_layout = [
		DMD.ComponentType.BATTERY,
		DMD.ComponentType.EXPLOSIVE_CHARGE,
		DMD.ComponentType.EXPLOSIVE_CHARGE,
	]
	var custom = DMD.new(custom_layout)
	assert_eq(custom.get_battery_bonus(), DMD.BATTERY_HEALTH_PER_MODULE)
	assert_eq(custom.get_explosive_charge_count(), 2)
	var damage = custom.get_explosion_damage()
	var expected = (
		DMD.EXPLOSIVE_CHARGE_BASE_DAMAGE +
		DMD.EXPLOSIVE_CHARGE_DAMAGE_PER_MODULE * 2
	)
	assert_eq(damage, expected)


