# enemy_damage_system.gd — Applies enemy weapon damage to player structure health.
class_name EnemyDamageSystem

const MECH_DEATH_EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")
const PLAYER_DEATH_META := "_mech_death_handled"

## Returns how much structure damage should be dealt for a raw enemy hit.
## Player and enemies both use direct HP subtraction.
static func to_structure_damage(raw_enemy_damage: int) -> int:
	return maxi(0, raw_enemy_damage)

## Applies enemy damage to player stats with armor penetration conversion.
## Returns true if damage was applied, false if deflected or no player stats exist.
static func apply_to_player(raw_enemy_damage: int, penetration: int, player_node: Node2D = null) -> bool:
	var stats: PlayerStats = GameManager.player_stats
	if not stats:
		return false
	if stats.is_dead():
		return false

	if not ArmorSystem.roll_penetration(penetration, stats.armor):
		if is_instance_valid(player_node):
			var sparks := DeflectionSparks.new()
			player_node.get_tree().root.add_child(sparks)
			sparks.global_position = player_node.global_position
		return false

	var structure_damage := to_structure_damage(raw_enemy_damage)
	if structure_damage > 0:
		stats.take_damage(structure_damage)
		if stats.is_dead():
			_handle_player_death(player_node)
		return true
	return false

static func _handle_player_death(player_node: Node2D) -> void:
	if GameManager.is_running:
		GameManager.end_game()
	else:
		GameManager.is_running = false

	if not is_instance_valid(player_node):
		return
	if player_node.has_meta(PLAYER_DEATH_META):
		return
	player_node.set_meta(PLAYER_DEATH_META, true)
	var death_position := player_node.global_position
	var death_camera := player_node.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(death_camera) and player_node.is_inside_tree():
		var tree := player_node.get_tree()
		var camera_parent: Node = tree.current_scene if tree.current_scene != null else tree.root
		death_camera.reparent(camera_parent, true)
		death_camera.global_position = death_position
		death_camera.enabled = true
		if death_camera.is_inside_tree():
			death_camera.make_current()
		else:
			death_camera.call_deferred("make_current")

	if player_node.is_inside_tree():
		_spawn_death_explosion_deferred(player_node.get_tree().root, death_position)

	player_node.queue_free()

static func _spawn_death_explosion_deferred(root: Node, death_position: Vector2) -> void:
	if not is_instance_valid(root):
		return
	var explosion = MECH_DEATH_EXPLOSION_SCENE.instantiate()
	explosion.damage = 0
	explosion.penetration = 0
	explosion.target_collision_mask = 0
	explosion.blast_scale = 1.6
	root.call_deferred("add_child", explosion)
	explosion.set_deferred("global_position", death_position)
