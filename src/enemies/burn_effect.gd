# burn_effect.gd — DoT node attached to burning enemies.
# Add as a child of any enemy that has a take_damage() method.
# Deals tick_damage per tick, ignoring armour (high penetration).
# Removes itself after ticks_remaining ticks.
class_name BurnEffect
extends CPUParticles2D

## Damage dealt each tick. Bypasses armour.
var tick_damage: int = 4
## Seconds between damage ticks.
var tick_interval: float = 0.75
## How many damage ticks remain before the burn expires.
var ticks_remaining: int = 2

var _tick_timer: float = 0.0

func _ready() -> void:
	_configure_particles()
	emitting = true

func _process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()

func _apply_tick() -> void:
	var host := get_parent()
	if not is_instance_valid(host):
		queue_free()
		return
	if host.has_method("take_damage"):
		host.take_damage(tick_damage, 999)  # 999 penetration = always bypasses armour
	ticks_remaining -= 1
	if ticks_remaining <= 0:
		emitting = false
		queue_free()

func _configure_particles() -> void:
	amount = 20
	lifetime = 0.6
	one_shot = false
	preprocess = 0.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 6.0
	direction = Vector2(0.0, -1.0)
	spread = 50.0
	gravity = Vector2(0.0, -30.0)
	initial_velocity_min = 25.0
	initial_velocity_max = 60.0
	scale_amount_min = 3.0
	scale_amount_max = 7.0
	color = Color(1.0, 0.45, 0.05, 0.9)
	z_index = 10
