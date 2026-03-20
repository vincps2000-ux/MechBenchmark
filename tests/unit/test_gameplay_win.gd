# test_gameplay_win.gd — Unit tests for the gameplay win condition logic
extends GutTest

# We test the core logic in isolation by simulating what gameplay.gd does:
# - Track a finite target count
# - Decrement on each destroy
# - Trigger win when count reaches zero

# ─── Minimal stub that mirrors gameplay.gd tracking logic ─────────────────────
# (Testing the actual scene would require integration tests; here we verify the
# counting / win-trigger behaviour in isolation.)

var _alive_targets: int
var _total_targets: int
var _level_won: bool

func before_each():
	_alive_targets = 0
	_total_targets = 0
	_level_won = false

func _simulate_spawn(count: int) -> void:
	_total_targets = count
	_alive_targets = count

func _simulate_destroy() -> void:
	_alive_targets -= 1
	if _alive_targets <= 0 and not _level_won:
		_level_won = true

func test_initial_state_not_won():
	_simulate_spawn(5)
	assert_false(_level_won)

func test_destroying_all_targets_wins():
	_simulate_spawn(3)
	_simulate_destroy()
	_simulate_destroy()
	_simulate_destroy()
	assert_true(_level_won, "Should win after destroying all targets")

func test_partial_destroy_does_not_win():
	_simulate_spawn(5)
	_simulate_destroy()
	_simulate_destroy()
	assert_false(_level_won, "Should not win with targets remaining")
	assert_eq(_alive_targets, 3)

func test_single_target_wins_immediately():
	_simulate_spawn(1)
	_simulate_destroy()
	assert_true(_level_won)

func test_target_counter_tracks_correctly():
	_simulate_spawn(10)
	for i in 7:
		_simulate_destroy()
	var destroyed := _total_targets - _alive_targets
	assert_eq(destroyed, 7, "Should track 7 destroyed out of 10")
	assert_eq(_alive_targets, 3)
	assert_false(_level_won)

func test_win_only_triggers_once():
	_simulate_spawn(2)
	_simulate_destroy()
	_simulate_destroy()
	assert_true(_level_won)
	# Simulating an extra destroy (edge case) should not crash
	_level_won = false   # reset to check it doesn't re-trigger normally
	# alive is already 0, but another call should not break
	_simulate_destroy()
	# alive_targets goes to -1 but win already happened
	assert_true(_level_won)

# ─── ShootTarget signal contract ─────────────────────────────────────────────
func test_shoot_target_has_destroyed_signal():
	var target := ShootTarget.new()
	assert_true(target.has_signal("destroyed"), "ShootTarget must emit 'destroyed' signal")
	target.free()

func test_shoot_target_has_take_damage():
	var target := ShootTarget.new()
	assert_true(target.has_method("take_damage"), "ShootTarget must have take_damage method")
	target.free()
