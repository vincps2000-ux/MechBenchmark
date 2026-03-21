# tests/unit/test_blood_splatter.gd
extends GutTest

var _sut: BloodSplatter

func before_each() -> void:
	_sut = BloodSplatter.new()
	add_child(_sut)

func after_each() -> void:
	if is_instance_valid(_sut) and _sut.is_inside_tree():
		_sut.queue_free()

# ── Defaults ──────────────────────────────────────────────────────────────────

func test_default_linger_time() -> void:
	assert_eq(_sut.linger_time, 3.0, "Default linger time should be 3 seconds")

func test_default_fade_time() -> void:
	assert_eq(_sut.fade_time, 2.0, "Default fade time should be 2 seconds")

# ── Visual properties ────────────────────────────────────────────────────────

func test_z_index_is_negative() -> void:
	assert_lt(_sut.z_index, 0, "Splatter should render below characters")

func test_drops_generated_on_ready() -> void:
	assert_gt(_sut._drops.size(), 0, "Should generate blood drops on ready")

func test_has_central_pool() -> void:
	# First drop is always the central pool, with a larger radius
	var first: Dictionary = _sut._drops[0]
	assert_gt(first["radius"], 4.0, "Central pool should have a large radius")

func test_drops_have_red_colors() -> void:
	for drop: Dictionary in _sut._drops:
		var c: Color = drop["color"]
		assert_gt(c.r, 0.4, "Blood color red channel should be above 0.4")
		assert_lt(c.g, 0.15, "Blood color green channel should be low")
		assert_lt(c.b, 0.15, "Blood color blue channel should be low")

func test_droplet_count_is_at_least_five() -> void:
	# 1 central pool + at least 4 droplets
	assert_gte(_sut._drops.size(), 5, "Should have central pool plus droplets")

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func test_starts_fully_opaque() -> void:
	assert_eq(_sut.modulate.a, 1.0, "Should start fully opaque")

func test_not_fading_initially() -> void:
	assert_false(_sut._fading, "Should not be fading initially")
