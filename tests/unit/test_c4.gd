# test_c4.gd — Unit tests for the C4 Launcher light weapon using GUT.
extends GutTest

var _launcher: C4Launcher

func before_each() -> void:
	_launcher = C4Launcher.new()
	add_child_autofree(_launcher)

func after_each() -> void:
	# Charges/explosions are spawned under the tree root by the launcher —
	# remove them so they cannot pollute other test suites.
	var leftovers: Array = []
	for node in get_tree().root.get_children():
		if node is C4Charge or node is AutocannonExplosion:
			leftovers.append(node)
	for node in leftovers:
		node.free()

# ─── Initial state ───────────────────────────────────────────────────────────

func test_starts_with_five_charges() -> void:
	assert_eq(_launcher.get_ammo_count(), 5, "C4 carries exactly 5 charges")
	assert_eq(_launcher.get_ammo_capacity(), 5)

func test_default_blast_is_huge() -> void:
	assert_gt(_launcher._aoe_scale, 2.0, "C4 blast should be huge")

func test_no_charges_placed_initially() -> void:
	assert_eq(_launcher.get_placed_charge_count(), 0)

# ─── setup() ─────────────────────────────────────────────────────────────────

func test_setup_applies_weapon_data() -> void:
	var data := WeaponData.new()
	data.damage = 150
	data.penetration = 12
	data.cooldown = 0.5
	data.area = 3.5
	data.projectile_speed = 300.0
	_launcher.setup(data)
	assert_eq(_launcher._damage, 150)
	assert_eq(_launcher._penetration, 12)
	assert_eq(_launcher._throw_interval, 0.5)
	assert_eq(_launcher._aoe_scale, 3.5)
	assert_eq(_launcher._projectile_speed, 300.0)

func test_setup_refills_ammo_to_five() -> void:
	_launcher._ammo_current = 1
	_launcher.setup(WeaponData.new())
	assert_eq(_launcher.get_ammo_count(), 5)

# ─── Throwing ────────────────────────────────────────────────────────────────

func test_throw_consumes_one_charge() -> void:
	var thrown := _launcher.try_throw_once()
	assert_true(thrown, "Should throw when charges remain")
	assert_eq(_launcher.get_ammo_count(), 4)

func test_throw_places_a_live_charge() -> void:
	_launcher.try_throw_once()
	assert_eq(_launcher.get_placed_charge_count(), 1)

func test_throw_starts_cooldown() -> void:
	_launcher.try_throw_once()
	assert_gt(_launcher._cooldown, 0.0)
	assert_false(_launcher.can_throw(), "Cannot throw again immediately")

func test_cannot_throw_beyond_five_charges() -> void:
	for i in 5:
		_launcher._cooldown = 0.0
		_launcher.try_throw_once()
	assert_true(_launcher.is_out_of_ammo())
	_launcher._cooldown = 0.0
	assert_false(_launcher.try_throw_once(), "Sixth throw must fail")

# ─── Manual detonation ───────────────────────────────────────────────────────

func test_detonate_all_fires_every_placed_charge() -> void:
	for i in 3:
		_launcher._cooldown = 0.0
		_launcher.try_throw_once()
	var detonated := _launcher.detonate_all()
	assert_eq(detonated, 3, "All placed charges should detonate")
	assert_eq(_launcher.get_placed_charge_count(), 0, "Placed list is cleared")

func test_detonate_all_with_no_charges_is_safe() -> void:
	assert_eq(_launcher.detonate_all(), 0)

func test_hold_time_threshold_exists() -> void:
	assert_gt(C4Launcher.HOLD_DETONATE_TIME, 0.0,
			"Detonation requires deliberately holding the trigger")

# ─── Charge ──────────────────────────────────────────────────────────────────

func test_charge_defaults() -> void:
	var charge := C4Charge.new()
	autofree(charge)
	assert_gt(charge.damage, 0)
	assert_gt(charge.aoe_scale, 2.0, "Charge blast should be huge")
	assert_true(charge.is_armed(), "Charge starts armed")

func test_charge_skids_to_a_stop() -> void:
	var charge := C4Charge.new()
	add_child_autofree(charge)
	charge.velocity = Vector2(260.0, 0.0)
	for i in 60:
		charge._physics_process(1.0 / 30.0)
	assert_eq(charge.velocity, Vector2.ZERO, "Charge should stop moving")
	assert_true(charge._stuck, "Charge should be stuck in place")

func test_charge_never_explodes_on_its_own() -> void:
	var charge := C4Charge.new()
	add_child_autofree(charge)
	charge.velocity = Vector2.ZERO
	for i in 120:
		charge._physics_process(1.0 / 30.0)
	assert_false(charge.is_queued_for_deletion(),
			"Charge must wait for manual detonation, not a fuse")

func test_charge_detonates_only_once() -> void:
	var charge := C4Charge.new()
	add_child_autofree(charge)
	charge.detonate()
	assert_false(charge.is_armed(), "Charge is spent after detonating")

# ─── Catalog ─────────────────────────────────────────────────────────────────

func test_catalog_has_c4_light_gun() -> void:
	var g := MechCatalog.get_gun_by_id("c4_charges")
	assert_not_null(g, "C4 Charges should exist in catalog")
	assert_eq(g.weapon_type, WeaponData.WeaponType.C4)
	assert_eq(g.slot_size, WeaponData.SlotSize.LIGHT)
	assert_gt(g.area, 2.0, "Catalog C4 should have a huge blast area")
