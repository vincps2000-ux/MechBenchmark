# enemy_projectile.gd — Fast projectile fired by enemy infantry.
class_name EnemyProjectile
extends Area2D

const MAX_LIFETIME := 4.0   # seconds before auto-destroy

## Set by the spawning enemy before adding to tree.
var velocity: Vector2 = Vector2.ZERO
var damage: int = 5
var penetration: int = 2

var _elapsed: float = 0.0

func _ready() -> void:
	# Layer 4 (projectiles = bit 3)
	# Mask: layer 1 (player = bit 0 = 1) + layer 5 (obstacles = bit 4 = 16)
	collision_layer = 8
	collision_mask  = 17   # 1 + 16

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += velocity * delta
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hit_player(body)
	queue_free()

func _hit_player(player: Node2D) -> void:
	var stats: PlayerStats = GameManager.player_stats
	if not stats:
		return
	if ArmorSystem.roll_penetration(penetration, stats.armor):
		stats.take_damage(1)
	else:
		# Deflected — sparks on the player
		var sparks := DeflectionSparks.new()
		player.get_tree().root.add_child(sparks)
		sparks.global_position = player.global_position
