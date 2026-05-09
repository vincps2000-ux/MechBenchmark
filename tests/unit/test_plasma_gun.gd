# test_plasma_gun.gd — Unit tests for the Plasma Gun weapon using GUT.
extends GutTest

const _PLASMA_GUN_SCRIPT := preload("res://src/weapons/plasma_gun.gd")
const _PLASMA_PROJECTILE_SCENE := preload("res://scenes/weapons/plasma_projectile.tscn")

var _plasma_gun


func before_each() -> void:
	_plasma_gun = _PLASMA_GUN_SCRIPT.new()
	add_child_autofree(_plasma_gun)


func test_default_damage_is_high() -> void:
	assert_true(_plasma_gun._damage >= 20,
		"Plasma Gun should default to high per-shot damage")


func test_default_penetration_is_medium() -> void:
	assert_true(_plasma_gun._penetration >= 5 and _plasma_gun._penetration < 7,
		"Plasma Gun should sit in the medium penetration band")


func test_setup_applies_projectile_values() -> void:
	var data := WeaponData.new()
	data.weapon_type = WeaponData.WeaponType.PLASMA_GUN
	data.damage = 31
	data.pierce = 3
	data.penetration = 6
	data.projectile_speed = 420.0
	data.projectile_lifetime = 2.8
	_plasma_gun.setup(data)

	assert_eq(_plasma_gun._damage, 31, "Damage should be taken from WeaponData")
	assert_eq(_plasma_gun._pierce, 3, "Pierce should be taken from WeaponData")
	assert_eq(_plasma_gun._penetration, 6, "Penetration should be taken from WeaponData")
	assert_eq(_plasma_gun._projectile_speed, 420.0, "Projectile speed should be configurable")
	assert_eq(_plasma_gun._projectile_lifetime, 2.8, "Projectile lifetime should be configurable")


func test_plasma_has_no_ammo_api() -> void:
	assert_false(_plasma_gun.has_method("get_ammo_count"),
		"Plasma Gun should not expose ammo count methods")
	assert_false(_plasma_gun.has_method("get_ammo_capacity"),
		"Plasma Gun should not expose ammo capacity methods")
	assert_false(_plasma_gun.has_method("is_out_of_ammo"),
		"Plasma Gun should not participate in the ammo HUD state")


func test_try_fire_once_only_obeys_cooldown() -> void:
	var first_fired: bool = _plasma_gun.try_fire_once()
	var second_fired: bool = _plasma_gun.try_fire_once()
	assert_true(first_fired, "Plasma Gun should fire when cooldown is ready")
	assert_false(second_fired, "Plasma Gun should be blocked by cooldown, not ammo depletion")


func test_projectile_arc_visual_rises_mid_flight() -> void:
	var projectile = _PLASMA_PROJECTILE_SCENE.instantiate()
	add_child_autofree(projectile)
	var orb := projectile.get_node("OrbVisual") as Polygon2D
	var base_y: float = orb.position.y

	projectile.max_lifetime = 2.0
	projectile.lob_height = 30.0
	projectile._elapsed = 1.0
	projectile._update_arc_visuals()

	assert_lt(orb.position.y, base_y,
		"Orb visual should lift upward around the midpoint of the lob")


func test_projectile_stops_on_obstacle_body() -> void:
	var projectile = _PLASMA_PROJECTILE_SCENE.instantiate()
	add_child_autofree(projectile)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)

	projectile._on_body_entered(wall)

	assert_true(projectile.is_queued_for_deletion(),
		"Plasma projectile should be destroyed on wall impact instead of piercing through")


func test_catalog_contains_plasma_gun() -> void:
	for gun in MechCatalog.get_all_guns():
		if gun.weapon_type == WeaponData.WeaponType.PLASMA_GUN:
			assert_eq(gun.name, "Plasma Gun")
			assert_eq(gun.damage, 24)
			assert_eq(gun.penetration, 5)
			assert_eq(gun.get_sprite_path(), "res://assets/sprites/weapon_plasma.svg")
			return
	fail_test("No PLASMA_GUN weapon found in catalog")