# tests/unit/test_level1_urban.gd — Unit tests for Level 1 "Urban Surprise" constants & config
extends GutTest

# Test the level_1 script constants without loading the full scene
# (avoids needing the scene tree with player, HUD, etc.)

func test_wave_counts_match_total_waves():
	# WAVE_ENEMY_COUNTS should have an entry for each wave
	var script := load("res://src/levels/level_1.gd")
	assert_not_null(script, "level_1.gd should load")
	# We can verify via the constants
	assert_eq(script.TOTAL_WAVES, 3, "Should have 3 waves")
	assert_eq(script.WAVE_ENEMY_COUNTS.size(), 3, "WAVE_ENEMY_COUNTS should have 3 entries")

func test_wave_enemy_counts_escalate():
	var script := load("res://src/levels/level_1.gd")
	var counts: Array[int] = script.WAVE_ENEMY_COUNTS
	for i in range(1, counts.size()):
		assert_gt(counts[i], counts[i - 1], "Wave %d should have more enemies than wave %d" % [i + 1, i])

func test_spawn_directions_match_total_waves():
	var script := load("res://src/levels/level_1.gd")
	assert_eq(script.WAVE_SPAWN_DIRS.size(), 3, "WAVE_SPAWN_DIRS should have 3 entries")

func test_arena_half_size():
	var script := load("res://src/levels/level_1.gd")
	assert_eq(script.ARENA_HALF_SIZE, 1200.0, "Arena half size should be 1200")

func test_obstacle_defs_valid():
	var script := load("res://src/levels/level_1.gd")
	var defs: Array = script.OBSTACLE_DEFS
	assert_gt(defs.size(), 0, "Should have obstacle definitions")
	# Each def should be [Vector2, int, Vector2, float]
	for i in defs.size():
		var d: Array = defs[i]
		assert_eq(d.size(), 4, "Obstacle def %d should have 4 elements" % i)
		assert_true(d[0] is Vector2, "Element 0 should be Vector2 (position)")
		assert_true(d[1] is int or d[1] is float, "Element 1 should be number (shape type)")
		assert_true(d[3] is float or d[3] is int, "Element 3 should be number (rotation)")

func test_xp_per_kill():
	var script := load("res://src/levels/level_1.gd")
	assert_eq(script.XP_PER_KILL, 5, "XP per kill should be 5")

func test_wave_delay():
	var script := load("res://src/levels/level_1.gd")
	assert_eq(script.WAVE_DELAY, 3.0, "Wave delay should be 3.0 seconds")

func test_total_enemies_across_all_waves():
	var script := load("res://src/levels/level_1.gd")
	var total := 0
	for c in script.WAVE_ENEMY_COUNTS:
		total += c
	assert_eq(total, 20, "Total enemies across all waves should be 20 (4+6+10)")

func test_obstacle_types_include_urban_elements():
	# Verify we have buildings (0), cars (1), dumpsters (2), barricades (3)
	var script := load("res://src/levels/level_1.gd")
	var types_found := {}
	for d in script.OBSTACLE_DEFS:
		types_found[d[1]] = true
	assert_true(types_found.has(0), "Should have BUILDING obstacles")
	assert_true(types_found.has(1), "Should have CAR obstacles")
	assert_true(types_found.has(2), "Should have DUMPSTER obstacles")
	assert_true(types_found.has(3), "Should have BARRICADE obstacles")
	assert_true(types_found.has(5), "Should have LAMPPOST obstacles")
