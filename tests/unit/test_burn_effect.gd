# test_burn_effect.gd — Unit tests for burning DoT system.
extends GutTest

# Preload avoids dependency on the class-name registry (no .uid yet in headless mode)
const BurnEffect = preload("res://src/enemies/burn_effect.gd")
const _INFANTRY_SCENE := preload("res://scenes/enemies/enemy_infantry.tscn")

# ── BurnEffect standalone tests ───────────────────────────────────────────────

func test_burn_effect_is_cpu_particles() -> void:
	var burn = BurnEffect.new()
	add_child_autofree(burn)
	assert_true(burn is CPUParticles2D, "BurnEffect should extend CPUParticles2D")


func test_burn_effect_defaults() -> void:
	var burn = BurnEffect.new()
	add_child_autofree(burn)
	assert_eq(burn.tick_damage, 4, "Default tick_damage should be 4")
	assert_eq(burn.ticks_remaining, 2, "Default ticks_remaining should be 2")


func test_burn_effect_emits_particles_on_ready() -> void:
	var burn = BurnEffect.new()
	add_child_autofree(burn)
	assert_true(burn.emitting, "Burn effect should be emitting after _ready")


func test_burn_effect_decrements_ticks_on_process() -> void:
	var host := Node2D.new()
	add_child_autofree(host)

	var burn = BurnEffect.new()
	burn.tick_damage = 4
	burn.ticks_remaining = 2
	burn.tick_interval = 0.0   # zero interval = fires every frame
	host.add_child(burn)

	var before: int = burn.ticks_remaining
	burn._process(0.01)
	assert_eq(burn.ticks_remaining, before - 1, "ticks_remaining should decrement each tick")


func test_burn_effect_removes_self_after_all_ticks() -> void:
	var host := Node2D.new()
	add_child_autofree(host)

	var burn = BurnEffect.new()
	burn.ticks_remaining = 1
	burn.tick_interval = 0.0
	host.add_child(burn)

	burn._process(0.01)
	# queue_free is called but node isn't freed until next frame; check the queued flag
	assert_true(burn.is_queued_for_deletion(), "BurnEffect should be queued for deletion after last tick")


# ── EnemyInfantry apply_burn tests ───────────────────────────────────────────

func test_apply_burn_adds_burn_effect_child() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)

	infantry.apply_burn()

	var found := false
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("burn_effect.gd"):
			found = true
			break
	assert_true(found, "apply_burn should add a BurnEffect child to infantry")


func test_apply_burn_refreshes_existing_instead_of_stacking() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)

	infantry.apply_burn(2)

	var burn = null
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("burn_effect.gd"):
			burn = child
			break

	assert_not_null(burn, "BurnEffect should be found after first apply_burn")
	burn.ticks_remaining = 1

	infantry.apply_burn(2)  # should refresh, not add a second BurnEffect

	var count := 0
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("burn_effect.gd"):
			count += 1
	assert_eq(count, 1, "apply_burn should not stack: only one BurnEffect allowed")
	assert_eq(burn.ticks_remaining, 2, "ticks_remaining should be refreshed to incoming value")


func test_infantry_dies_in_two_burn_ticks() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)
	infantry.health = infantry.max_health  # 8

	infantry.apply_burn(2, 4)

	var burn = null
	for child in infantry.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("burn_effect.gd"):
			burn = child
			break

	assert_not_null(burn, "BurnEffect should exist after apply_burn")

	# Tick 1 — infantry should survive
	burn.tick_interval = 0.0
	burn._process(0.01)
	assert_true(is_instance_valid(infantry), "Infantry should survive first burn tick")

	# Tick 2 — infantry should die
	if is_instance_valid(burn):
		burn.tick_interval = 0.0
		burn._process(0.01)
	# queue_free defers removal; check queued-for-deletion flag instead of instance validity
	assert_true(infantry.is_queued_for_deletion(), "Infantry should be queued for deletion after second burn tick")


# ── Acid armour-bypass test ───────────────────────────────────────────────────

func test_take_damage_with_max_penetration_bypasses_armor() -> void:
	var infantry := _INFANTRY_SCENE.instantiate() as EnemyInfantry
	add_child_autofree(infantry)
	infantry.health = infantry.max_health  # 8
	infantry.armor = 999  # absurdly high armor — would always deflect normal attacks

	# Acid uses penetration=999 which matches armor, so chance = pow(0.5, 999-999+1) = 0.5
	# Use a penetration just above armor to guarantee penetration
	infantry.take_damage(1, 1000)

	assert_lt(infantry.health, infantry.max_health, "Damage with penetration above armor should always deal damage")
