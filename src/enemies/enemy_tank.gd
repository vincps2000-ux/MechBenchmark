# enemy_tank.gd — Armoured tank enemy that must turn before moving.
# Uses the same Autocannon script as the player, but AI-triggered.
class_name EnemyTank
extends CharacterBody2D

signal died(enemy: EnemyTank)

const AUTOCANNON_SCENE := preload("res://scenes/weapons/autocannon.tscn")
const SCRAP_SPLATTER := preload("res://src/enemies/scrap_splatter.gd")
const _BURN_EFFECT_SCRIPT := preload("res://src/enemies/burn_effect.gd")
const _FREEZE_EFFECT_SCRIPT := preload("res://src/enemies/freeze_effect.gd")

const HALF_W := 18.0
const HALF_H := 11.0

@export var turn_speed: float = 120.0
@export var move_speed: float = 55.0
@export var preferred_range: float = 350.0
@export var fire_range: float = 420.0
@export var fire_arc_deg: float = 12.0
@export var path_reach_distance: float = 30.0
@export var path_alert_range: float = 320.0
@export var path_end_circle_radius: float = 72.0
@export var path_end_circle_speed: float = 0.9

@export var max_health: int = 20
@export var armor: int = 5

const COLOR_BODY := Color(0.42, 0.35, 0.22, 1.0)
const COLOR_DAMAGED := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TREAD := Color(0.25, 0.20, 0.13, 1.0)

var health: int
var _is_frozen: bool = false
var _player: Node2D = null
var _autocannon: Autocannon = null
var _rng := RandomNumberGenerator.new()
var _level_pathing_enabled: bool = false
var _path_alerted: bool = false
var _path_points: Array[Vector2] = []
var _path_index: int = 0
var _path_end_circling: bool = false
var _path_end_anchor: Vector2 = Vector2.ZERO
var _circle_phase: float = 0.0

@onready var _visual: Polygon2D = $Visual

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_player = _find_player()
	_rng.randomize()
	_setup_autocannon()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not _player:
			return

	if _is_frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _level_pathing_enabled and _path_end_circling:
		_circle_at_path_end(delta)
		return

	if _level_pathing_enabled and not _path_alerted:
		if global_position.distance_to(_player.global_position) <= path_alert_range:
			_path_alerted = true
			_path_end_circling = false
		else:
			_follow_level_path(delta)
			return

	var to_player := global_position.direction_to(_player.global_position)
	var dist_player := global_position.distance_to(_player.global_position)

	# Rotate hull toward player.
	var target_angle := to_player.angle()
	var angle_diff := wrapf(target_angle - rotation, -PI, PI)
	var max_rot := deg_to_rad(turn_speed) * delta
	rotation += clampf(angle_diff, -max_rot, max_rot)

	# Move only forward when roughly facing the player.
	var facing_player := absf(wrapf(target_angle - rotation, -PI, PI)) < deg_to_rad(30.0)
	if dist_player > preferred_range and facing_player:
		velocity = transform.x * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Fire when aimed and in range; same autocannon logic as player.
	if is_instance_valid(_autocannon):
		var aim_error := absf(wrapf(to_player.angle() - rotation, -PI, PI))
		if dist_player <= fire_range and aim_error <= deg_to_rad(fire_arc_deg):
			_autocannon.try_fire_once()

func configure_level_path(path_points: Array[Vector2], alert_range: float = 320.0) -> void:
	_path_points = path_points.duplicate()
	_path_index = 0
	_level_pathing_enabled = not _path_points.is_empty()
	_path_alerted = false
	_path_end_circling = false
	_path_end_anchor = Vector2.ZERO
	_circle_phase = randf_range(0.0, TAU)
	path_alert_range = alert_range

func alert_to_player() -> void:
	if _level_pathing_enabled:
		_path_alerted = true
		_path_end_circling = false

func is_path_alerted() -> bool:
	return _path_alerted

func is_path_end_circling() -> bool:
	return _path_end_circling

func begin_loosing_zone_orbit(anchor: Vector2) -> void:
	_path_end_anchor = anchor
	_path_end_circling = true
	_level_pathing_enabled = true

