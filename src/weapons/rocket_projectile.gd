# rocket_projectile.gd — Small rocket fired by the Rocket Pod.
# Travels in a straight line, explodes on impact with enemies or walls.
class_name RocketProjectile
extends Area2D

const EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")
const COLOR_ROCKET := Color(1.0, 0.5, 0.2, 1.0)

## Turn rate for seeking rockets (radians per second).
const SEEKING_TURN_RATE := 3.0
## Turn rate for wire-guided rockets (radians per second).
const WIRE_GUIDED_TURN_RATE := 5.0

var velocity: Vector2 = Vector2.ZERO
var damage: int = 15
var pierce: int = 1
var penetration: int = 3
var targeting_type: WeaponData.TargetingType = WeaponData.TargetingType.UNGUIDED
var max_lifetime: float = 3.0
var aoe_scale: float = 1.0
var explosive_enabled: bool = true

var _elapsed: float = 0.0
var _pierced: int   = 0

func _ready() -> void:
	collision_layer = 8    # bit 3 = projectiles
	collision_mask  = 2 | 16  # bit 1 (enemies) + bit 4 (environment)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	var visual := get_node_or_null("RocketVisual") as Polygon2D
	if visual:
		visual.color = COLOR_ROCKET if explosive_enabled else Color(0.55, 0.65, 0.75, 0.9)

func _physics_process(delta: float) -> void:
	match targeting_type:
		WeaponData.TargetingType.SEEKING:
			var target_pos := _find_nearest_enemy()
			if target_pos != Vector2.INF:
				_steer_toward(target_pos, delta)
		WeaponData.TargetingType.WIRE_GUIDED:
			var cursor_pos := _get_cursor_world_pos()
			_steer_toward(cursor_pos, delta)

	position += velocity * delta
	rotation = velocity.angle()
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()


func _steer_toward(target_pos: Vector2, delta: float) -> void:
	var desired_dir := (target_pos - global_position).normalized()
	var current_angle := velocity.angle()
	var desired_angle := desired_dir.angle()
	var angle_diff := angle_difference(current_angle, desired_angle)

	var turn_rate := SEEKING_TURN_RATE if targeting_type == WeaponData.TargetingType.SEEKING else WIRE_GUIDED_TURN_RATE
	var max_turn := turn_rate * delta
	var turn := clampf(angle_diff, -max_turn, max_turn)

	var speed := velocity.length()
	velocity = Vector2.from_angle(current_angle + turn) * speed


func _find_nearest_enemy() -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_dist := INF
	var best_pos := Vector2.INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var dist := global_position.distance_squared_to((enemy as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best_pos = (enemy as Node2D).global_position
	return best_pos


func _get_cursor_world_pos() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return global_position + velocity.normalized() * 100.0
	var canvas := get_canvas_transform()
	return canvas.affine_inverse() * viewport.get_mouse_position()

func _on_area_entered(area: Area2D) -> void:
	if not explosive_enabled:
		queue_free()
		return
	if area.has_method("take_damage"):
		area.take_damage(damage, penetration)
	elif area.get_parent() != null and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, penetration)
	_deferred_explode_and_pierce()

func _on_body_entered(body: Node2D) -> void:
	if not explosive_enabled:
		queue_free()
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, penetration)
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
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.damage = damage
	explosion.penetration = penetration
	explosion.blast_scale = aoe_scale
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
