# enemy_infantry.gd — Small green circle enemy that chases and shoots at the player.
# Movement / perception / damage handled by the shared EnemyBase AI system.
class_name EnemyInfantry
extends EnemyBase

const ENEMY_PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")
const BLOOD_SPLATTER := preload("res://src/enemies/blood_splatter.gd")

const BASE_COLOR := Color(0.15, 0.75, 0.2, 1.0)

## How close the enemy tries to stay from the player before stopping approach
@export var preferred_range: float = 380.0

## Combat
@export var fire_rate: float = 0.5           # seconds between burst starts
@export var burst_size: int = 3
@export var burst_shot_interval: float = 0.08
@export var spread_degrees: float = 6.0
@export var projectile_speed: float = 360.0
@export var projectile_damage: int = 5
@export var projectile_penetration: int = 2

var _fire_timer: float = 0.0
var _burst_shot_timer: float = 0.0
var _burst_shots_remaining: int = 0

func _init() -> void:
	max_health = 8
	armor = 3
	move_speed = 60.0

func _create_behaviors() -> Array[Callable]:
	return [
		Callable(self, "_behavior_fire_in_range"),
		Callable(self, "_behavior_chase_player"),
	]

func _update_timers(delta: float) -> void:
	_fire_timer -= delta
	_burst_shot_timer -= delta

func _visual_base_color() -> Color:
	return BASE_COLOR

func _behavior_fire_in_range(_delta: float) -> bool:
	var dist_to_player := global_position.distance_to(_player.global_position)
	if dist_to_player > preferred_range:
		return false

	if not _has_line_of_sight_to_player():
		return false

	velocity = Vector2.ZERO
	_try_fire_burst(global_position.direction_to(_player.global_position))
	return true

func _try_fire_burst(base_direction: Vector2) -> void:
	if _burst_shots_remaining <= 0:
		if _fire_timer > 0.0:
			return
		_burst_shots_remaining = burst_size
		_burst_shot_timer = 0.0

	if _burst_shot_timer > 0.0:
		return

	_shoot(_apply_spread(base_direction))
	_burst_shots_remaining -= 1
	if _burst_shots_remaining > 0:
		_burst_shot_timer = burst_shot_interval
	else:
		_fire_timer = fire_rate

func _apply_spread(direction: Vector2) -> Vector2:
	if spread_degrees <= 0.0:
		return direction.normalized()
	var spread_radians := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	return direction.rotated(spread_radians).normalized()

func _shoot(direction: Vector2) -> void:
	var proj: Area2D = ENEMY_PROJECTILE_SCENE.instantiate()
	proj.velocity = direction * projectile_speed
	proj.damage = projectile_damage
	proj.penetration = projectile_penetration
	proj.global_position = global_position
	get_tree().root.add_child(proj)

func _spawn_death_effect() -> void:
	var splat := BLOOD_SPLATTER.new()
	splat.add_to_group("blood_splatter")
	get_tree().root.add_child(splat)
	splat.global_position = global_position
