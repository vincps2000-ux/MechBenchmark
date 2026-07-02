# test_artillery.gd — Unit tests for the Artillery weapon, strike marker and
# targeting reticle using GUT.
extends GutTest

var _artillery: Artillery

func before_each() -> void:
	_artillery = Artillery.new()
	add_child_autofree(_artillery)

func after_each() -> void:
	# Clean up any strike markers spawned during firing tests so they do not
	# leak into subsequent tests.
	for strike in get_tree().get_nodes_in_group("artillery_strike"):
		strike.free()

# ─── Magazine / ammo ──────────────────────────────────────────────────────────

func test_magazine_holds_five_shells() -> void:
	assert_eq(Artillery.MAX_AMMO, 5, "Artillery magazine should hold 5 shells")

func test_starts_with_full_magazine() -> void:
	assert_eq(_artillery.get_ammo_count(), 5, "Should start fully loaded")

func test_capacity_matches_max_ammo() -> void:
	assert_eq(_artillery.get_ammo_capacity(), Artillery.MAX_AMMO,
			"Capacity should equal MAX_AMMO")

func test_has_ammo_true_when_loaded() -> void:
	assert_true(_artillery.has_ammo(), "Freshly built gun should report ammo")

func test_is_out_of_ammo_when_empty() -> void:
	_artillery._ammo_current = 0
	assert_true(_artillery.is_out_of_ammo(), "Empty gun should be out of ammo")
	assert_false(_artillery.has_ammo(), "Empty gun should not report ammo")

# ─── setup() ─────────────────────────────────────────────────────────────────

func test_setup_applies_damage() -> void:
	var data := WeaponData.new()
	data.damage = 200
	_artillery.setup(data)
	assert_eq(_artillery._damage, 200, "Damage should come from WeaponData")

func test_setup_applies_penetration() -> void:
	var data := WeaponData.new()
	data.penetration = 12
	_artillery.setup(data)
	assert_eq(_artillery._penetration, 12, "Penetration should come from WeaponData")

func test_setup_scales_blast_radius_with_area() -> void:
	var data := WeaponData.new()
	data.area = 2.0
	_artillery.setup(data)
	assert_eq(_artillery._blast_radius, Artillery.BLAST_RADIUS * 2.0,
			"Area multiplier should scale blast radius")

func test_setup_reloads_magazine() -> void:
	_artillery._ammo_current = 1
	_artillery.setup(WeaponData.new())
	assert_eq(_artillery.get_ammo_count(), 5, "setup() should refill the magazine")

func test_setup_scales_scatter_radius_with_area() -> void:
	var data := WeaponData.new()
	data.area = 2.0
	_artillery.setup(data)
	assert_eq(_artillery._scatter_radius, Artillery.SCATTER_RADIUS * 2.0,
			"Area multiplier should scale the scatter radius too")

# ─── Impact scatter ───────────────────────────────────────────────────────────

func test_scatter_offset_stays_within_radius() -> void:
	for _i in 50:
		var offset := _artillery.random_scatter_offset()
		assert_lte(offset.length(), Artillery.SCATTER_RADIUS + 0.01,
				"Scattered impact must land inside the scatter radius")

func test_scatter_offset_zero_when_radius_zero() -> void:
	_artillery._scatter_radius = 0.0
	assert_eq(_artillery.random_scatter_offset(), Vector2.ZERO,
			"No scatter radius means shells land dead-centre")

func test_scatter_is_smaller_than_blast() -> void:
	assert_lt(Artillery.SCATTER_RADIUS, Artillery.BLAST_RADIUS,
			"Scatter must stay within the visible aim circle")

# ─── Firing ──────────────────────────────────────────────────────────────────

func test_fire_at_consumes_one_shell() -> void:
	var before := _artillery.get_ammo_count()
	var fired := _artillery.fire_at(Vector2(500, 0))
	assert_true(fired, "Should fire when loaded and off cooldown")
	assert_eq(_artillery.get_ammo_count(), before - 1, "Firing should spend one shell")

func test_fire_at_sets_cooldown() -> void:
	_artillery.fire_at(Vector2(500, 0))
	assert_gt(_artillery._cooldown, 0.0, "Firing should start the reload cooldown")

func test_fire_at_blocked_during_cooldown() -> void:
	_artillery.fire_at(Vector2(500, 0))
	var after_first := _artillery.get_ammo_count()
	var second := _artillery.fire_at(Vector2(500, 0))
	assert_false(second, "Cannot fire again while cooling down")
	assert_eq(_artillery.get_ammo_count(), after_first,
			"Blocked shot should not spend ammo")

func test_fire_at_blocked_when_empty() -> void:
	_artillery._ammo_current = 0
	assert_false(_artillery.fire_at(Vector2(500, 0)),
			"Cannot fire with an empty magazine")

func test_fire_at_spawns_strike() -> void:
	_artillery.fire_at(Vector2(500, 0))
	var strikes := get_tree().get_nodes_in_group("artillery_strike")
	assert_eq(strikes.size(), 1, "Firing should spawn one artillery strike")

