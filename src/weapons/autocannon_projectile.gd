# autocannon_projectile.gd — Fast-moving cannon shell that explodes on impact.
#
# The projectile travels in a straight line at high speed.  When it overlaps
# an enemy Area2D (collision layer 2) it deals damage, spawns a small explosion
# visual, and frees itself.  It also self-destructs after MAX_LIFETIME seconds
# so stray shots don't live forever.
class_name AutocannonProjectile
extends Area2D

const EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")
const ENEMY_DAMAGE_SYSTEM := preload("res://src/combat/enemy_damage_system.gd")

const MAX_LIFETIME := 3.0   # seconds before auto-destroy

## Default HE shell colour.
const COLOR_HE       := Color(1.0, 0.95, 0.3, 1.0)
## Solid shell colour — dark steel.
const COLOR_SOLID     := Color(0.55, 0.55, 0.6, 1.0)
## Canister pellet colour — small blue.
const COLOR_CANISTER  := Color(0.3, 0.5, 0.9, 1.0)

## Velocity vector set by Autocannon before adding to tree.
var velocity: Vector2 = Vector2.ZERO
## Damage to deal on impact; set by Autocannon.
var damage: int = 25
## How many enemies this shell can pierce before detonating (1 = no pierce).
var pierce: int = 1
## Armour penetration value; set by Autocannon.
var penetration: int = 4
## Whether this shell spawns an explosion on impact (false for Solid/Canister).
var explodes: bool = true
## Visual colour override for the bullet polygon.
var shell_color: Color = COLOR_HE
var max_lifetime: float = MAX_LIFETIME
## Actors this projectile should damage (2 = enemies, 1 = player).
var target_collision_mask: int = 2
## Actors the explosion should damage.
var explosion_target_mask: int = 2

var _elapsed: float = 0.0
var _pierced: int   = 0

func _ready() -> void:
	add_to_group("level_effect")
	# Layer 4 (bit 3) = projectiles.
	# Always include layer 5 (bit 16) = environment so shells stop on walls.
	collision_layer = 8    # bit 3 only (projectiles)
	collision_mask  = target_collision_mask | 16

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Apply shell colour to the BulletVisual polygon
	var bullet_visual := get_node_or_null("BulletVisual") as Polygon2D
	if bullet_visual:
		bullet_visual.color = shell_color

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage, penetration)
	elif area.is_in_group("player"):
		ENEMY_DAMAGE_SYSTEM.apply_to_player(damage, penetration, area)
	elif area.get_parent() != null and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, penetration)
	elif area.get_parent() != null and area.get_parent().is_in_group("player"):
		ENEMY_DAMAGE_SYSTEM.apply_to_player(damage, penetration, area.get_parent())

	# Defer explosion + free so we're not mutating physics state mid-flush
	_deferred_explode_and_pierce()

## Called when the shell hits a PhysicsBody2D (enemy or obstacle/wall).
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, penetration)
		call_deferred("_deferred_explode_and_pierce")
	elif body.is_in_group("player"):
		ENEMY_DAMAGE_SYSTEM.apply_to_player(damage, penetration, body)
		call_deferred("_deferred_explode_and_pierce")
	else:
		call_deferred("_deferred_explode_and_die")

func _deferred_explode_and_pierce() -> void:
	if explodes:
		_spawn_explosion()
	_pierced += 1
	if _pierced >= pierce:
		queue_free()

func _deferred_explode_and_die() -> void:
	if explodes:
		_spawn_explosion()
	queue_free()

func _spawn_explosion() -> void:
	var explosion: AutocannonExplosion = EXPLOSION_SCENE.instantiate()
	explosion.damage = damage
	explosion.penetration = penetration
	explosion.target_collision_mask = explosion_target_mask
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
