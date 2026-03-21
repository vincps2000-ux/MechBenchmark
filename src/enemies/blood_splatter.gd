# blood_splatter.gd — Cosmetic blood splatter left on the ground when infantry dies.
class_name BloodSplatter
extends Node2D

## How long the splatter stays fully visible before fading.
@export var linger_time: float = 3.0
## How long the fade-out takes.
@export var fade_time: float = 2.0

var _drops: Array[Dictionary] = []
var _timer: float = 0.0
var _fading: bool = false

func _ready() -> void:
	z_index = -1  # Draw below characters
	_generate_drops()
	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if not _fading and _timer >= linger_time:
		_fading = true
		_timer = 0.0
	if _fading:
		var alpha := 1.0 - clampf(_timer / fade_time, 0.0, 1.0)
		modulate.a = alpha
		if alpha <= 0.0:
			queue_free()

func _draw() -> void:
	for drop: Dictionary in _drops:
		var pos: Vector2 = drop["pos"]
		var radius: float = drop["radius"]
		var color: Color = drop["color"]
		draw_circle(pos, radius, color)

func _generate_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position) ^ int(Time.get_ticks_msec())

	# Central pool
	var pool_r: float = rng.randf_range(5.0, 9.0)
	_drops.append({
		"pos": Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
		"radius": pool_r,
		"color": _blood_color(rng),
	})

	# Surrounding smaller droplets  (4-8)
	var count: int = rng.randi_range(4, 8)
	for i: int in count:
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(4.0, 16.0)
		var r: float = rng.randf_range(1.5, 4.0)
		_drops.append({
			"pos": Vector2(cos(angle), sin(angle)) * dist,
			"radius": r,
			"color": _blood_color(rng),
		})

func _blood_color(rng: RandomNumberGenerator) -> Color:
	# Dark red variants
	return Color(
		rng.randf_range(0.45, 0.7),
		rng.randf_range(0.0, 0.08),
		rng.randf_range(0.0, 0.05),
		rng.randf_range(0.8, 1.0),
	)
