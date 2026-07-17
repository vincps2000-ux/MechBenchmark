# test_machinegun.gd — Unit tests for the Machinegun weapon using GUT.
extends GutTest

const MACHINEGUN_SCENE := preload("res://scenes/weapons/machinegun.tscn")

class SmartTestMachinegun:
	extends Machinegun
	var target_available := false

	func _has_smart_target() -> bool:
		return target_available

class ProjectileTarget:
	extends Node2D
	var damage_received := 0
	var knockback_received := Vector2.ZERO

	func take_damage(amount: int, _penetration: int) -> void:
		damage_received += amount

	func apply_knockback(impulse: Vector2) -> void:
		knockback_received = impulse

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

func test_normal_ammo_preserves_baseline_damage_and_penetration() -> void:
	var data := WeaponData.new()
	data.damage = 6
	data.penetration = 4
	data.ammo_type = WeaponData.AmmoType.NORMAL
	_machinegun.setup(data)
	assert_eq(_machinegun._damage, 6, "Normal ammunition should use baseline damage")
	assert_eq(_machinegun._penetration, 4, "Normal ammunition should use baseline penetration")

func test_riot_rounds_deal_no_damage_and_enable_knockback() -> void:
	var data := WeaponData.new()
	data.damage = 6
	data.ammo_type = WeaponData.AmmoType.RIOT
	_machinegun.setup(data)
	assert_eq(_machinegun._damage, 0, "Riot rounds must deal no damage")
	assert_gt(_machinegun._knockback_force, 0.0, "Riot rounds should push enemies")

func test_smart_rounds_only_fire_with_cursor_lock() -> void:
	var smart_gun := SmartTestMachinegun.new()
	add_child_autofree(smart_gun)
	var data := WeaponData.new()
	data.ammo_type = WeaponData.AmmoType.SMART
	smart_gun.setup(data)
	smart_gun.target_available = false
	assert_false(smart_gun.can_fire(), "Smart rounds must not fire without an enemy under the cursor")
	smart_gun.target_available = true
	assert_true(smart_gun.can_fire(), "Smart rounds should fire while the cursor is over an enemy")

func test_smart_rounds_report_lock_state_for_hud() -> void:
	var smart_gun := SmartTestMachinegun.new()
	add_child_autofree(smart_gun)
	var data := WeaponData.new()
	data.ammo_type = WeaponData.AmmoType.SMART
	smart_gun.setup(data)
	assert_true(smart_gun.uses_smart_rounds())
	smart_gun.target_available = true
	assert_true(smart_gun.has_smart_lock())

func test_try_fire_once_consumes_one_ammo() -> void:
	var before := _machinegun.get_ammo_count()
	var fired := _machinegun.try_fire_once()
	assert_true(fired, "Machinegun should fire when ammo is available")
	assert_eq(_machinegun.get_ammo_count(), before - 1,
			"Machinegun should spend one round per shot")

func test_try_fire_once_fails_when_out_of_ammo() -> void:
	_machinegun._ammo_current = 0
	assert_false(_machinegun.try_fire_once(),
			"Machinegun should not fire when ammo is empty")

func test_four_barrels_fire_four_rounds_per_cycle() -> void:
	var data := WeaponData.new()
	data.barrel_count = 4
	_machinegun.setup(data)
	var before := _machinegun.get_ammo_count()
	assert_true(_machinegun.try_fire_once())
	assert_eq(_machinegun.get_ammo_count(), before - 4,
			"Each fitted barrel should fire and consume one round")

func test_more_barrels_increase_rate_and_spread() -> void:
	var data := WeaponData.new()
	data.barrel_count = 4
	_machinegun.setup(data)
	assert_lt(_machinegun._fire_interval, Machinegun.FIRE_INTERVAL,
			"A four-barrel cluster should cycle faster")
	assert_gt(_machinegun._spread_deg, Machinegun.SPREAD_DEG,
			"A four-barrel cluster should have a wider grouping")

func test_barrel_count_is_clamped_to_workbench_limits() -> void:
	assert_eq(WeaponData.clamp_barrel_count(0), 1)
	assert_eq(WeaponData.clamp_barrel_count(99), 4)

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

func test_riot_projectile_pushes_without_damage() -> void:
	_projectile = MachinegunProjectile.new()
	add_child_autofree(_projectile)
	_projectile.damage = 0
	_projectile.knockback_force = 240.0
	_projectile.velocity = Vector2.RIGHT * 600.0
	var target := ProjectileTarget.new()
	add_child_autofree(target)
	_projectile._on_body_entered(target)
	assert_eq(target.damage_received, 0, "Riot rounds must not damage their target")
	assert_gt(target.knockback_received.x, 0.0, "Riot rounds should push along their travel direction")

func test_in_game_visual_uses_one_sprite_per_selected_barrel() -> void:
	var scene_gun := MACHINEGUN_SCENE.instantiate() as Machinegun
	var data := WeaponData.new()
	data.barrel_count = 4
	scene_gun.setup(data)
	add_child_autofree(scene_gun)
	await get_tree().process_frame
	assert_eq(scene_gun.get_node("WeaponVisuals").get_child_count(), 4,
			"In-game model should show each selected barrel")

func test_in_game_visual_length_tracks_selected_barrel_length() -> void:
	var scene_gun := MACHINEGUN_SCENE.instantiate() as Machinegun
	var data := WeaponData.new()
	data.barrel_length = WeaponData.BarrelLength.VERY_LONG
	scene_gun.setup(data)
	add_child_autofree(scene_gun)
	await get_tree().process_frame
	var visual := scene_gun.get_node("WeaponVisuals").get_child(0) as Sprite2D
	assert_gt(visual.scale.y, 0.65, "Long barrels should lengthen the original in-game model")

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
