# test_autocannon.gd — Unit tests for the Autocannon weapon using GUT.
extends GutTest

const _EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")

var _autocannon: Autocannon
var _projectile: AutocannonProjectile

func before_each() -> void:
	_autocannon = Autocannon.new()
	add_child_autofree(_autocannon)

# ─── Autocannon initial state ─────────────────────────────────────────────────

func test_default_damage_is_positive() -> void:
	assert_gt(_autocannon._damage, 0, "Default damage should be positive")

func test_default_pierce_is_positive() -> void:
	assert_gt(_autocannon._pierce, 0, "Default pierce should be positive")

func test_cooldown_starts_at_zero() -> void:
	assert_eq(_autocannon._cooldown, 0.0, "Cooldown should start at 0")

func test_flash_timer_starts_at_zero() -> void:
	assert_eq(_autocannon._flash_timer, 0.0, "Flash timer should start at 0")

# ─── setup() ─────────────────────────────────────────────────────────────────

func test_setup_applies_damage() -> void:
	var data := WeaponData.new()
	data.damage = 50
	_autocannon.setup(data)
	assert_eq(_autocannon._damage, 50, "Damage should be taken from WeaponData")

func test_setup_applies_pierce() -> void:
	var data := WeaponData.new()
	data.pierce = 3
	_autocannon.setup(data)
	assert_eq(_autocannon._pierce, 3, "Pierce should be taken from WeaponData")

func test_setup_with_zero_damage() -> void:
	var data := WeaponData.new()
	data.damage = 0
	_autocannon.setup(data)
	assert_eq(_autocannon._damage, 0, "Zero damage should be stored as-is")

# ─── Constants ───────────────────────────────────────────────────────────────

func test_fire_interval_is_positive() -> void:
	assert_gt(Autocannon.FIRE_INTERVAL, 0.0, "FIRE_INTERVAL must be positive")

func test_fire_interval_is_slow() -> void:
	# "Slow firing" as per spec: interval should be at least 0.5 s
	# assert_gt used as GUT doesn't provide assert_ge
	assert_true(Autocannon.FIRE_INTERVAL >= 0.5,
			"Autocannon should be slow-firing (>=0.5 s between shots)")

func test_projectile_speed_is_fast() -> void:
	# "Fast projectiles" as per spec: should be at least 500 px/s
	assert_true(Autocannon.PROJECTILE_SPEED >= 500.0,
			"Autocannon shells should travel fast (>=500 px/s)")

func test_colors_are_different() -> void:
	assert_ne(Autocannon.COLOR_IDLE, Autocannon.COLOR_FLASH,
			"Muzzle-flash and idle colours must differ for visual feedback")

# ─── Autocannon projectile ────────────────────────────────────────────────────

func test_projectile_default_damage_positive() -> void:
	_projectile = AutocannonProjectile.new()
	add_child_autofree(_projectile)
	assert_gt(_projectile.damage, 0, "Projectile default damage should be positive")

func test_projectile_default_pierce_positive() -> void:
	_projectile = AutocannonProjectile.new()
	add_child_autofree(_projectile)
	assert_gt(_projectile.pierce, 0, "Projectile default pierce should be positive")

func test_projectile_velocity_defaults_to_zero() -> void:
	_projectile = AutocannonProjectile.new()
	add_child_autofree(_projectile)
	assert_eq(_projectile.velocity, Vector2.ZERO,
			"Projectile velocity should start at zero before setup")

func test_projectile_max_lifetime_positive() -> void:
	assert_gt(AutocannonProjectile.MAX_LIFETIME, 0.0,
			"Projectile MAX_LIFETIME must be positive")

# ─── Explosion ───────────────────────────────────────────────────────────────

func test_explosion_max_radius_positive() -> void:
	assert_gt(AutocannonExplosion.MAX_RADIUS, 0.0,
			"Explosion MAX_RADIUS must be positive")

func test_explosion_expand_time_positive() -> void:
	assert_gt(AutocannonExplosion.EXPAND_TIME, 0.0,
			"Explosion EXPAND_TIME must be positive")

func test_explosion_fade_time_positive() -> void:
	assert_gt(AutocannonExplosion.FADE_TIME, 0.0,
			"Explosion FADE_TIME must be positive")

func test_explosion_colors_differ() -> void:
	assert_ne(AutocannonExplosion.COLOR_FILL, AutocannonExplosion.COLOR_RING,
			"Fill and ring colours should differ for visual depth")

func test_explosion_starts_in_expand_state() -> void:
	var explosion: AutocannonExplosion = _EXPLOSION_SCENE.instantiate()
	add_child_autofree(explosion)
	assert_eq(explosion._state, 0, "Explosion should start in expand state (0)")

func test_explosion_oneshots_infantry() -> void:
	var explosion: AutocannonExplosion = _EXPLOSION_SCENE.instantiate()
	add_child_autofree(explosion)
	var infantry_health: int = 8  # EnemyInfantry.max_health default
	assert_true(explosion.damage >= infantry_health,
			"Explosion damage (%d) must one-shot infantry (%d HP)" % [explosion.damage, infantry_health])
