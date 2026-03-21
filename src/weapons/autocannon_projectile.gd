# autocannon_projectile.gd — Fast-moving cannon shell that explodes on impact.
#
# The projectile travels in a straight line at high speed.  When it overlaps
# an enemy Area2D (collision layer 2) it deals damage, spawns a small explosion
# visual, and frees itself.  It also self-destructs after MAX_LIFETIME seconds
# so stray shots don't live forever.
class_name AutocannonProjectile
extends Area2D

const EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")

const MAX_LIFETIME := 3.0   # seconds before auto-destroy

## Velocity vector set by Autocannon before adding to tree.
var velocity: Vector2 = Vector2.ZERO
## Damage to deal on impact; set by Autocannon.
var damage: int = 25
## How many enemies this shell can pierce before detonating (1 = no pierce).
var pierce: int = 1

var _elapsed: float = 0.0
var _pierced: int   = 0

func _ready() -> void:
	# Layer 4 (bit 3) = projectiles; mask layer 2 (bit 1) = enemies
	# Also mask layer 5 (bit 16) = environment obstacles so shells don't fly through walls
	collision_layer = 8    # bit 3 only (projectiles)
	collision_mask  = 2 | 16  # bit 1 (enemies) + bit 4 (environment)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	elif area.get_parent() != null and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)

	# Defer explosion + free so we're not mutating physics state mid-flush
	_deferred_explode_and_pierce()

## Called when the shell hits a PhysicsBody2D (enemy or obstacle/wall).
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		call_deferred("_deferred_explode_and_pierce")
	else:
		call_deferred("_deferred_explode_and_die")

func _deferred_explode_and_pierce() -> void:
	_spawn_explosion()
	_pierced += 1
	if _pierced >= pierce:
		queue_free()

func _deferred_explode_and_die() -> void:
	_spawn_explosion()
	queue_free()

func _spawn_explosion() -> void:
	var explosion: AutocannonExplosion = EXPLOSION_SCENE.instantiate()
	explosion.damage = damage
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
