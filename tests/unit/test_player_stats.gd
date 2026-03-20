# test_player_stats.gd — Unit tests for PlayerStats using GUT
extends GutTest

var stats: PlayerStats

func before_each():
	stats = PlayerStats.new()

func test_initial_integrity():
	assert_eq(stats.integrity, 4, "Player starts with 4 integrity")

func test_initial_max_integrity():
	assert_eq(stats.max_integrity, 4, "Player starts with 4 max integrity")

func test_initial_level():
	assert_eq(stats.level, 1, "Player starts at level 1")

func test_take_damage():
	stats.take_damage(1)
	assert_eq(stats.integrity, 3, "Integrity should be 3 after taking 1 damage")

func test_take_damage_does_not_go_below_zero():
	stats.take_damage(999)
	assert_eq(stats.integrity, 0, "Integrity should not go below 0")

func test_heal():
	stats.take_damage(2)
	stats.heal(1)
	assert_eq(stats.integrity, 3, "Integrity should be 3 after healing 1 from 2")

func test_heal_does_not_exceed_max():
	stats.take_damage(1)
	stats.heal(999)
	assert_eq(stats.integrity, stats.max_integrity, "Integrity should not exceed max_integrity")

func test_is_dead_when_integrity_zero():
	stats.take_damage(4)
	assert_true(stats.is_dead(), "Player should be dead at 0 integrity")

func test_is_not_dead_when_integrity_above_zero():
	stats.take_damage(3)
	assert_false(stats.is_dead(), "Player should not be dead at 1 integrity")

func test_xp_for_next_level_scales():
	var lvl1_xp = stats.xp_for_next_level()
	stats.level = 5
	var lvl5_xp = stats.xp_for_next_level()
	assert_gt(lvl5_xp, lvl1_xp, "Higher levels should require more XP")

func test_add_experience_levels_up():
	var needed = stats.xp_for_next_level()
	var leveled = stats.add_experience(needed)
	assert_true(leveled, "Should level up when XP reaches threshold")
	assert_eq(stats.level, 2, "Level should be 2 after leveling up")

func test_add_experience_carries_over():
	var needed = stats.xp_for_next_level()
	stats.add_experience(needed + 3)
	assert_eq(stats.experience, 3, "Excess XP should carry over")

func test_add_experience_no_level_up():
	var leveled = stats.add_experience(1)
	assert_false(leveled, "Should not level up with only 1 XP")
	assert_eq(stats.level, 1, "Level should remain 1")
