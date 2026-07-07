# enemy_tank.gd — Armoured tank enemy that must turn before moving.
# Uses the same Autocannon script as the player, but AI-triggered.
# Movement / perception / damage handled by the shared EnemyBase AI system.
class_name EnemyTank
extends EnemyBase

const AUTOCANNON_SCENE := preload("res://scenes/weapons/autocannon.tscn")
const SCRAP_SPLATTER := preload("res://src/enemies/scrap_splatter.gd")

const HALF_W := 18.0
const HALF_H := 11.0

@export var turn_speed: float = 120.0
@export var preferred_range: float = 350.0
@export var fire_range: float = 420.0
@export var fire_arc_deg: float = 12.0
@export var path_reach_distance: float = 30.0
@export var path_alert_range: float = 320.0
@export var path_end_circle_radius: float = 72.0
@export var path_end_circle_speed: float = 0.9

const COLOR_BODY := Color(0.42, 0.35, 0.22, 1.0)
const COLOR_TREAD := Color(0.25, 0.20, 0.13, 1.0)

var _autocannon: Autocannon = null
var _rng := RandomNumberGenerator.new()
var _level_pathing_enabled: bool = false
var _path_alerted: bool = false
var _level_path_points: Array[Vector2] = []
var _level_path_index: int = 0
var _path_end_circling: bool = false
var _path_end_anchor: Vector2 = Vector2.ZERO
var _circle_phase: float = 0.0

func _init() -> void:
	max_health = 20
	armor = 5
	move_speed = 55.0
	alert_range = 560.0

func _enemy_ready() -> void:
	_rng.randomize()
	_setup_autocannon()
	queue_redraw()

func _create_behaviors() -> Array[Callable]:
	return [
		Callable(self, "_behavior_follow_level_path"),
		Callable(self, "_behavior_engage_player"),
	]

func _visual_base_color() -> Color:
	return COLOR_BODY

# ─── Behaviors ────────────────────────────────────────────────────────────────

func _behavior_follow_level_path(delta: float) -> bool:
	if not _level_pathing_enabled:
		return false

	if _path_end_circling:
		_circle_at_path_end(delta)
		return true

	if _path_alerted:
		return false

	if global_position.distance_to(_player.global_position) <= path_alert_range:
		_path_alerted = true
		_path_end_circling = false
		return false

	_follow_level_path(delta)
	return true

func _behavior_engage_player(delta: float) -> bool:
	var to_player := global_position.direction_to(_player.global_position)
	var dist_player := global_position.distance_to(_player.global_position)

	# Rotate hull toward player.
	var target_angle := to_player.angle()
	_rotate_toward(target_angle, delta)

	# Move only forward when roughly facing the player.
	var facing_player := absf(wrapf(target_angle - rotation, -PI, PI)) < deg_to_rad(30.0)
	if dist_player > preferred_range and facing_player:
		velocity = transform.x * move_speed
	else:
		velocity = Vector2.ZERO

	# Fire when aimed and in range; same autocannon logic as player.
	if is_instance_valid(_autocannon):
		var aim_error := absf(wrapf(to_player.angle() - rotation, -PI, PI))
		if dist_player <= fire_range and aim_error <= deg_to_rad(fire_arc_deg):
			_autocannon.try_fire_once()
	return true

# ─── Level path API (used by mission scripts) ─────────────────────────────────

func configure_level_path(path_points: Array[Vector2], p_alert_range: float = 320.0) -> void:
	_level_path_points = path_points.duplicate()
	_level_path_index = 0
	_level_pathing_enabled = not _level_path_points.is_empty()
	_path_alerted = false
	_path_end_circling = false
	_path_end_anchor = Vector2.ZERO
	_circle_phase = randf_range(0.0, TAU)
	path_alert_range = p_alert_range

func alert_to_player() -> void:
	super()
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
	if _level_path_points.is_empty():
		velocity = Vector2.ZERO
		return

	var target := _level_path_points[min(_level_path_index, _level_path_points.size() - 1)]
	if global_position.distance_to(target) <= path_reach_distance:
		if _level_path_index < _level_path_points.size() - 1:
			_level_path_index += 1
			target = _level_path_points[_level_path_index]
		else:
			_path_end_circling = true
			_path_end_anchor = target
			_circle_at_path_end(delta)
			return

	var to_target := global_position.direction_to(target)
	var target_angle := to_target.angle()
	_rotate_toward(target_angle, delta)

	# Keep movement deliberate: tank rotates into the curve before pushing forward.
	var facing_target := absf(wrapf(target_angle - rotation, -PI, PI)) < deg_to_rad(22.0)
	velocity = transform.x * move_speed if facing_target else Vector2.ZERO

func _circle_at_path_end(delta: float) -> void:
	_circle_phase = wrapf(_circle_phase + path_end_circle_speed * delta, 0.0, TAU)
	var orbit_target := _path_end_anchor + Vector2.from_angle(_circle_phase) * path_end_circle_radius
	var to_orbit := global_position.direction_to(orbit_target)
	var target_angle := to_orbit.angle()
	_rotate_toward(target_angle, delta)

	var facing_orbit := absf(wrapf(target_angle - rotation, -PI, PI)) < deg_to_rad(26.0)
	velocity = transform.x * move_speed if facing_orbit else Vector2.ZERO

func _rotate_toward(target_angle: float, delta: float) -> void:
	var angle_diff := wrapf(target_angle - rotation, -PI, PI)
	var max_rot := deg_to_rad(turn_speed) * delta
	rotation += clampf(angle_diff, -max_rot, max_rot)

# ─── Weapon & visuals ─────────────────────────────────────────────────────────

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

func _spawn_death_effect() -> void:
	var splat := SCRAP_SPLATTER.new()
	splat.add_to_group("scrap_splatter")
	get_tree().root.add_child(splat)
	splat.global_position = global_position
