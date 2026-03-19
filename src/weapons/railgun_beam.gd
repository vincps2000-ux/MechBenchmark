# railgun_beam.gd — Instantaneous bright-white rail-shot beam.
#
# Spawned at the scene root for one shot.  It holds a brief full-brightness
# flash, then fades out quickly and frees itself — no persistent firing loop.
class_name RailgunBeam
extends Node2D

const FLASH_TIME := 0.06   # seconds the beam is held at full alpha
const FADE_TIME  := 0.30   # seconds to fade out after the flash

var _glow : Line2D = null
var _core : Line2D = null
var _edge : Line2D = null

func _ready() -> void:
	_glow = get_node_or_null("GlowLine") as Line2D
	_core = get_node_or_null("CoreLine") as Line2D
	_edge = get_node_or_null("EdgeLine") as Line2D

var _state:   int   = 0   # 0 = flash hold, 1 = fade out
var _elapsed: float = 0.0
var _charge:  float = 1.0  # saved so wider/brighter at higher charge

## Call once immediately after adding to the scene tree.
## `charge` is the 0–1 normalised charge level so a partial shot looks weaker.
func fire(from: Vector2, to: Vector2, charge: float) -> void:
	_charge  = charge
	_state   = 0
	_elapsed = 0.0

	for line: Line2D in [_glow, _core, _edge]:
		if line == null:
			continue
		line.clear_points()
		line.add_point(from)
		line.add_point(to)

	# Width scales with charge — fuller charge = thicker shot.
	if _glow: _glow.width = lerp(4.0, 18.0, charge)
	if _core: _core.width = lerp(1.5,  5.0, charge)
	if _edge: _edge.width = lerp(1.0,  3.0, charge)

	_set_alpha(1.0)

func _process(delta: float) -> void:
	_elapsed += delta
	match _state:
		0:  # hold flash
			if _elapsed >= FLASH_TIME:
				_elapsed -= FLASH_TIME
				_state = 1
		1:  # fade out
			var t := _elapsed / FADE_TIME
			if t >= 1.0:
				queue_free()
				return
			_set_alpha(1.0 - t)

func _set_alpha(a: float) -> void:
	if _glow:
		var gc := _glow.default_color
		gc.a = a * 0.55 * _charge
		_glow.default_color = gc
	if _core:
		var cc := _core.default_color
		cc.a = a
		_core.default_color = cc
	if _edge:
		var ec := _edge.default_color
		ec.a = a * 0.70 * _charge
		_edge.default_color = ec
