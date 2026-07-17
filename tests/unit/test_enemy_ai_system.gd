# test_enemy_ai_system.gd — Unit tests for the shared EnemyBase AI system
# and the FPV drone enemy type.
extends GutTest

const INFANTRY_SCENE := preload("res://scenes/enemies/enemy_infantry.tscn")
const TANK_SCENE := preload("res://scenes/enemies/enemy_tank.tscn")
const FPV_DRONE_SCENE := preload("res://scenes/enemies/enemy_fpv_drone.tscn")

func _make_player(pos: Vector2) -> Node2D:
	var player := Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	player.global_position = pos
	return player

# ── Single shared AI system ───────────────────────────────────────────────────

func test_all_enemy_types_use_shared_ai_system() -> void:
	var infantry := INFANTRY_SCENE.instantiate()
	var tank := TANK_SCENE.instantiate()
	var drone := FPV_DRONE_SCENE.instantiate()
	assert_true(infantry is EnemyBase, "Infantry should use the shared EnemyBase AI system")
	assert_true(tank is EnemyBase, "Tank should use the shared EnemyBase AI system")
	assert_true(drone is EnemyBase, "FPV drone should use the shared EnemyBase AI system")
	infantry.free()
	tank.free()
	drone.free()

func test_base_take_damage_reduces_health_and_alerts() -> void:
	_make_player(Vector2(5000, 5000))
	var drone := FPV_DRONE_SCENE.instantiate() as EnemyFpvDrone
	drone.starts_dormant = true
	add_child_autofree(drone)
	await get_tree().process_frame
	assert_false(drone._is_alerted, "Dormant enemy should start unalerted")
	drone.take_damage(1, 10)
	assert_eq(drone.health, drone.max_health - 1, "Damage should reduce health")
	assert_true(drone._is_alerted, "Taking damage should alert the enemy")

func test_base_lethal_damage_emits_died_signal() -> void:
	_make_player(Vector2(5000, 5000))
	var drone := FPV_DRONE_SCENE.instantiate() as EnemyFpvDrone
	add_child_autofree(drone)
	await get_tree().process_frame
	watch_signals(drone)
	drone.take_damage(drone.max_health, 10)
	assert_signal_emitted(drone, "died", "Lethal damage should emit died signal")

func test_base_apply_freeze_freezes_enemy() -> void:
	_make_player(Vector2(5000, 5000))
	var drone := FPV_DRONE_SCENE.instantiate() as EnemyFpvDrone
	add_child_autofree(drone)
	await get_tree().process_frame
	drone.apply_freeze(5.0)
	await get_tree().process_frame
	assert_true(drone._is_frozen, "Freeze effect should freeze any EnemyBase enemy")

func test_base_knockback_temporarily_overrides_enemy_ai_velocity() -> void:
	_make_player(Vector2(5000, 5000))
	var infantry := INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)
	infantry.set_physics_process(false)
	await get_tree().process_frame
	infantry.apply_knockback(Vector2(300.0, 0.0))
	infantry._physics_process(0.016)
	assert_gt(infantry.velocity.x, 0.0, "Knockback should push the enemy away from impact")
	assert_gt(infantry._knockback_timer, 0.0, "Knockback should persist beyond one AI frame")

# ── FPV drone behavior ────────────────────────────────────────────────────────

func test_drone_is_fast_and_fragile() -> void:
	var drone := EnemyFpvDrone.new()
	var infantry := EnemyInfantry.new()
	assert_gt(drone.move_speed, infantry.move_speed, "Drone should be much faster than infantry")
	assert_lt(drone.max_health, infantry.max_health, "Drone should be more fragile than infantry")
	assert_eq(drone.armor, 0, "Drone should have no armor")
	drone.free()
	infantry.free()

func test_drone_flies_over_obstacles() -> void:
	var drone := FPV_DRONE_SCENE.instantiate() as CharacterBody2D
	assert_eq(drone.collision_mask & 16, 0, "Drone must not collide with environment (flies over obstacles)")
	assert_eq(drone.collision_layer, 2, "Drone must be on the enemy layer so player weapons hit it")
	drone.free()

func test_drone_dives_toward_distant_player() -> void:
	var player := _make_player(Vector2(400, 0))
	var drone := FPV_DRONE_SCENE.instantiate() as EnemyFpvDrone
	add_child_autofree(drone)
	drone.set_physics_process(false)
	drone.global_position = Vector2.ZERO
	await get_tree().process_frame

	var handled: bool = drone._behavior_dive_at_player(0.016)
	assert_true(handled, "Dive behavior should handle the frame")
	assert_gt(drone.velocity.x, 0.0, "Drone should move toward the player")
	assert_true(is_instance_valid(drone), "Drone should not detonate at range")
	assert_almost_eq(player.global_position, Vector2(400, 0), Vector2.ONE, "sanity")

func test_drone_detonates_near_player_and_damages_stats() -> void:
	var stats := PlayerStats.new()
	stats.max_health = 100
	stats.health = 100
	stats.armor = 0
	GameManager.player_stats = stats
	GameManager.is_running = true

	var player := _make_player(Vector2(10, 0))
	var drone := FPV_DRONE_SCENE.instantiate() as EnemyFpvDrone
	add_child_autofree(drone)
	drone.set_physics_process(false)
	drone.global_position = Vector2.ZERO
	await get_tree().process_frame

	watch_signals(drone)
	drone._behavior_dive_at_player(0.016)
	assert_eq(stats.health, 100 - drone.explosion_damage, "Detonation should damage the player")
	assert_signal_emitted(drone, "died", "Detonation should emit died so missions update counters")
	assert_true(is_instance_valid(player), "Non-lethal detonation should not remove the player")

func test_drone_detonates_only_once() -> void:
	var stats := PlayerStats.new()
	stats.max_health = 100
	stats.health = 100
	stats.armor = 0
	GameManager.player_stats = stats
	GameManager.is_running = true

	_make_player(Vector2(10, 0))
	var drone := FPV_DRONE_SCENE.instantiate() as EnemyFpvDrone
	add_child_autofree(drone)
	drone.set_physics_process(false)
	drone.global_position = Vector2.ZERO
	await get_tree().process_frame

	drone._detonate()
	drone._detonate()
	assert_eq(stats.health, 100 - drone.explosion_damage, "Repeat detonation must not double-damage")
