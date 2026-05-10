# test_enemy_damage_system.gd — Unit tests for enemy damage to player/mech death handling.
extends GutTest

func before_each() -> void:
	_clear_autocannon_explosions()

func after_each() -> void:
	_clear_autocannon_explosions()

func test_apply_to_player_lethal_hit_spawns_explosion_and_removes_mech() -> void:
	var stats := PlayerStats.new()
	stats.max_health = 30
	stats.health = 1
	stats.armor = 0
	GameManager.player_stats = stats
	GameManager.is_running = true

	var mech := Node2D.new()
	mech.add_to_group("player")
	add_child_autofree(mech)
	mech.global_position = Vector2(123, 45)

	var before := _count_autocannon_explosions()
	var applied := EnemyDamageSystem.apply_to_player(10, 99, mech)
	await get_tree().process_frame

	assert_true(applied, "Lethal damage should be applied")
	assert_true(stats.is_dead(), "Player stats should be dead at 0 health")
	assert_false(GameManager.is_running, "Game should stop when the player dies")
	assert_false(is_instance_valid(mech), "Player mech should be removed after death")
	assert_eq(_count_autocannon_explosions(), before + 1, "A death explosion should be spawned exactly once")
	_clear_autocannon_explosions()


func test_apply_to_player_dead_player_does_not_spawn_extra_explosions() -> void:
	var stats := PlayerStats.new()
	stats.max_health = 30
	stats.health = 1
	stats.armor = 0
	GameManager.player_stats = stats
	GameManager.is_running = true

	var mech := Node2D.new()
	mech.add_to_group("player")
	add_child_autofree(mech)

	var before := _count_autocannon_explosions()
	var first_applied := EnemyDamageSystem.apply_to_player(10, 99, mech)
	var second_applied := EnemyDamageSystem.apply_to_player(10, 99, mech)
	await get_tree().process_frame

	assert_true(first_applied, "First lethal hit should apply")
	assert_false(second_applied, "No additional damage should apply after death")
	assert_eq(_count_autocannon_explosions(), before + 1, "Only one death explosion should be spawned")
	_clear_autocannon_explosions()


func test_apply_to_player_lethal_hit_detaches_and_locks_camera() -> void:
	var stats := PlayerStats.new()
	stats.max_health = 30
	stats.health = 1
	stats.armor = 0
	GameManager.player_stats = stats
	GameManager.is_running = true

	var mech := Node2D.new()
	mech.add_to_group("player")
	add_child_autofree(mech)
	mech.global_position = Vector2(222, -88)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	mech.add_child(cam)

	EnemyDamageSystem.apply_to_player(10, 99, mech)

	var tree := get_tree()
	var expected_parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	assert_true(cam.get_parent() == expected_parent, "Death camera should be detached to active scene parent")
	assert_eq(cam.global_position, Vector2(222, -88), "Death camera should stay on mech death position")
	assert_true(cam.is_current(), "Death camera should remain current")


func _count_autocannon_explosions() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path.ends_with("autocannon_explosion.gd"):
			count += 1
	return count

func _clear_autocannon_explosions() -> void:
	for child in get_tree().root.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path.ends_with("autocannon_explosion.gd"):
			child.free()
