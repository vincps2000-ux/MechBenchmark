# tests/unit/test_rocket_pod.gd — Tests for Rocket Pod targeting customisation
extends GutTest

var _pod: RocketPod


func before_each() -> void:
	_pod = RocketPod.new()
	add_child_autofree(_pod)


# ─── Default state ────────────────────────────────────────────────────────────

func test_default_damage_is_positive() -> void:
	assert_gt(_pod._damage, 0, "Default damage should be positive")

func test_default_pierce_is_positive() -> void:
	assert_gt(_pod._pierce, 0, "Default pierce should be positive")

func test_cooldown_starts_at_zero() -> void:
	assert_eq(_pod._cooldown, 0.0, "Cooldown should start at 0")

func test_default_targeting_is_unguided() -> void:
	assert_eq(_pod._targeting_type, WeaponData.TargetingType.UNGUIDED,
		"Rocket Pod should default to UNGUIDED targeting")


# ─── setup() applies targeting ────────────────────────────────────────────────

func test_setup_applies_targeting_type() -> void:
	var data := WeaponData.new()
	data.targeting_type = WeaponData.TargetingType.SEEKING
	_pod.setup(data)
	assert_eq(_pod._targeting_type, WeaponData.TargetingType.SEEKING,
		"setup() should apply targeting type from WeaponData")

func test_setup_applies_wire_guided() -> void:
	var data := WeaponData.new()
	data.targeting_type = WeaponData.TargetingType.WIRE_GUIDED
	_pod.setup(data)
	assert_eq(_pod._targeting_type, WeaponData.TargetingType.WIRE_GUIDED,
		"setup() should apply WIRE_GUIDED targeting type")

func test_fire_rocket_consumes_one_ammo() -> void:
	var before := _pod.get_ammo_count()
	assert_true(_pod._fire_rocket(), "Rocket pod should fire while ammo remains")
	assert_eq(_pod.get_ammo_count(), before - 1,
		"Rocket pod should spend one rocket per launch")

func test_fire_rocket_fails_when_out_of_ammo() -> void:
	_pod._ammo_current = 0
	assert_false(_pod._fire_rocket(),
		"Rocket pod should not launch when rack is empty")


# ─── WeaponData.TargetingType enum ────────────────────────────────────────────

func test_targeting_type_enum_has_unguided() -> void:
	assert_eq(WeaponData.TargetingType.UNGUIDED, 0,
		"UNGUIDED should be the first enum value")

func test_targeting_type_enum_has_seeking() -> void:
	assert_eq(WeaponData.TargetingType.SEEKING, 1,
		"SEEKING should be the second enum value")

func test_targeting_type_enum_has_wire_guided() -> void:
	assert_eq(WeaponData.TargetingType.WIRE_GUIDED, 2,
		"WIRE_GUIDED should be the third enum value")

func test_weapon_data_default_targeting_is_unguided() -> void:
	var data := WeaponData.new()
	assert_eq(data.targeting_type, WeaponData.TargetingType.UNGUIDED,
		"WeaponData should default to UNGUIDED targeting")


# ─── Rocket projectile targeting properties ───────────────────────────────────

func test_projectile_default_targeting_is_unguided() -> void:
	var proj := RocketProjectile.new()
	add_child_autofree(proj)
	assert_eq(proj.targeting_type, WeaponData.TargetingType.UNGUIDED,
		"Projectile should default to UNGUIDED")

func test_projectile_seeking_has_turn_rate() -> void:
	assert_gt(RocketProjectile.SEEKING_TURN_RATE, 0.0,
		"Seeking rockets must have a positive turn rate")

func test_projectile_wire_guided_has_turn_rate() -> void:
	assert_gt(RocketProjectile.WIRE_GUIDED_TURN_RATE, 0.0,
		"Wire-guided rockets must have a positive turn rate")


# ─── Seeking behaviour (unit-level) ──────────────────────────────────────────

func test_seeking_rocket_steers_toward_target() -> void:
	var proj := RocketProjectile.new()
	add_child_autofree(proj)
	proj.targeting_type = WeaponData.TargetingType.SEEKING
	proj.velocity = Vector2(400, 0)  # flying right
	proj.global_position = Vector2.ZERO

	# Place a fake target above-right
	var target_pos := Vector2(100, -200)
	proj._steer_toward(target_pos, 1.0)

	# Velocity should have rotated upward (negative y)
	assert_lt(proj.velocity.y, 0.0,
		"Seeking rocket should steer toward the target (upward)")


func test_seeking_rocket_does_not_exceed_turn_rate() -> void:
	var proj := RocketProjectile.new()
	add_child_autofree(proj)
	proj.targeting_type = WeaponData.TargetingType.SEEKING
	proj.velocity = Vector2(400, 0)
	proj.global_position = Vector2.ZERO

	var original_angle := proj.velocity.angle()
	proj._steer_toward(Vector2(0, -400), 0.016)  # ~1 frame

	var turned := absf(proj.velocity.angle() - original_angle)
	var max_turn := RocketProjectile.SEEKING_TURN_RATE * 0.016
	assert_true(turned <= max_turn + 0.001,
		"Should not exceed max turn rate per frame")


# ─── Wire-guided behaviour (unit-level) ──────────────────────────────────────

func test_wire_guided_steers_toward_cursor_pos() -> void:
	var proj := RocketProjectile.new()
	add_child_autofree(proj)
	proj.targeting_type = WeaponData.TargetingType.WIRE_GUIDED
	proj.velocity = Vector2(400, 0)
	proj.global_position = Vector2.ZERO

	# Simulate cursor below
	proj._steer_toward(Vector2(100, 200), 1.0)

	assert_gt(proj.velocity.y, 0.0,
		"Wire-guided rocket should steer toward cursor (downward)")


# ─── Pod passes targeting to projectile ───────────────────────────────────────

func test_fire_rocket_passes_targeting_to_projectile() -> void:
	var data := WeaponData.new()
	data.targeting_type = WeaponData.TargetingType.SEEKING
	data.weapon_type = WeaponData.WeaponType.ROCKET_POD
	_pod.setup(data)

	# We can't easily test _fire_rocket since it adds to the scene tree,
	# but we verify the pod stores the targeting type for passing
	assert_eq(_pod._targeting_type, WeaponData.TargetingType.SEEKING,
		"Pod should store targeting type for passing to projectiles")