func _follow_level_path(delta: float) -> void:
	if _path_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _path_end_circling:
		_circle_at_path_end(delta)
		return

	var target := _path_points[min(_path_index, _path_points.size() - 1)]
	if global_position.distance_to(target) <= path_reach_distance:
		if _path_index < _path_points.size() - 1:
			_path_index += 1
			target = _path_points[_path_index]
		else:
			_path_end_circling = true
			_path_end_anchor = target
			_circle_at_path_end(delta)
			return

	var to_target := global_position.direction_to(target)
	var target_angle := to_target.angle()
	var angle_diff := wrapf(target_angle - rotation, -PI, PI)
	var max_rot := deg_to_rad(turn_speed) * delta
	rotation += clampf(angle_diff, -max_rot, max_rot)

	# Keep movement deliberate: tank rotates into the curve before pushing forward.
	var facing_target := absf(wrapf(target_angle - rotation, -PI, PI)) < deg_to_rad(22.0)
	if facing_target:
		velocity = transform.x * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _circle_at_path_end(delta: float) -> void:
	_circle_phase = wrapf(_circle_phase + path_end_circle_speed * delta, 0.0, TAU)
	var orbit_target := _path_end_anchor + Vector2.from_angle(_circle_phase) * path_end_circle_radius
	var to_orbit := global_position.direction_to(orbit_target)
	var target_angle := to_orbit.angle()
	var angle_diff := wrapf(target_angle - rotation, -PI, PI)
	var max_rot := deg_to_rad(turn_speed) * delta
	rotation += clampf(angle_diff, -max_rot, max_rot)

	var facing_orbit := absf(wrapf(target_angle - rotation, -PI, PI)) < deg_to_rad(26.0)
	velocity = transform.x * move_speed if facing_orbit else Vector2.ZERO
	move_and_slide()

func take_damage(amount: int, penetration: int = 10) -> void:
	if not ArmorSystem.roll_penetration(penetration, armor):
		_spawn_deflection()
		return

	health -= amount
	_visual.color = COLOR_DAMAGED
	var tween := create_tween()
	tween.tween_property(_visual, "color", COLOR_BODY, 0.12)

	if health <= 0:
		_spawn_scrap_splatter()
		died.emit(self)
		queue_free()

func apply_burn(ticks: int = 2, damage_per_tick: int = 4) -> void:
	for child in get_children():
		if child.get_script() == _BURN_EFFECT_SCRIPT:
			child.ticks_remaining = maxi(child.ticks_remaining, ticks)
			return
	var burn = _BURN_EFFECT_SCRIPT.new()
	burn.tick_damage = damage_per_tick
	burn.ticks_remaining = ticks
	add_child(burn)

func apply_freeze(dur: float = 10.0) -> void:
	for child in get_children():
		if child.get_script() == _FREEZE_EFFECT_SCRIPT:
			child.duration = dur
			child._timer = 0.0
			return
	var freeze = _FREEZE_EFFECT_SCRIPT.new()
	freeze.duration = dur
	add_child(freeze)

func _setup_autocannon() -> void:
	var weapon := AUTOCANNON_SCENE.instantiate() as Autocannon
	weapon.name = "Autocannon"
	weapon.fire_control_mode = Autocannon.FireControlMode.EXTERNAL
	# Enemy tank autocannon should damage player layer (1), and collide with walls.
	weapon.projectile_target_mask = 1
	weapon.explosion_target_mask = 1

	var data := WeaponData.new()
	data.weapon_type = WeaponData.WeaponType.AUTOCANNON
	data.damage = 20
	data.pierce = 2
	data.penetration = 5
	data.ammo_type = _rng.randi_range(0, 2) as WeaponData.AmmoType
	data.barrel_length = _rng.randi_range(0, WeaponData.BARREL_LENGTH_COUNT - 1) as WeaponData.BarrelLength
	weapon.setup(data)

	weapon.position = Vector2(HALF_W - 2.0, 0.0)
	add_child(weapon)
	_autocannon = weapon

func _draw() -> void:
	var tread_w := HALF_W + 2.0
	var tread_h := 5.0
	var tread_offset := HALF_H + 2.0
	draw_rect(Rect2(-tread_w, -tread_offset - tread_h, tread_w * 2.0, tread_h), COLOR_TREAD)
	draw_rect(Rect2(-tread_w, tread_offset, tread_w * 2.0, tread_h), COLOR_TREAD)

func _spawn_scrap_splatter() -> void:
	var splat := SCRAP_SPLATTER.new()
	splat.add_to_group("scrap_splatter")
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
