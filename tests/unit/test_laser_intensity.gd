# test_laser_intensity.gd — Unit tests for laser energy-intensity customisation.
extends GutTest

const _LASER_SCRIPT := preload("res://src/weapons/laser.gd")
const _WEAPON_DATA_SCRIPT := preload("res://src/weapons/weapon_data.gd")

class MockEnergyOwner extends Node2D:
	var current_energy: float = 200.0

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


func _make_data(intensity: int) -> WeaponData:
	var data := WeaponData.new()
	data.weapon_type = WeaponData.WeaponType.LASER
	data.laser_intensity = intensity
	return data


# ── Default intensity ──────────────────────────────────────────────────────────

func test_default_intensity_is_two() -> void:
	var data := WeaponData.new()
	assert_eq(data.laser_intensity, 2,
		"Default laser intensity should be 2 (Standard)")


# ── Static stats lookup ───────────────────────────────────────────────────────

func test_get_stats_for_intensity_flicker() -> void:
	var stats: Array = _LASER_SCRIPT.get_stats_for_intensity(0)
	assert_eq(stats[0], 2.0,  "Flicker energy cost should be 2.0/s")
	assert_eq(stats[1], 2,    "Flicker damage should be 2")
	assert_eq(stats[2], 1,    "Flicker penetration should be 1")


func test_get_stats_for_intensity_standard() -> void:
	var stats: Array = _LASER_SCRIPT.get_stats_for_intensity(2)
	assert_eq(stats[0], 20.0, "Standard energy cost should be 20.0/s")
	assert_eq(stats[1], 12,   "Standard damage should be 12")
	assert_eq(stats[2], 3,    "Standard penetration should be 3")


func test_get_stats_for_intensity_overload() -> void:
	var stats: Array = _LASER_SCRIPT.get_stats_for_intensity(4)
	assert_eq(stats[0], 50.0, "Overload energy cost should be 50.0/s")
	assert_eq(stats[1], 35,   "Overload damage should be 35")
	assert_eq(stats[2], 8,    "Overload penetration should be 8")


func test_get_stats_clamps_below_zero() -> void:
	var stats_m1: Array = _LASER_SCRIPT.get_stats_for_intensity(-1)
	var stats_0:  Array = _LASER_SCRIPT.get_stats_for_intensity(0)
	assert_eq(stats_m1[0], stats_0[0], "Negative intensity should clamp to 0")


func test_get_stats_clamps_above_four() -> void:
	var stats_5: Array = _LASER_SCRIPT.get_stats_for_intensity(5)
	var stats_4: Array = _LASER_SCRIPT.get_stats_for_intensity(4)
	assert_eq(stats_5[0], stats_4[0], "Intensity above 4 should clamp to 4")


# ── setup() applies intensity ─────────────────────────────────────────────────

func test_setup_intensity_0_sets_flicker_energy_cost() -> void:
	_laser.setup(_make_data(0))
	assert_eq(_laser.get_energy_cost_per_second(), 2.0,
		"Flicker intensity should cost 2 energy/s")


func test_setup_intensity_4_sets_overload_energy_cost() -> void:
	_laser.setup(_make_data(4))
	assert_eq(_laser.get_energy_cost_per_second(), 50.0,
		"Overload intensity should cost 50 energy/s")


func test_setup_intensity_2_matches_legacy_default() -> void:
	_laser.setup(_make_data(2))
	assert_eq(_laser.get_energy_cost_per_second(), 20.0,
		"Standard intensity should match the original 20 energy/s baseline")


func test_setup_intensity_0_sets_flicker_damage() -> void:
	_laser.setup(_make_data(0))
	assert_eq(_laser._damage, 2, "Flicker damage should be 2")


func test_setup_intensity_4_sets_overload_damage() -> void:
	_laser.setup(_make_data(4))
	assert_eq(_laser._damage, 35, "Overload damage should be 35")


func test_setup_intensity_0_sets_flicker_penetration() -> void:
	_laser.setup(_make_data(0))
	assert_eq(_laser._penetration, 1, "Flicker penetration should be 1")


func test_setup_intensity_4_sets_overload_penetration() -> void:
	_laser.setup(_make_data(4))
	assert_eq(_laser._penetration, 8, "Overload penetration should be 8")


# ── Energy consumption scales with intensity ──────────────────────────────────

func test_overload_consumes_fifty_energy_per_second() -> void:
	_laser.setup(_make_data(4))
	_owner.current_energy = 200.0
	var consumed: bool = _laser._try_consume_energy(1.0)
	assert_true(consumed, "Overload should consume energy when available")
	assert_eq(_owner.current_energy, 150.0,
		"Overload should spend 50 energy in one second")


func test_flicker_consumes_two_energy_per_second() -> void:
	_laser.setup(_make_data(0))
	_owner.current_energy = 100.0
	var consumed: bool = _laser._try_consume_energy(1.0)
	assert_true(consumed, "Flicker should consume energy when available")
	assert_eq(_owner.current_energy, 98.0,
		"Flicker should spend 2 energy in one second")


func test_flicker_fires_on_tiny_energy_pool() -> void:
	_laser.setup(_make_data(0))
	_owner.current_energy = 3.0
	assert_true(_laser._try_consume_energy(1.0),
		"Flicker should fire on a 3-energy pool (costs only 2/s)")


func test_overload_fails_on_thirty_energy() -> void:
	_laser.setup(_make_data(4))
	_owner.current_energy = 30.0
	assert_false(_laser._try_consume_energy(1.0),
		"Overload should fail when pool has less than 50 energy")


# ── Damage ordering ───────────────────────────────────────────────────────────

func test_higher_intensity_has_greater_damage() -> void:
	for i in range(1, 5):
		var lo: Array = _LASER_SCRIPT.get_stats_for_intensity(i - 1)
		var hi: Array = _LASER_SCRIPT.get_stats_for_intensity(i)
		assert_lt(lo[1], hi[1],
			"Intensity %d damage should exceed intensity %d" % [i, i - 1])


func test_higher_intensity_has_greater_penetration() -> void:
	for i in range(1, 5):
		var lo: Array = _LASER_SCRIPT.get_stats_for_intensity(i - 1)
		var hi: Array = _LASER_SCRIPT.get_stats_for_intensity(i)
		assert_lt(lo[2], hi[2],
			"Intensity %d penetration should exceed intensity %d" % [i, i - 1])


func test_higher_intensity_costs_more_energy() -> void:
	for i in range(1, 5):
		var lo: Array = _LASER_SCRIPT.get_stats_for_intensity(i - 1)
		var hi: Array = _LASER_SCRIPT.get_stats_for_intensity(i)
		assert_lt(lo[0], hi[0],
			"Intensity %d energy cost should exceed intensity %d" % [i, i - 1])
