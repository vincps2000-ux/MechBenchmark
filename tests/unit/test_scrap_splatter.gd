extends GutTest

const ENEMY_TANK_SCENE := preload("res://scenes/enemies/enemy_tank.tscn")

func before_each() -> void:
	_clear_scrap_splatter()

func after_each() -> void:
	_clear_scrap_splatter()

func test_enemy_tank_lethal_hit_spawns_scrap_splatter() -> void:
	var tank := ENEMY_TANK_SCENE.instantiate() as EnemyTank
	add_child_autofree(tank)

	var before := _count_scrap_splatter()
	tank.take_damage(999, 999)
	await get_tree().process_frame

	assert_eq(_count_scrap_splatter(), before + 1, "Mechanical tank death should spawn one scrap splatter")

func _count_scrap_splatter() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path.ends_with("scrap_splatter.gd"):
			count += 1
	return count

func _clear_scrap_splatter() -> void:
	for child in get_tree().root.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path.ends_with("scrap_splatter.gd"):
			child.free()