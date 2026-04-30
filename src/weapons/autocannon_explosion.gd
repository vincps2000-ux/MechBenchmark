# autocannon_explosion.gd — Small impact explosion that deals area damage.
#
# Instantiated at the point of projectile impact.  Draws a circle that
# rapidly expands then fades out.  During the expand phase an Area2D hitbox
# (radius = MAX_RADIUS) is active; every enemy touched once receives damage.
# The hitbox is disabled as soon as the expand phase ends so enemies walking
# through the fading visual are not hit a second time.
class_name AutocannonExplosion
extends Area2D
const ENEMY_DAMAGE_SYSTEM := preload("res://src/combat/enemy_damage_system.gd")

## Radius the explosion ring grows to at full expansion.
const MAX_RADIUS  := 40.0
## Duration of the expand phase (fast snap outward).
const EXPAND_TIME := 0.10
## Duration of the fade phase after fully expanded.
const FADE_TIME   := 0.18
## Number of points used to draw the circle polygon.
const POINT_COUNT := 24

## Inner fill: warm orange.
const COLOR_FILL  := Color(1.00, 0.55, 0.10, 0.70)
## Outer ring: bright yellow-white.
const COLOR_RING  := Color(1.00, 0.90, 0.30, 0.90)

# 0 = expanding, 1 = fading
var _state:   int   = 0
var _elapsed: float = 0.0

var _fill_poly : Polygon2D = null
var _ring_poly : Polygon2D = null

## Damage dealt to each enemy inside the blast radius.  Set by the projectile
## before this node is added to the scene tree.
var damage: int = 25
## Armour penetration value; set by the projectile.
var penetration: int = 4
## External AOE scaler. 1.0 = default blast radius.
var blast_scale: float = 1.0
## Actors this explosion should damage (2 = enemies, 1 = player).
var target_collision_mask: int = 2

## Tracks enemies already damaged so a slow enemy isn't hit twice.
var _hit_set: Array = []

var _audio: AudioStreamPlayer2D

func _ready() -> void:
	# Procedural explosion boom
	_audio = AudioStreamPlayer2D.new()
	_audio.stream = _create_boom_stream()
	_audio.volume_db = -6.0
	_audio.max_distance = 800.0
	add_child(_audio)
	_audio.play()

	# ── Collision: no layer (we are not an obstacle), configurable target mask ──
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", target_collision_mask)
	set_deferred("monitorable", false)   # nothing needs to detect us
	# Defer monitoring enable to avoid "Can't change state while flushing queries"
	# when spawned from inside an area_entered callback.
	call_deferred("_enable_monitoring")

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
	_fill_poly.color = COLOR_FILL
	_fill_poly.z_index = 10
	add_child(_fill_poly)

	# Build thicker outline ring
	_ring_poly = Polygon2D.new()
	_ring_poly.color = COLOR_RING
	_ring_poly.z_index = 11
	add_child(_ring_poly)

	_update_visuals(0.0, 1.0)

func _process(delta: float) -> void:
	_elapsed += delta

	match _state:
		0:  # expand
			var t := _elapsed / EXPAND_TIME
			if t >= 1.0:
				t = 1.0
				_state = 1
				_elapsed = 0.0
				# Blast window closed — stop detecting new targets
				call_deferred("_disable_monitoring")
			_update_visuals(t, 1.0)

		1:  # fade
			var t := _elapsed / FADE_TIME
			if t >= 1.0:
				queue_free()
				return
			_update_visuals(1.0, 1.0 - t)

func _update_visuals(expand_t: float, alpha: float) -> void:
	# Ease-out expansion so it snaps fast then slows.
	var max_radius := _effective_max_radius()
	var radius := max_radius * (1.0 - pow(1.0 - expand_t, 2.0))

	_fill_poly.polygon  = _make_circle(radius * 0.80)
	_ring_poly.polygon  = _make_circle(radius)

	var fill_c := COLOR_FILL
	fill_c.a = COLOR_FILL.a * alpha
	_fill_poly.color = fill_c

	var ring_c := COLOR_RING
	ring_c.a = COLOR_RING.a * alpha
	_ring_poly.color = ring_c

func _on_area_entered(area: Area2D) -> void:
	if _hit_set.has(area):
		return
	_hit_set.append(area)
	if area.has_method("take_damage"):
		area.take_damage(damage, penetration)
	elif area.is_in_group("player"):
		ENEMY_DAMAGE_SYSTEM.apply_to_player(damage, penetration, area)
	elif is_instance_valid(area.get_parent()) and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, penetration)
	elif is_instance_valid(area.get_parent()) and area.get_parent().is_in_group("player"):
		ENEMY_DAMAGE_SYSTEM.apply_to_player(damage, penetration, area.get_parent())

func _on_body_entered(body: Node2D) -> void:
	if _hit_set.has(body):
		return
	_hit_set.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage, penetration)
	elif body.is_in_group("player"):
		ENEMY_DAMAGE_SYSTEM.apply_to_player(damage, penetration, body)


func _effective_max_radius() -> float:
	return MAX_RADIUS * maxf(0.2, blast_scale)


func _enable_monitoring() -> void:
	set_deferred("monitoring", true)


func _disable_monitoring() -> void:
	set_deferred("monitoring", false)


func _make_circle(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in POINT_COUNT:
		var angle := TAU * float(i) / float(POINT_COUNT)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts

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
