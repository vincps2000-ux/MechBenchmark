# test_machinegun.gd — Unit tests for the Machinegun weapon using GUT.
extends GutTest

var _machinegun: Machinegun
var _projectile: MachinegunProjectile

func before_each() -> void:
	_machinegun = Machinegun.new()
	add_child_autofree(_machinegun)

# ─── Machinegun initial state ────────────────────────────────────────────────

func test_default_damage_is_positive() -> void:
	assert_gt(_machinegun._damage, 0, "Default damage should be positive")

func test_default_pierce_is_positive() -> void:
	assert_gt(_machinegun._pierce, 0, "Default pierce should be positive")

func test_cooldown_starts_at_zero() -> void:
	assert_eq(_machinegun._cooldown, 0.0, "Cooldown should start at 0")

func test_flash_timer_starts_at_zero() -> void:
	assert_eq(_machinegun._flash_timer, 0.0, "Flash timer should start at 0")

# ─── setup() ─────────────────────────────────────────────────────────────────

func test_setup_applies_damage() -> void:
	var data := WeaponData.new()
	data.damage = 20
	_machinegun.setup(data)
	assert_eq(_machinegun._damage, 20, "Damage should be taken from WeaponData")

func test_setup_applies_pierce() -> void:
	var data := WeaponData.new()
	data.pierce = 2
	_machinegun.setup(data)
	assert_eq(_machinegun._pierce, 2, "Pierce should be taken from WeaponData")

func test_setup_applies_penetration() -> void:
	var data := WeaponData.new()
	data.penetration = 1
	_machinegun.setup(data)
	assert_eq(_machinegun._penetration, 1, "Penetration should be taken from WeaponData")

func test_setup_with_zero_damage() -> void:
	var data := WeaponData.new()
	data.damage = 0
	_machinegun.setup(data)
	assert_eq(_machinegun._damage, 0, "Zero damage should be stored as-is")

func test_short_barrel_is_fast_and_inaccurate() -> void:
	var data := WeaponData.new()
	data.barrel_length = WeaponData.BarrelLength.VERY_SHORT
	_machinegun.setup(data)
	assert_lt(_machinegun._fire_interval, Machinegun.FIRE_INTERVAL,
			"Very short barrel should fire faster than the default setup")
	assert_gt(_machinegun._spread_deg, Machinegun.SPREAD_DEG,
			"Very short barrel should be less accurate than the default setup")
	assert_lt(_machinegun._projectile_lifetime, MachinegunProjectile.MAX_LIFETIME,
			"Very short barrel should shorten effective range")

func test_long_barrel_is_slow_and_accurate() -> void:
	var data := WeaponData.new()
	data.barrel_length = WeaponData.BarrelLength.VERY_LONG
	_machinegun.setup(data)
	assert_gt(_machinegun._fire_interval, Machinegun.FIRE_INTERVAL,
			"Very long barrel should fire slower than the default setup")
	assert_lt(_machinegun._spread_deg, Machinegun.SPREAD_DEG,
			"Very long barrel should be more accurate than the default setup")
	assert_gt(_machinegun._projectile_lifetime, MachinegunProjectile.MAX_LIFETIME,
			"Very long barrel should extend effective range")

# ─── Constants ───────────────────────────────────────────────────────────────

func test_fire_interval_is_positive() -> void:
	assert_gt(Machinegun.FIRE_INTERVAL, 0.0, "FIRE_INTERVAL must be positive")

func test_fire_interval_is_rapid() -> void:
	assert_true(Machinegun.FIRE_INTERVAL <= 0.15,
			"Machinegun should be rapid-fire (<=0.15 s between shots)")

func test_projectile_speed_is_fast() -> void:
	assert_true(Machinegun.PROJECTILE_SPEED >= 500.0,
			"Machinegun bullets should travel fast (>=500 px/s)")

func test_colors_are_different() -> void:
	assert_ne(Machinegun.COLOR_IDLE, Machinegun.COLOR_FLASH,
			"Muzzle-flash and idle colours must differ for visual feedback")

# ─── Machinegun projectile ────────────────────────────────────────────────────

func test_projectile_default_damage_positive() -> void:
	_projectile = MachinegunProjectile.new()
	add_child_autofree(_projectile)
	assert_gt(_projectile.damage, 0, "Projectile default damage should be positive")

func test_projectile_default_pierce_is_one() -> void:
	_projectile = MachinegunProjectile.new()
	add_child_autofree(_projectile)
	assert_eq(_projectile.pierce, 1, "Machinegun bullets should not pierce by default")

func test_projectile_velocity_defaults_to_zero() -> void:
	_projectile = MachinegunProjectile.new()
	add_child_autofree(_projectile)
	assert_eq(_projectile.velocity, Vector2.ZERO, "Velocity should default to zero")

func test_projectile_does_not_explode() -> void:
	_projectile = MachinegunProjectile.new()
	add_child_autofree(_projectile)
	assert_false(_projectile.has_method("_spawn_explosion"),
			"Machinegun bullets should not explode")

# ─── Balance: kills infantry in 3 shots ──────────────────────────────────────

func test_penetration_beats_infantry_armor() -> void:
	# Infantry armor = 3; machinegun pen must exceed it for reliable hits
	assert_gt(_machinegun._penetration, 3,
			"Penetration should exceed infantry armor (3) for 100% hit chance")

func test_three_shots_kill_infantry() -> void:
	# Infantry HP = 8; 3 × damage must be enough to kill
	var total := _machinegun._damage * 3
	assert_true(total >= 8,
			"Three shots (%d dmg) should kill infantry (8 HP)" % total)

func test_two_shots_dont_kill_infantry() -> void:
	# Should NOT kill in only 2 shots — keeps the weapon balanced
	var total := _machinegun._damage * 2
	assert_lt(total, 8,
			"Two shots (%d dmg) should not kill infantry (8 HP)" % total)
