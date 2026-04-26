# test_freeze_effect.gd — Unit tests for the cryo freeze system.
extends GutTest

const FreezeEffect = preload("res://src/enemies/freeze_effect.gd")
const _INFANTRY_SCENE := preload("res://scenes/enemies/enemy_infantry.tscn")

# ── FreezeEffect standalone tests ─────────────────────────────────────────────

func test_freeze_effect_is_cpu_particles() -> void:
	var fx = FreezeEffect.new()
	add_child_autofree(fx)
	assert_true(fx is CPUParticles2D, "FreezeEffect should extend CPUParticles2D")


func test_freeze_effect_default_duration() -> void:
	var fx = FreezeEffect.new()
	add_child_autofree(fx)
	assert_eq(fx.duration, 10.0, "Default freeze duration should be 10 seconds")


func test_freeze_effect_emits_on_ready() -> void:
	var fx = FreezeEffect.new()
	add_child_autofree(fx)
	assert_true(fx.emitting, "FreezeEffect should be emitting after _ready")


func test_freeze_effect_sets_frozen_on_parent() -> void:
	var host := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(host)

	var fx = FreezeEffect.new()
	host.add_child(fx)

	assert_true(host._is_frozen, "FreezeEffect should set _is_frozen = true on parent")


func test_freeze_effect_clears_frozen_on_expiry() -> void:
	var host := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(host)

	var fx = FreezeEffect.new()
	fx.duration = 0.0
	host.add_child(fx)

	fx._process(0.01)  # timer >= duration immediately

	assert_false(host._is_frozen, "FreezeEffect should clear _is_frozen on expiry")


func test_freeze_effect_queued_for_deletion_after_expiry() -> void:
	var host := Node2D.new()
	host.set("_is_frozen", false)
	add_child_autofree(host)

	var fx = FreezeEffect.new()
	fx.duration = 0.0
	host.add_child(fx)

	fx._process(0.01)

	assert_true(fx.is_queued_for_deletion(), "FreezeEffect should queue_free after expiry")


# ── EnemyInfantry apply_freeze tests ─────────────────────────────────────────

func test_apply_freeze_sets_is_frozen() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)

	infantry.apply_freeze()

	assert_true(infantry._is_frozen, "Infantry should be frozen after apply_freeze")


func test_apply_freeze_defaults_to_ten_seconds() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)

	infantry.apply_freeze()

	var fx = null
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("freeze_effect.gd"):
			fx = child
			break

	assert_not_null(fx, "FreezeEffect child should exist")
	assert_eq(fx.duration, 10.0, "apply_freeze should default to 10 seconds")


func test_apply_freeze_does_not_stack() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)

	infantry.apply_freeze(2.0)
	infantry.apply_freeze(2.0)

	var count := 0
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("freeze_effect.gd"):
			count += 1
	assert_eq(count, 1, "apply_freeze should not stack: only one FreezeEffect allowed")


func test_apply_freeze_refresh_resets_timer_without_extending_duration() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)

	infantry.apply_freeze(10.0)

	var fx = null
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("freeze_effect.gd"):
			fx = child
			break

	assert_not_null(fx, "FreezeEffect child should exist")
	fx._timer = 6.0
	fx.duration = 10.0

	infantry.apply_freeze(10.0)

	assert_eq(fx._timer, 0.0, "Reapplying freeze should reset the timer")
	assert_eq(fx.duration, 10.0, "Reapplying freeze should not accumulate extra duration")


func test_infantry_unfreezes_after_duration() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)

	infantry.apply_freeze(1.0)
	assert_true(infantry._is_frozen, "Infantry should be frozen immediately")

	var fx = null
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("freeze_effect.gd"):
			fx = child
			break

	assert_not_null(fx, "FreezeEffect child should exist")
	# Simulate enough time passing to expire
	fx._process(1.5)

	assert_false(infantry._is_frozen, "Infantry should be unfrozen after duration expires")
