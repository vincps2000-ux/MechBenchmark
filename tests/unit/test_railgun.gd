extends GutTest

const _RAILGUN_SCRIPT := preload("res://src/weapons/railgun.gd")

func test_railgun_range_is_effectively_unbounded() -> void:
	var railgun = _RAILGUN_SCRIPT.new()
	add_child_autofree(railgun)

	assert_gt(railgun.get_max_range(), 100000.0,
		"Railgun should not stop at a short gameplay range cap")