# ─── Alignment gating ─────────────────────────────────────────────────────────

func test_not_aligned_when_target_too_close() -> void:
	# A target on top of the gun must never be considered aligned.
	assert_false(_artillery.is_aligned_to(_artillery.global_position),
			"Target on the muzzle should not be aligned")

func test_aligned_when_target_in_front() -> void:
	# The gun's default transform points along +X, so a target far to the right
	# is within the alignment cone.
	assert_true(_artillery.is_aligned_to(_artillery.global_position + Vector2(400, 0)),
			"Target straight ahead should be aligned")

func test_not_aligned_when_target_behind() -> void:
	assert_false(_artillery.is_aligned_to(_artillery.global_position + Vector2(-400, 0)),
			"Target directly behind should not be aligned")

# ─── Fire-state machine ───────────────────────────────────────────────────────

func test_state_no_ammo_when_empty() -> void:
	_artillery._ammo_current = 0
	assert_eq(_artillery.compute_fire_state(), Artillery.FireState.NO_AMMO,
			"Empty gun should report NO_AMMO")

func test_state_cooldown_after_firing() -> void:
	_artillery.fire_at(Vector2(400, 0))
	assert_eq(_artillery.compute_fire_state(), Artillery.FireState.COOLDOWN,
			"Gun should report COOLDOWN right after firing")

func test_state_colors_are_distinct() -> void:
	var ready := _artillery.state_color(Artillery.FireState.READY)
	var misaligned := _artillery.state_color(Artillery.FireState.MISALIGNED)
	var cooldown := _artillery.state_color(Artillery.FireState.COOLDOWN)
	var empty := _artillery.state_color(Artillery.FireState.NO_AMMO)
	assert_ne(ready, misaligned, "Ready and misaligned colours must differ")
	assert_ne(ready, cooldown, "Ready and cooldown colours must differ")
	assert_ne(ready, empty, "Ready and empty colours must differ")

func test_ready_color_is_green() -> void:
	var ready := _artillery.state_color(Artillery.FireState.READY)
	assert_gt(ready.g, ready.r, "Ready reticle should read as green")
	assert_gt(ready.g, ready.b, "Ready reticle should read as green")

# ─── Constants / spec ─────────────────────────────────────────────────────────

func test_alignment_tolerance_is_positive_and_tight() -> void:
	assert_gt(Artillery.ALIGNMENT_TOLERANCE, 0.0, "Tolerance must be positive")
	assert_lt(Artillery.ALIGNMENT_TOLERANCE, deg_to_rad(45.0),
			"Tolerance should be a tight cone, not a wide arc")

func test_blast_radius_is_large() -> void:
	assert_true(Artillery.BLAST_RADIUS >= 100.0,
			"Artillery should produce a big blast footprint")

func test_fill_time_is_positive() -> void:
	assert_gt(Artillery.FILL_TIME, 0.0, "Fill telegraph must take time")


# ─── ArtilleryStrike ──────────────────────────────────────────────────────────

func test_strike_fill_ratio_starts_at_zero() -> void:
	var strike := ArtilleryStrike.new()
	add_child_autofree(strike)
	assert_eq(strike.get_fill_ratio(), 0.0, "Fresh strike should be 0% filled")

func test_strike_fill_ratio_progresses() -> void:
	var strike := ArtilleryStrike.new()
	strike.fill_time = 2.0
	add_child_autofree(strike)
	strike._process(1.0)
	assert_almost_eq(strike.get_fill_ratio(), 0.5, 0.01,
			"Halfway through fill_time should be ~50%")

func test_strike_fill_ratio_clamped_to_one() -> void:
	var strike := ArtilleryStrike.new()
	strike.fill_time = 1.0
	add_child_autofree(strike)
	strike._process(0.5)
	assert_almost_eq(strike.get_fill_ratio(), 0.5, 0.01, "Should report 50%")
	# Free immediately so the detonation branch is not exercised here.

func test_strike_detonates_after_fill() -> void:
	var strike := ArtilleryStrike.new()
	strike.fill_time = 0.2
	strike.damage = 99
	get_tree().root.add_child(strike)
	strike._process(0.5)  # exceeds fill_time -> should detonate & free itself
	assert_true(strike.is_queued_for_deletion(),
			"Strike should free itself once it detonates")
	# Remove any explosion spawned by the detonation.
	for fx in get_tree().get_nodes_in_group("level_effect"):
		if fx != strike:
			fx.free()


# ─── ArtilleryTargeter ────────────────────────────────────────────────────────

func test_targeter_configure_updates_radius_and_color() -> void:
	var targeter := ArtilleryTargeter.new()
	add_child_autofree(targeter)
	targeter.configure(123.0, Color.RED, 40.0)
	assert_eq(targeter._radius, 123.0, "configure() should store the radius")
	assert_eq(targeter._color, Color.RED, "configure() should store the colour")
	assert_eq(targeter._scatter_radius, 40.0, "configure() should store the scatter radius")
