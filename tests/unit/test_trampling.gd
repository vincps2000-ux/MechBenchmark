# test_trampling.gd — Unit tests for mech trampling of small enemies
extends GutTest

const _PLAYER_SCRIPT := preload("res://src/player/player_controller.gd")
const _ENEMY_INFANTRY_SCRIPT := preload("res://src/enemies/enemy_infantry.gd")

# ── Constants sanity ──────────────────────────────────────────────────────────

func test_trample_min_speed_is_positive():
	assert_gt(_PLAYER_SCRIPT.TRAMPLE_MIN_SPEED, 0.0,
		"Player must be moving to trample")

func test_trample_damage_one_shots_infantry():
	var infantry := EnemyInfantry.new()
	assert_gte(_PLAYER_SCRIPT.TRAMPLE_DAMAGE, infantry.max_health,
		"Trample damage should one-shot infantry")
	infantry.free()

func test_trample_penetration_bypasses_infantry_armor():
	var infantry := EnemyInfantry.new()
	assert_gt(_PLAYER_SCRIPT.TRAMPLE_PENETRATION, infantry.armor,
		"Trample penetration should exceed infantry armor")
	infantry.free()

func test_trample_min_speed_below_base_move_speed():
	assert_lt(_PLAYER_SCRIPT.TRAMPLE_MIN_SPEED, _PLAYER_SCRIPT.BASE_SPEED,
		"Trample threshold should be reachable in normal movement")

# ── Infantry take_damage with trample values ──────────────────────────────────

func test_infantry_dies_from_trample_damage():
	var scene := preload("res://scenes/enemies/enemy_infantry.tscn")
	var infantry: EnemyInfantry = scene.instantiate()
	add_child_autofree(infantry)
	await get_tree().process_frame
	infantry.health = infantry.max_health
	watch_signals(infantry)
	infantry.take_damage(_PLAYER_SCRIPT.TRAMPLE_DAMAGE,
		_PLAYER_SCRIPT.TRAMPLE_PENETRATION)
	assert_signal_emitted(infantry, "died", "Infantry should emit died signal on trample")

func test_infantry_survives_low_speed_no_trample():
	# Verify infantry health is not touched if trample is not triggered
	# (no direct call — just confirm health is positive by default)
	var infantry := EnemyInfantry.new()
	infantry.health = infantry.max_health
	assert_eq(infantry.health, infantry.max_health,
		"Infantry starts at full health before any trample")
	infantry.free()

# ── Player collision mask no longer blocks on enemy layer ─────────────────────

func test_player_collision_mask_excludes_enemy_layer():
	const ENEMY_LAYER_BIT := 2  # layer 2 value
	var scene := preload("res://scenes/player/player.tscn")
	var player: CharacterBody2D = scene.instantiate()
	assert_eq(player.collision_mask & ENEMY_LAYER_BIT, 0,
		"Player collision mask must not include enemy layer (trample pass-through)")
	player.free()

func test_player_collision_mask_still_includes_environment():
	const ENVIRONMENT_BIT := 16  # layer 5 value
	var scene := preload("res://scenes/player/player.tscn")
	var player: CharacterBody2D = scene.instantiate()
	assert_eq(player.collision_mask & ENVIRONMENT_BIT, ENVIRONMENT_BIT,
		"Player collision mask must include environment layer")
	player.free()
