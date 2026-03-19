# test_weapon_data.gd — Unit tests for WeaponData using GUT
extends GutTest

var weapon: WeaponData

func before_each():
	weapon = WeaponData.new()
	weapon.name = "Test Blaster"
	weapon.damage = 10
	weapon.projectile_count = 1
	weapon.pierce = 1
	weapon.level = 1
	weapon.max_level = 8

func test_initial_state():
	assert_eq(weapon.level, 1)
	assert_eq(weapon.damage, 10)
	assert_eq(weapon.projectile_count, 1)

func test_can_level_up():
	assert_true(weapon.can_level_up(), "Should be able to level up at level 1")

func test_cannot_level_up_at_max():
	weapon.level = weapon.max_level
	assert_false(weapon.can_level_up(), "Should not be able to level up at max level")

func test_level_up_increases_damage():
	var old_damage = weapon.damage
	weapon.level_up()
	assert_gt(weapon.damage, old_damage, "Damage should increase on level up")

func test_level_up_increases_projectiles_at_even_levels():
	# Level 1 -> 2 (even level, gains projectile)
	weapon.level_up()
	assert_eq(weapon.level, 2)
	assert_eq(weapon.projectile_count, 2, "Should gain projectile at even level")

func test_level_up_increases_pierce_at_multiples_of_3():
	# Level up to 3
	weapon.level_up()  # 1 -> 2
	weapon.level_up()  # 2 -> 3
	assert_eq(weapon.pierce, 2, "Should gain pierce at level 3")

func test_level_up_does_nothing_at_max():
	weapon.level = weapon.max_level
	var old_damage = weapon.damage
	weapon.level_up()
	assert_eq(weapon.damage, old_damage, "Damage should not change at max level")
	assert_eq(weapon.level, weapon.max_level, "Level should not change at max level")

# ── WeaponType enum ──────────────────────────────────────────────────────────

func test_default_weapon_type_is_autocannon():
	assert_eq(weapon.weapon_type, WeaponData.WeaponType.AUTOCANNON,
		"Default weapon_type should be AUTOCANNON")

func test_weapon_type_can_be_set():
	weapon.weapon_type = WeaponData.WeaponType.LASER
	assert_eq(weapon.weapon_type, WeaponData.WeaponType.LASER,
		"weapon_type should be assignable to LASER")

func test_get_sprite_path_laser():
	weapon.weapon_type = WeaponData.WeaponType.LASER
	assert_eq(weapon.get_sprite_path(), "res://assets/sprites/weapon_laser.svg",
		"Laser should use the laser sprite")

func test_get_sprite_path_railgun():
	weapon.weapon_type = WeaponData.WeaponType.RAILGUN
	assert_eq(weapon.get_sprite_path(), "res://assets/sprites/weapon_laser.svg",
		"Railgun should use the laser sprite")

func test_get_sprite_path_flamethrower():
	weapon.weapon_type = WeaponData.WeaponType.FLAMETHROWER
	assert_eq(weapon.get_sprite_path(), "res://assets/sprites/weapon_gun.svg",
		"Flamethrower should use the gun sprite")

func test_get_sprite_path_autocannon():
	weapon.weapon_type = WeaponData.WeaponType.AUTOCANNON
	assert_eq(weapon.get_sprite_path(), "res://assets/sprites/weapon_autocannon.svg",
		"Autocannon should use the dedicated autocannon sprite")
