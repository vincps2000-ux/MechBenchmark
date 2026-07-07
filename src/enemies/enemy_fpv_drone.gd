# enemy_fpv_drone.gd — Fast kamikaze FPV drone.  Flies over obstacles,
# weaves erratically toward the player and self-detonates on proximity.
# All perception / damage / status handling comes from the EnemyBase AI system.
class_name EnemyFpvDrone
extends EnemyBase

const SCRAP_SPLATTER := preload("res://src/enemies/scrap_splatter.gd")
const EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")

const BASE_COLOR := Color(0.85, 0.35, 0.15, 1.0)

## Erratic side-to-side weave while diving at the player.
@export var weave_amplitude: float = 90.0
@export var weave_frequency: float = 7.0
## Distance to the player at which the drone self-detonates.
@export var detonation_range: float = 34.0
@export var explosion_damage: int = 14
@export var explosion_penetration: int = 6

var _weave_phase: float = 0.0
var _detonated: bool = false

func _init() -> void:
	max_health = 4
	armor = 0
	move_speed = 240.0
	alert_range = 700.0

func _enemy_ready() -> void:
	_weave_phase = randf_range(0.0, TAU)
	queue_redraw()

func _create_behaviors() -> Array[Callable]:
	return [
		Callable(self, "_behavior_dive_at_player"),
	]

func _update_timers(delta: float) -> void:
	_weave_phase = wrapf(_weave_phase + weave_frequency * delta, 0.0, TAU)

func _visual_base_color() -> Color:
	return BASE_COLOR

func _behavior_dive_at_player(_delta: float) -> bool:
	var to_player := _player.global_position - global_position
	if to_player.length() <= detonation_range:
		_detonate()
		return true

	var dir := to_player.normalized()
	velocity = dir * move_speed + dir.orthogonal() * sin(_weave_phase) * weave_amplitude
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
	return true

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	velocity = Vector2.ZERO
	EnemyDamageSystem.apply_to_player(explosion_damage, explosion_penetration, _player)
	_spawn_explosion_visual()
	died.emit(self)
	queue_free()

func _spawn_explosion_visual() -> void:
	if not is_inside_tree():
		return
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.damage = 0
	explosion.penetration = 0
	explosion.target_collision_mask = 0
	explosion.blast_scale = 0.7
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position

func _spawn_death_effect() -> void:
	var splat := SCRAP_SPLATTER.new()
	splat.add_to_group("scrap_splatter")
	get_tree().root.add_child(splat)
	splat.global_position = global_position

func _draw() -> void:
	# Rotor arms (X frame) with rotor disc hints at each tip.
	var arm_color := Color(0.2, 0.2, 0.22, 1.0)
	var rotor_color := Color(0.55, 0.55, 0.6, 0.55)
	var arm_len := 12.0
	for angle_deg in [45.0, 135.0, 225.0, 315.0]:
		var dir := Vector2.from_angle(deg_to_rad(angle_deg))
		draw_line(Vector2.ZERO, dir * arm_len, arm_color, 2.5)
		draw_circle(dir * arm_len, 4.5, rotor_color)
