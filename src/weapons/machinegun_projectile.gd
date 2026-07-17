# machinegun_projectile.gd — Small fast bullet fired by the Machinegun.
# No explosion — just direct kinetic damage on contact.
class_name MachinegunProjectile
extends Area2D

const MAX_LIFETIME := 2.0
const COLOR_BULLET := Color(1.0, 0.85, 0.3, 1.0)

var velocity: Vector2 = Vector2.ZERO
var damage: int = 3
var pierce: int = 1
var penetration: int = 4
var max_lifetime: float = MAX_LIFETIME
var bullet_color: Color = COLOR_BULLET
var knockback_force: float = 0.0

var _elapsed: float = 0.0
var _pierced: int   = 0

func _ready() -> void:
	add_to_group("level_effect")
	collision_layer = 8       # bit 3 (projectiles)
	collision_mask  = 2 | 16  # bit 1 (enemies) + bit 4 (environment)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	var visual := get_node_or_null("BulletVisual") as Polygon2D
	if visual:
		visual.color = bullet_color

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	_apply_impact(area)
	_deferred_pierce()

func _on_body_entered(body: Node2D) -> void:
	_apply_impact(body)
	call_deferred("_deferred_pierce")

func _apply_impact(collider: Node) -> void:
	var target := collider
	if not target.has_method("take_damage") and target.get_parent() != null:
		target = target.get_parent()
	if damage > 0 and target.has_method("take_damage"):
		target.take_damage(damage, penetration)
	if knockback_force > 0.0 and target.has_method("apply_knockback"):
		target.apply_knockback(velocity.normalized() * knockback_force)

func _deferred_pierce() -> void:
	_pierced += 1
	if _pierced >= pierce:
		queue_free()
