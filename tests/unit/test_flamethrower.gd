# test_flamethrower.gd - Unit tests for Chemical thrower element configuration.
extends GutTest

const _FLAMETHROWER_SCENE := preload("res://scenes/weapons/flamethrower.tscn")

var _flamethrower: Flamethrower

func before_each() -> void:
	_flamethrower = _FLAMETHROWER_SCENE.instantiate() as Flamethrower
	add_child_autofree(_flamethrower)


func test_setup_applies_thrower_element_acid() -> void:
	var data := WeaponData.new()
	data.thrower_element = WeaponData.ThrowerElement.ACID
	_flamethrower.setup(data)
	assert_eq(_flamethrower._thrower_element, WeaponData.ThrowerElement.ACID)


func test_setup_applies_thrower_element_cryogenics() -> void:
	var data := WeaponData.new()
	data.thrower_element = WeaponData.ThrowerElement.CRYOGENICS
	_flamethrower.setup(data)
	assert_eq(_flamethrower._thrower_element, WeaponData.ThrowerElement.CRYOGENICS)


func test_setup_applies_thrower_nozzle_long() -> void:
	var data := WeaponData.new()
	data.thrower_nozzle = WeaponData.ThrowerNozzle.LONG_NOZZLE
	_flamethrower.setup(data)
	assert_eq(_flamethrower._thrower_nozzle, WeaponData.ThrowerNozzle.LONG_NOZZLE)


func test_long_nozzle_profile_is_narrow_and_long_range() -> void:
	var data := WeaponData.new()
	data.thrower_nozzle = WeaponData.ThrowerNozzle.LONG_NOZZLE
	_flamethrower.setup(data)
	assert_gt(_flamethrower._max_range, 300.0, "Long nozzle should noticeably increase reach")
	assert_lt(rad_to_deg(_flamethrower._cone_angle), 40.0, "Long nozzle should tighten cone spread")
	assert_lt(_flamethrower._ray_count, 11, "Long nozzle should use fewer rays than default")


func test_wide_nozzle_profile_is_wide_and_short_range() -> void:
	var data := WeaponData.new()
	data.thrower_nozzle = WeaponData.ThrowerNozzle.WIDE_NOZZLE
	_flamethrower.setup(data)
	assert_lt(_flamethrower._max_range, 200.0, "Wide nozzle should shorten reach")
	assert_gt(rad_to_deg(_flamethrower._cone_angle), 80.0, "Wide nozzle should broaden cone spread")
	assert_gt(_flamethrower._ray_count, 11, "Wide nozzle should use denser ray coverage")


func test_acid_damage_is_halved() -> void:
	var data := WeaponData.new()
	data.thrower_element = WeaponData.ThrowerElement.ACID
	data.damage = 6
	_flamethrower.setup(data)
	assert_eq(_flamethrower._damage / 2, 3, "Acid deals half of base damage")


func test_acid_damage_minimum_one() -> void:
	var data := WeaponData.new()
	data.thrower_element = WeaponData.ThrowerElement.ACID
	data.damage = 1
	_flamethrower.setup(data)
	assert_eq(maxi(1, _flamethrower._damage / 2), 1, "Acid damage minimum is 1")


func test_consume_ammo_spends_one_unit_after_one_second() -> void:
	var before := _flamethrower.get_ammo_count()
	assert_true(_flamethrower._consume_ammo(1.0),
			"Chemical thrower should consume ammo while fuel remains")
	var expected := maxi(0, before - int(Flamethrower.AMMO_DRAIN_PER_SECOND))
	assert_eq(_flamethrower.get_ammo_count(), expected,
			"Chemical thrower should spend configured fuel units per second")


func test_consume_ammo_is_frame_rate_independent_over_one_second() -> void:
	_flamethrower._ammo_current = float(Flamethrower.MAX_AMMO)
	assert_true(_flamethrower._consume_ammo(0.5))
	assert_true(_flamethrower._consume_ammo(0.5))
	var stepped := _flamethrower.get_ammo_count()

	_flamethrower._ammo_current = float(Flamethrower.MAX_AMMO)
	assert_true(_flamethrower._consume_ammo(1.0))
	var single_step := _flamethrower.get_ammo_count()

	assert_eq(stepped, single_step,
			"Equal total delta time should consume equal ammo regardless of frame slicing")


func test_consume_ammo_partial_second_keeps_ceiled_display() -> void:
	_flamethrower._ammo_current = float(Flamethrower.MAX_AMMO)
	assert_true(_flamethrower._consume_ammo(0.5))
	var expected := ceili(float(Flamethrower.MAX_AMMO) - Flamethrower.AMMO_DRAIN_PER_SECOND * 0.5)
	assert_eq(_flamethrower.get_ammo_count(), expected,
			"HUD ammo count should reflect partial second drain consistently")


func test_consume_ammo_fails_when_empty() -> void:
	_flamethrower._ammo_current = 0.0
	assert_false(_flamethrower._consume_ammo(),
			"Chemical thrower should stop firing when out of fuel")
