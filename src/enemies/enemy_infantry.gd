# enemy_infantry.gd — Small green circle enemy that chases and shoots at the player.
class_name EnemyInfantry
extends CharacterBody2D

signal died(enemy: EnemyInfantry)

const ENEMY_PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")
const BLOOD_SPLATTER := preload("res://src/enemies/blood_splatter.gd")
const _BURN_EFFECT_SCRIPT := preload("res://src/enemies/burn_effect.gd")
const _FREEZE_EFFECT_SCRIPT := preload("res://src/enemies/freeze_effect.gd")

## Movement
@export var move_speed: float = 60.0
## How close the enemy tries to stay from the player before stopping approach
@export var preferred_range: float = 380.0
@export var path_cell_size: float = 64.0
@export var path_world_margin: float = 360.0
@export var path_rebuild_interval: float = 0.35
@export var path_retarget_distance: float = 80.0
@export var path_waypoint_reach_distance: float = 20.0
@export var path_max_grid_dimension: int = 48

## Combat
@export var max_health: int = 8
@export var armor: int = 3
@export var fire_rate: float = 0.5           # seconds between burst starts
@export var burst_size: int = 3
@export var burst_shot_interval: float = 0.08
@export var spread_degrees: float = 6.0
@export var projectile_speed: float = 360.0
@export var projectile_damage: int = 5
@export var projectile_penetration: int = 2

var health: int
var _is_frozen: bool = false
var _player: Node2D = null
var _fire_timer: float = 0.0
var _burst_shot_timer: float = 0.0
var _burst_shots_remaining: int = 0
var _behaviors: Array[Callable] = []
var _path_rebuild_timer: float = 0.0
var _path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _last_path_target: Vector2 = Vector2.INF

const ENVIRONMENT_MASK := 16

# ── Visual ────────────────────────────────────────────────────────────────────
@onready var _visual: Polygon2D = $Visual
@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	# Find the player in the tree (layer 1 / group)
	_player = _find_player()
	_behaviors = [
		Callable(self, "_behavior_fire_in_range"),
		Callable(self, "_behavior_move_into_range")
	]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not _player:
			return

	if _is_frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_fire_timer -= delta
	_burst_shot_timer -= delta
	_path_rebuild_timer -= delta

	var did_apply_behavior := false
	for behavior in _behaviors:
		if behavior.call():
			did_apply_behavior = true
			break

	if not did_apply_behavior:
		velocity = Vector2.ZERO

	move_and_slide()

func _behavior_fire_in_range() -> bool:
	var dist_to_player := global_position.distance_to(_player.global_position)
	if dist_to_player > preferred_range:
		return false

	if not _has_line_of_sight_to_player():
		return false

	velocity = Vector2.ZERO
	_try_fire_burst(global_position.direction_to(_player.global_position))
	return true

func _behavior_move_into_range() -> bool:
	var dir_to_player := global_position.direction_to(_player.global_position)

	if _has_line_of_sight_to_player():
		_clear_path()
		velocity = dir_to_player * move_speed
		return true

	var player_moved_since_path := _last_path_target.distance_to(_player.global_position) >= path_retarget_distance
	if _path_rebuild_timer <= 0.0 or _path_points.is_empty() or player_moved_since_path:
		_rebuild_path_to_player()

	if _path_points.is_empty():
		# Fallback if no path was found this frame.
		velocity = dir_to_player * move_speed
		return true

	_advance_path_index_if_reached()
	if _path_index >= _path_points.size():
		velocity = dir_to_player * move_speed
		return true

	var waypoint := _path_points[_path_index]
	velocity = global_position.direction_to(waypoint) * move_speed
	return true

func _has_line_of_sight_to_player() -> bool:
	var state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, _player.global_position)
	query.collision_mask = ENVIRONMENT_MASK
	query.exclude = [self]
	var hit := state.intersect_ray(query)
	return hit.is_empty()

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

func _advance_path_index_if_reached() -> void:
	while _path_index < _path_points.size() and global_position.distance_to(_path_points[_path_index]) <= path_waypoint_reach_distance:
		_path_index += 1

