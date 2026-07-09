# test_pom_pom.gd — Unit tests for the Pom-Pom Gun light weapon using GUT.
extends GutTest

var _gun: PomPomGun

func before_each() -> void:
	_gun = PomPomGun.new()
	add_child_autofree(_gun)

# ─── Initial state ───────────────────────────────────────────────────────────

func test_default_damage_is_positive() -> void:
	assert_gt(_gun._damage, 0, "Default damage should be positive")

func test_starts_with_full_ammo() -> void:
	assert_eq(_gun.get_ammo_count(), PomPomGun.MAX_AMMO)

func test_not_bursting_initially() -> void:
	assert_eq(_gun._burst_remaining, 0, "Should not start mid-burst")

# ─── setup() ─────────────────────────────────────────────────────────────────

func test_setup_applies_weapon_data() -> void:
	var data := WeaponData.new()
	data.damage = 9
	data.pierce = 2
	data.penetration = 5
	data.projectile_count = 6
	data.cooldown = 1.3
	data.area = 0.8
	_gun.setup(data)
	assert_eq(_gun._damage, 9)
	assert_eq(_gun._pierce, 2)
	assert_eq(_gun._penetration, 5)
	assert_eq(_gun._burst_size, 6, "Burst size comes from projectile_count")
	assert_eq(_gun._recovery_time, 1.3)
	assert_eq(_gun._aoe_scale, 0.8)

func test_setup_clamps_burst_size_to_minimum_one() -> void:
	var data := WeaponData.new()
	data.projectile_count = 0
	_gun.setup(data)
	assert_eq(_gun._burst_size, 1, "Burst size should be at least 1")

# ─── Burst behaviour ─────────────────────────────────────────────────────────

func test_start_burst_fires_first_shell_immediately() -> void:
	var before := _gun.get_ammo_count()
	_gun._start_burst()
	assert_eq(_gun.get_ammo_count(), before - 1, "First shell fires on burst start")
	assert_eq(_gun._burst_remaining, PomPomGun.BURST_SIZE - 1)

func test_burst_uses_rhythm_interval_between_shells() -> void:
	_gun._start_burst()
	assert_almost_eq(_gun._cooldown, PomPomGun.BURST_INTERVAL, 0.001,
			"Mid-burst cooldown should be the pom-pom rhythm interval")

func test_last_shell_triggers_recovery() -> void:
	var data := WeaponData.new()
	data.projectile_count = 1
	data.cooldown = 0.9
	_gun.setup(data)
	_gun._start_burst()
	assert_eq(_gun._burst_remaining, 0, "Single-shell burst ends immediately")
	assert_almost_eq(_gun._cooldown, 0.9, 0.001, "Recovery follows the last shell")

func test_cannot_fire_during_recovery() -> void:
	_gun._cooldown = 0.5
	assert_false(_gun.can_fire(), "Should not fire while recovering")

func test_cannot_fire_when_out_of_ammo() -> void:
	_gun._ammo_current = 0
	assert_false(_gun.can_fire(), "Should not fire when ammo is empty")
	assert_true(_gun.is_out_of_ammo())

func test_burst_limited_by_remaining_ammo() -> void:
	_gun._ammo_current = 2
	_gun._start_burst()
	assert_eq(_gun._burst_remaining, 1, "Burst should shrink to remaining ammo")

# ─── Shell ───────────────────────────────────────────────────────────────────

func test_shell_defaults() -> void:
	var shell := PomPomShell.new()
	autofree(shell)
	assert_gt(shell.damage, 0)
	assert_gt(shell.aoe_scale, 0.0)
	assert_gt(PomPomShell.FUSE_TIME, 0.0, "Shell must have an airburst fuse")
