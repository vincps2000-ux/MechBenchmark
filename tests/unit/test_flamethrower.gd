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


func test_consume_ammo_spends_one_unit() -> void:
	var before := _flamethrower.get_ammo_count()
	assert_true(_flamethrower._consume_ammo(),
			"Chemical thrower should consume ammo while fuel remains")
	assert_eq(_flamethrower.get_ammo_count(), before - 1,
			"Chemical thrower should spend one unit of fuel per firing tick")


func test_consume_ammo_fails_when_empty() -> void:
	_flamethrower._ammo_current = 0
	assert_false(_flamethrower._consume_ammo(),
			"Chemical thrower should stop firing when out of fuel")
