# enemy_projectile.gd — Fast projectile fired by enemy infantry.
class_name EnemyProjectile
extends Area2D

const MAX_LIFETIME := 4.0   # seconds before auto-destroy
const ENEMY_DAMAGE_SYSTEM := preload("res://src/combat/enemy_damage_system.gd")

## Set by the spawning enemy before adding to tree.
var velocity: Vector2 = Vector2.ZERO
var damage: int = 5
var penetration: int = 2

var _elapsed: float = 0.0

func _ready() -> void:
	add_to_group("level_effect")
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
	ENEMY_DAMAGE_SYSTEM.apply_to_player(damage, penetration, player)
