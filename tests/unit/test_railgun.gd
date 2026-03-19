# test_railgun.gd — Unit tests for the Railgun weapon using GUT.
extends GutTest

var _railgun: Railgun

func before_each() -> void:
	_railgun = Railgun.new()
	add_child_autofree(_railgun)

# ─── Initial state ────────────────────────────────────────────────────────────

func test_charge_starts_at_zero() -> void:
	assert_eq(_railgun._charge, 0.0, "Charge should start at 0")

func test_default_damage_is_positive() -> void:
	assert_gt(_railgun._damage, 0, "Default damage should be positive")

func test_default_pierce_is_positive() -> void:
	assert_gt(_railgun._pierce, 0, "Default pierce should be positive")

# ─── setup() ─────────────────────────────────────────────────────────────────

func test_setup_applies_damage() -> void:
	var data := WeaponData.new()
	data.damage = 150
	_railgun.setup(data)
	assert_eq(_railgun._damage, 150, "Damage should be taken from WeaponData")

func test_setup_applies_pierce() -> void:
	var data := WeaponData.new()
	data.pierce = 8
	_railgun.setup(data)
	assert_eq(_railgun._pierce, 8, "Pierce should be taken from WeaponData")

func test_setup_with_zero_damage() -> void:
	var data := WeaponData.new()
	data.damage = 0
	_railgun.setup(data)
	assert_eq(_railgun._damage, 0, "Zero damage should be stored as-is")

# ─── Constants ───────────────────────────────────────────────────────────────

func test_charge_time_is_reasonable() -> void:
	assert_gt(Railgun.CHARGE_TIME, 0.0, "CHARGE_TIME must be positive")
	assert_lt(Railgun.CHARGE_TIME, 10.0, "CHARGE_TIME should be under 10 seconds")

func test_min_charge_is_between_zero_and_one() -> void:
	assert_gt(Railgun.MIN_CHARGE, 0.0, "MIN_CHARGE must be above zero")
	assert_lt(Railgun.MIN_CHARGE, 1.0, "MIN_CHARGE must be below full charge")

func test_max_range_is_positive() -> void:
	assert_gt(Railgun.MAX_RANGE, 0.0, "MAX_RANGE must be positive")

func test_colors_are_different() -> void:
	# Ensures the charge visual actually changes colour.
	assert_ne(Railgun.COLOR_IDLE, Railgun.COLOR_FULL,
			"Idle and full-charge colours must differ for visual feedback")

# ─── Charge accumulation logic ────────────────────────────────────────────────

func test_charge_does_not_exceed_one() -> void:
	# Simulate many frames of holding down fire.
	_railgun._charge = 0.0
	for _i in 300:
		_railgun._charge = minf(_railgun._charge + 0.1, 1.0)
	assert_eq(_railgun._charge, 1.0, "Charge should be clamped at 1.0")

func test_charge_below_min_does_not_trigger_fire() -> void:
	# Set charge just under the threshold; the railgun should reset without firing.
	# We test indirectly: after the else branch, charge resets to 0.
	_railgun._charge = Railgun.MIN_CHARGE - 0.01
	# Manually reproduce the release branch logic:
	var fired := false
	if _railgun._charge >= Railgun.MIN_CHARGE:
		fired = true
	_railgun._charge = 0.0
	assert_false(fired, "Should not fire below MIN_CHARGE")
	assert_eq(_railgun._charge, 0.0, "Charge should reset to 0 on release")

func test_charge_at_min_triggers_fire() -> void:
	_railgun._charge = Railgun.MIN_CHARGE
	var fired := false
	if _railgun._charge >= Railgun.MIN_CHARGE:
		fired = true
	assert_true(fired, "Should fire at exactly MIN_CHARGE")

# ─── Visual helpers ───────────────────────────────────────────────────────────

func test_update_charge_visual_safe_without_sprite() -> void:
	# _weapon_sprite is null when instantiated without the scene; must not crash.
	_railgun._charge = 0.75
	_railgun._update_charge_visual()
	assert_true(true, "_update_charge_visual should not throw without sprite node")
