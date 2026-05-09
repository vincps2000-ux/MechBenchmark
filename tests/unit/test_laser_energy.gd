# test_laser_energy.gd — Focused unit tests for laser energy gating.
extends GutTest

const _LASER_SCRIPT := preload("res://src/weapons/laser.gd")

class MockEnergyOwner extends Node2D:
	var current_energy: float = 100.0

	func has_energy_for(amount: float) -> bool:
		return current_energy + 0.0001 >= amount

	func consume_energy(amount: float) -> bool:
		if not has_energy_for(amount):
			return false
		current_energy = maxf(0.0, current_energy - amount)
		return true

var _owner: MockEnergyOwner
var _laser

func before_each() -> void:
	_owner = MockEnergyOwner.new()
	add_child_autofree(_owner)
	_laser = _LASER_SCRIPT.new()
	_owner.add_child(_laser)

func test_laser_energy_cost_per_second_is_twenty() -> void:
	assert_eq(_laser.get_energy_cost_per_second(), 20.0,
		"Laser should cost 20 energy per second of fire")
	assert_gt(_laser.get_cool_off_duration(), 0.0,
		"Laser should have a positive cool-off period after energy depletion")

func test_try_consume_energy_spends_twenty_for_one_second() -> void:
	var consumed: bool = _laser._try_consume_energy(1.0)
	assert_true(consumed, "Laser should consume energy when enough charge is available")
	assert_eq(_owner.current_energy, 80.0,
		"One second of laser fire should spend 20 energy")

func test_try_consume_energy_fails_without_enough_charge() -> void:
	_owner.current_energy = 10.0
	assert_false(_laser._try_consume_energy(1.0),
		"Laser should not fire when the shared energy pool is too low")
	assert_eq(_owner.current_energy, 10.0,
		"Failed laser fire should not change energy")

func test_laser_enters_cool_off_when_energy_breaks() -> void:
	_owner.current_energy = 4.0
	_laser._enter_cool_off()
	assert_false(_laser._can_resume_fire(),
		"Laser should be locked out during cool-off")
	_laser._update_cool_off(_laser.get_cool_off_duration())
	assert_false(_laser._can_resume_fire(),
		"Laser should still wait for a restart charge after cool-off ends")

func test_laser_requires_restart_charge_after_cool_off() -> void:
	_owner.current_energy = 4.0
	_laser._enter_cool_off()
	_laser._update_cool_off(_laser.get_cool_off_duration())
	assert_false(_laser._can_resume_fire(),
		"Laser should not restart on tiny energy recovery")
	_owner.current_energy = 9.0
	assert_true(_laser._can_resume_fire(),
		"Laser should restart once enough recovery energy is available")