# plasma_projectile.gd — Dense plasma orb with a visible arc over the arena.
class_name PlasmaProjectile
extends Area2D

const MAX_LIFETIME := 2.2
const COLOR_PLASMA := Color(0.25, 0.68, 1.0, 0.95)
const COLOR_CORE := Color(0.82, 0.95, 1.0, 0.95)

var velocity: Vector2 = Vector2.ZERO
var damage: int = 24
var pierce: int = 2
var penetration: int = 5
var max_lifetime: float = MAX_LIFETIME
var lob_height: float = 28.0

var _elapsed: float = 0.0
var _pierced: int = 0
var _base_visual_y: float = 0.0
var _base_shadow_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("level_effect")
	collision_layer = 8
	collision_mask = 2 | 16
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	var orb := get_node_or_null("OrbVisual") as Polygon2D
	if orb:
		_base_visual_y = orb.position.y
		orb.color = COLOR_PLASMA

	var core := get_node_or_null("CoreVisual") as Polygon2D
	if core:
		core.color = COLOR_CORE

	var shadow := get_node_or_null("ShadowVisual") as Polygon2D
	if shadow:
		_base_shadow_scale = shadow.scale

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_elapsed += delta
	_update_arc_visuals()
	if _elapsed >= max_lifetime:
		queue_free()

func _update_arc_visuals() -> void:
	var orb := get_node_or_null("OrbVisual") as Polygon2D
	var core := get_node_or_null("CoreVisual") as Polygon2D
	var shadow := get_node_or_null("ShadowVisual") as Polygon2D
	var progress := clampf(_elapsed / maxf(max_lifetime, 0.001), 0.0, 1.0)
	var arc_offset := sin(progress * PI) * lob_height
	if orb:
		orb.position.y = _base_visual_y - arc_offset
	if core:
		core.position.y = _base_visual_y - arc_offset
	if shadow:
		var shadow_scale := 0.72 + (1.0 - progress) * 0.08 + progress * 0.08
		shadow.scale = _base_shadow_scale * shadow_scale

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage, penetration)
	elif area.get_parent() != null and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, penetration)
	_deferred_pierce()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, penetration)
		call_deferred("_deferred_pierce")
	else:
		queue_free()

func _deferred_pierce() -> void:
	_pierced += 1
	if _pierced >= pierce:
		queue_free()