func _rebuild_path_to_player() -> void:
	_path_rebuild_timer = path_rebuild_interval
	_last_path_target = _player.global_position

	var from := global_position
	var to := _player.global_position
	var min_x: float = minf(from.x, to.x) - path_world_margin
	var min_y: float = minf(from.y, to.y) - path_world_margin
	var max_x: float = maxf(from.x, to.x) + path_world_margin
	var max_y: float = maxf(from.y, to.y) + path_world_margin

	var span_x: float = max_x - min_x
	var span_y: float = max_y - min_y
	var max_span: float = maxf(span_x, span_y)
	var computed_cell_size: float = maxf(path_cell_size, max_span / maxf(1.0, float(path_max_grid_dimension)))

	var cells_x := int(ceil(span_x / computed_cell_size)) + 1
	var cells_y := int(ceil(span_y / computed_cell_size)) + 1
	if cells_x <= 1 or cells_y <= 1:
		_clear_path()
		return

	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, cells_x, cells_y)
	astar.cell_size = Vector2(computed_cell_size, computed_cell_size)
	astar.offset = Vector2(min_x, min_y)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	for y in range(cells_y):
		for x in range(cells_x):
			var point := astar.get_point_position(Vector2i(x, y))
			if _is_environment_blocked(point):
				astar.set_point_solid(Vector2i(x, y), true)

	var start_id := _world_to_cell_id(from, min_x, min_y, computed_cell_size, cells_x, cells_y)
	var end_id := _world_to_cell_id(to, min_x, min_y, computed_cell_size, cells_x, cells_y)

	astar.set_point_solid(start_id, false)
	astar.set_point_solid(end_id, false)

	var path := astar.get_point_path(start_id, end_id)
	if path.size() <= 1:
		_clear_path()
		return

	_path_points = path
	_path_index = 1

func _world_to_cell_id(world_pos: Vector2, min_x: float, min_y: float, cell_size: float, cells_x: int, cells_y: int) -> Vector2i:
	var x := clampi(int(floor((world_pos.x - min_x) / cell_size)), 0, cells_x - 1)
	var y := clampi(int(floor((world_pos.y - min_y) / cell_size)), 0, cells_y - 1)
	return Vector2i(x, y)

func _is_environment_blocked(point: Vector2) -> bool:
	var state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.collision_mask = ENVIRONMENT_MASK
	query.exclude = [self, _player]
	var hit := state.intersect_point(query, 1)
	return not hit.is_empty()

func _clear_path() -> void:
	_path_points = PackedVector2Array()
	_path_index = 0

func _shoot(direction: Vector2) -> void:
	var proj: Area2D = ENEMY_PROJECTILE_SCENE.instantiate()
	proj.velocity = direction * projectile_speed
	proj.damage = projectile_damage
	proj.penetration = projectile_penetration
	proj.global_position = global_position
	get_tree().root.add_child(proj)

## Called by player projectiles / weapons.  penetration defaults high so
## callers that don't pass it always penetrate (backward-compat).
func take_damage(amount: int, penetration: int = 10) -> void:
	if not ArmorSystem.roll_penetration(penetration, armor):
		_spawn_deflection()
		return

	health -= amount
	# Flash white briefly
	_visual.color = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_visual, "color", Color(0.15, 0.75, 0.2, 1.0), 0.1)

	if health <= 0:
		_spawn_blood_splatter()
		died.emit(self)
		queue_free()

## Apply a burning DoT effect.  If already burning, refreshes tick count.
## ticks=2 and damage_per_tick=4 kills infantry (health 8) in exactly 2 ticks.
func apply_burn(ticks: int = 2, damage_per_tick: int = 4) -> void:
	for child in get_children():
		if child.get_script() == _BURN_EFFECT_SCRIPT:
			child.ticks_remaining = maxi(child.ticks_remaining, ticks)
			return
	var burn = _BURN_EFFECT_SCRIPT.new()
	burn.tick_damage = damage_per_tick
	burn.ticks_remaining = ticks
	add_child(burn)

## Freeze the enemy in place for duration seconds. Refreshes if already frozen.
func apply_freeze(dur: float = 10.0) -> void:
	for child in get_children():
		if child.get_script() == _FREEZE_EFFECT_SCRIPT:
			child.duration = dur
			child._timer = 0.0
			return
	var freeze = _FREEZE_EFFECT_SCRIPT.new()
	freeze.duration = dur
	add_child(freeze)

func _spawn_blood_splatter() -> void:
	var splat := BloodSplatter.new()
	splat.add_to_group("blood_splatter")
	get_tree().root.add_child(splat)
	splat.global_position = global_position

func _spawn_deflection() -> void:
	var sparks := DeflectionSparks.new()
	get_tree().root.add_child(sparks)
	sparks.global_position = global_position

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
