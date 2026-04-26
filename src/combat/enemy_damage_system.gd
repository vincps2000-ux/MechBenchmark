# enemy_damage_system.gd — Converts enemy weapon damage into player structure damage.
class_name EnemyDamageSystem

# Raw enemy weapon damage is scaled to player integrity chunks.
# Example mapping with default values:
#   1..10  -> 1 structure
#   11..20 -> 2 structure
#   21..30 -> 3 structure
const DAMAGE_PER_STRUCTURE := 10

## Returns how much player structure damage should be dealt for a raw enemy hit.
static func to_structure_damage(raw_enemy_damage: int) -> int:
	if raw_enemy_damage <= 0:
		return 0
	return maxi(1, int(ceil(float(raw_enemy_damage) / float(DAMAGE_PER_STRUCTURE))))

## Applies enemy damage to player stats with armor penetration conversion.
## Returns true if damage was applied, false if deflected or no player stats exist.
static func apply_to_player(raw_enemy_damage: int, penetration: int, player_node: Node2D = null) -> bool:
	var stats: PlayerStats = GameManager.player_stats
	if not stats:
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
		return true
	return false
