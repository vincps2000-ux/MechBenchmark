class_name ReconDrone
extends CharacterBody2D

signal battery_depleted

const MAX_BATTERY := 100.0
const BATTERY_DRAIN_PER_SECOND := 4.0
const FORWARD_THRUST := 420.0
const STRAFE_THRUST := 320.0
const ROTATION_SPEED := 2.8
const ACCELERATION := 6.5
const DRAG_PER_SECOND := 1.4

@onready var camera: Camera2D = $Camera2D

var _battery: float = MAX_BATTERY

func _ready() -> void:
	z_index = 4
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _battery <= 0.0:
		return

	_battery = maxf(0.0, _battery - BATTERY_DRAIN_PER_SECOND * delta)
	if _battery == 0.0:
		battery_depleted.emit()
		queue_free()
		return

	var turn_input := (
		float(Input.is_key_pressed(KEY_E)) -
		float(Input.is_key_pressed(KEY_Q))
	)
	rotation += turn_input * ROTATION_SPEED * delta

	var forward_input := (
		float(Input.is_action_pressed("move_up")) -
		float(Input.is_action_pressed("move_down"))
	)
	var strafe_input := (
		float(Input.is_action_pressed("move_right")) -
		float(Input.is_action_pressed("move_left"))
	)

	var desired_velocity := (
		transform.x * (forward_input * FORWARD_THRUST) +
		transform.y * (strafe_input * STRAFE_THRUST)
	)
	var accel_weight := clampf(ACCELERATION * delta, 0.0, 1.0)
	velocity = velocity.lerp(desired_velocity, accel_weight)
	velocity *= maxf(0.0, 1.0 - DRAG_PER_SECOND * delta)
	move_and_slide()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0.72, 0.92, 1.0, 0.95))
	draw_circle(Vector2.ZERO, 3.0, Color(0.08, 0.22, 0.32, 0.95))
	draw_line(Vector2.ZERO, Vector2(10.0, 0.0), Color(0.2, 0.95, 0.82, 0.95), 2.0, true)
	draw_line(Vector2(-8.0, -5.0), Vector2(-8.0, 5.0), Color(0.4, 0.7, 0.95, 0.95), 2.0, true)

	# Small heading marker matching mech-style directional readability.
	var marker_color := Color(1.0, 0.24, 0.2, 0.85)
	var marker_tip := Vector2(12.0, 0.0)
	var marker_base_top := Vector2(6.0, -3.0)
	var marker_base_bottom := Vector2(6.0, 3.0)
	draw_colored_polygon(PackedVector2Array([
		marker_tip,
		marker_base_top,
		marker_base_bottom,
	]), marker_color)

func get_battery() -> float:
	return _battery

func get_max_battery() -> float:
	return MAX_BATTERY

func get_battery_ratio() -> float:
	if MAX_BATTERY <= 0.0:
		return 0.0
	return _battery / MAX_BATTERY

func set_active_view(active: bool) -> void:
	if active:
		camera.make_current()

func set_launch_velocity(world_direction: Vector2) -> void:
	if world_direction.length_squared() <= 0.0001:
		return
	velocity = world_direction.normalized() * (FORWARD_THRUST * 0.35)

func debug_deplete_battery() -> void:
	_battery = 0.0
	battery_depleted.emit()
	queue_free()
