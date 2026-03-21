# enemy_projectile.gd — Fast projectile fired by enemy infantry.
# Currently does NOT deal damage to the player (placeholder for future).
class_name EnemyProjectile
extends Area2D

const MAX_LIFETIME := 4.0   # seconds before auto-destroy

## Set by the spawning enemy before adding to tree.
var velocity: Vector2 = Vector2.ZERO
var damage: int = 5

var _elapsed: float = 0.0

func _ready() -> void:
	# Layer 4 (projectiles = bit 3); mask layer 5 (bit 4 = value 16) = environment obstacles
	collision_layer = 8
	collision_mask  = 16

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += velocity * delta
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME:
		queue_free()

## Destroy the projectile when it hits a StaticBody2D (obstacle / wall).
func _on_body_entered(_body: Node2D) -> void:
	queue_free()
