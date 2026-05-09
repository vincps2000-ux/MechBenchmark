# scrap_splatter.gd — Cosmetic scrap splatter left on the ground when mechanical enemies die.
class_name ScrapSplatter
extends Node2D

## How long the splatter stays fully visible before fading.
@export var linger_time: float = 3.0
## How long the fade-out takes.
@export var fade_time: float = 2.0

var _chunks: Array[Dictionary] = []

func _ready() -> void:
	z_index = -1  # Draw below characters
	add_to_group("scrap_splatter")
	add_to_group("level_effect")
	_generate_chunks()
	queue_redraw()

func _draw() -> void:
	for chunk: Dictionary in _chunks:
		var pos: Vector2 = chunk["pos"]
		var radius: float = chunk["radius"]
		var color: Color = chunk["color"]
		draw_circle(pos, radius, color)

func _generate_chunks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position) ^ int(Time.get_ticks_msec())

	# Central oil-and-shrapnel pool
	var pool_r: float = rng.randf_range(5.0, 9.0)
	_chunks.append({
		"pos": Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
		"radius": pool_r,
		"color": _scrap_color(rng, true),
	})

	# Surrounding metal fragments (4-8)
	var count: int = rng.randi_range(4, 8)
	for i: int in count:
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(4.0, 16.0)
		var r: float = rng.randf_range(1.5, 4.0)
		_chunks.append({
			"pos": Vector2(cos(angle), sin(angle)) * dist,
			"radius": r,
			"color": _scrap_color(rng),
		})

func _scrap_color(rng: RandomNumberGenerator, dark_bias: bool = false) -> Color:
	if dark_bias:
		return Color(
			rng.randf_range(0.08, 0.16),
			rng.randf_range(0.08, 0.14),
			rng.randf_range(0.08, 0.14),
			rng.randf_range(0.8, 1.0),
		)

	return Color(
		rng.randf_range(0.40, 0.65),
		rng.randf_range(0.38, 0.60),
		rng.randf_range(0.34, 0.56),
		rng.randf_range(0.8, 1.0),
	)