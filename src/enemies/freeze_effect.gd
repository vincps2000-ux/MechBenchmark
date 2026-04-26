# freeze_effect.gd — Stasis node attached to frozen enemies.
# Disables all movement and firing for the duration, then removes itself.
class_name FreezeEffect
extends CPUParticles2D

## How many seconds the freeze lasts.
var duration: float = 10.0

var _timer: float = 0.0

func _ready() -> void:
	_configure_particles()
	emitting = true
	var host := get_parent()
	if host and "_is_frozen" in host:
		host._is_frozen = true

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		_expire()

func _expire() -> void:
	var host := get_parent()
	if is_instance_valid(host) and "_is_frozen" in host:
		host._is_frozen = false
	emitting = false
	queue_free()

func _configure_particles() -> void:
	amount = 24
	lifetime = 0.8
	one_shot = false
	preprocess = 0.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 8.0
	direction = Vector2(0.0, -1.0)
	spread = 60.0
	gravity = Vector2(0.0, -10.0)
	initial_velocity_min = 10.0
	initial_velocity_max = 30.0
	scale_amount_min = 2.0
	scale_amount_max = 5.0
	color = Color(0.5, 0.85, 1.0, 0.85)
	z_index = 10
