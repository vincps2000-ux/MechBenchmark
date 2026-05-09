# explosion.gd — Unified explosion system for all area-damage effects
# Used by mines, autocannon projectiles, and other entities that need blast damage.
# Expands quickly, deals damage during expansion, then fades out.
class_name Explosion
extends Area2D

## Radius the explosion expands to at full size.
@export var max_radius: float = 40.0
## Damage dealt to each enemy in blast radius.
@export var damage: int = 1
## Armour penetration value for damage calculation.
@export var penetration: int = 0
## Duration of the expand phase (fast snap outward).
@export var expand_time: float = 0.10
## Duration of the fade phase after expansion.
@export var fade_time: float = 0.18
## Inner fill color (warm orange).
@export var color_fill: Color = Color(1.00, 0.55, 0.10, 0.70)
## Outer ring color (bright yellow-white).
@export var color_ring: Color = Color(1.00, 0.90, 0.30, 0.90)

const POINT_COUNT := 24

# 0 = expanding, 1 = fading
var _state: int = 0
var _elapsed: float = 0.0
var _fill_poly: Polygon2D = null
var _ring_poly: Polygon2D = null
var _hit_set: Array = []
var _audio: AudioStreamPlayer2D = null
var _scale: float = 1.0

func _ready() -> void:
	add_to_group("level_effect")
	# Defer all physics state changes to avoid conflicts during collision callbacks
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 2)
	set_deferred("monitorable", false)

	# Circle hitbox matching the scaled full blast radius
	var effective_radius := _effective_max_radius()
	var shape := CircleShape2D.new()
	shape.radius = effective_radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Build fill disc
	_fill_poly = Polygon2D.new()
	_fill_poly.color = color_fill
	_fill_poly.z_index = 10
	add_child(_fill_poly)

	# Build thicker outline ring
	_ring_poly = Polygon2D.new()
	_ring_poly.color = color_ring
	_ring_poly.z_index = 11
	add_child(_ring_poly)

	_play_boom_sound()
	_update_visuals(0.0, 1.0)
	
	# Enable monitoring after deferred setup
	set_deferred("monitoring", true)

func set_scale_factor(scale: float) -> void:
	"""Set an external AOE scaler. 1.0 = default blast radius."""
	_scale = maxf(0.2, scale)

func _process(delta: float) -> void:
	_elapsed += delta

	match _state:
		0:  # expand
			var t := _elapsed / expand_time
			if t >= 1.0:
				t = 1.0
				_state = 1
				_elapsed = 0.0
				# Blast window closed — stop detecting new targets
				monitoring = false
			_update_visuals(t, 1.0)

		1:  # fade
			var t := _elapsed / fade_time
			if t >= 1.0:
				queue_free()
				return
			_update_visuals(1.0, 1.0 - t)

func _update_visuals(expand_t: float, alpha: float) -> void:
	# Ease-out expansion so it snaps fast then slows
	var max_r := _effective_max_radius()
	var radius := max_r * (1.0 - pow(1.0 - expand_t, 2.0))

	_fill_poly.polygon = _make_circle(radius * 0.80)
	_ring_poly.polygon = _make_circle(radius)

	var fill_c := color_fill
	fill_c.a = color_fill.a * alpha
	_fill_poly.color = fill_c

	var ring_c := color_ring
	ring_c.a = color_ring.a * alpha
	_ring_poly.color = ring_c

func _on_area_entered(area: Area2D) -> void:
	if _hit_set.has(area):
		return
	_hit_set.append(area)
	if area.has_method("take_damage"):
		area.take_damage(damage, penetration)
	elif is_instance_valid(area.get_parent()) and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, penetration)

func _on_body_entered(body: Node2D) -> void:
	if _hit_set.has(body):
		return
	_hit_set.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage, penetration)

func _effective_max_radius() -> float:
	return max_radius * _scale

func _make_circle(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in POINT_COUNT:
		var angle := TAU * float(i) / float(POINT_COUNT)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts

func _play_boom_sound() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.stream = _create_boom_stream()
	_audio.volume_db = -6.0
	_audio.max_distance = 800.0
	add_child(_audio)
	_audio.play()

static func _create_boom_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.18
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-t * 20.0)
		# Low-frequency thump with descending pitch
		var freq := 90.0 + 60.0 * exp(-t * 25.0)
		var boom := sin(t * freq * TAU) * 0.7
		# Add crackle noise layer
		var noise := (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 35.0)
		var sample := (boom + noise) * envelope
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2]     = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
