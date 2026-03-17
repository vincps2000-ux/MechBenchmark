# test_enemy_data.gd — Unit tests for EnemyData using GUT
extends GutTest

var enemy: EnemyData

func before_each():
	enemy = EnemyData.new()
	enemy.name = "Test Zombie"
	enemy.max_health = 20
	enemy.health = 20
	enemy.xp_reward = 5

func test_initial_health():
	assert_eq(enemy.health, 20)

func test_take_damage():
	enemy.take_damage(8)
	assert_eq(enemy.health, 12)

func test_take_damage_does_not_go_below_zero():
	enemy.take_damage(999)
	assert_eq(enemy.health, 0)

func test_is_dead():
	enemy.take_damage(20)
	assert_true(enemy.is_dead())

func test_is_not_dead():
	enemy.take_damage(19)
	assert_false(enemy.is_dead())

func test_reset():
	enemy.take_damage(15)
	enemy.reset()
	assert_eq(enemy.health, enemy.max_health, "Reset should restore full health")
