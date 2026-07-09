# c4_charge.gd — Sticky C4 charge tossed by the C4 Launcher.
#
# Slides to a stop where it lands and sits armed indefinitely, LED
# blinking.  It never explodes on its own — the player must squeeze the
# clacker (hold fire) to set it off.  Detonation is a huge blast.
class_name C4Charge
extends Area2D

const EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")

## Fraction of velocity retained per second — skids to a stop fast.
const DRAG := 0.02
## Below this speed the charge counts as "stuck" and stops moving.
const STICK_SPEED := 8.0
## Armed LED blink frequency in Hz.
const BLINK_FREQ := 3.0

var velocity: Vector2 = Vector2.ZERO
var damage: int = 120
var penetration: int = 10
var aoe_scale: float = 3.0

var _elapsed: float = 0.0
var _stuck: bool = false
var _detonating: bool = false
var _led: Node2D = null

func _ready() -> void:
	add_to_group("level_effect")
	collision_layer = 8   # bit 3 = projectiles
	collision_mask  = 16  # bit 4 (environment) — stops at walls, ignores enemies

	body_entered.connect(_on_body_entered)
	_led = get_node_or_null("ChargeVisual/ArmedLed") as Node2D

func _physics_process(delta: float) -> void:
	_elapsed += delta

	if not _stuck:
		position += velocity * delta
		velocity = velocity * pow(DRAG, delta)
		# Skid rotation while sliding
		rotation += velocity.length() * 0.002
		if velocity.length() <= STICK_SPEED:
			_stuck = true
			velocity = Vector2.ZERO

	# Armed LED blink
	if is_instance_valid(_led):
		_led.visible = sin(_elapsed * BLINK_FREQ * TAU) > 0.0

func is_armed() -> bool:
	return not _detonating

## Detonate after an optional ripple delay (0 = immediately).
func detonate_delayed(delay: float) -> void:
	if _detonating:
		return
	_detonating = true
	if delay <= 0.0:
		_explode()
	else:
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(_explode)

func detonate() -> void:
	detonate_delayed(0.0)

func _on_body_entered(_body: Node2D) -> void:
	# Hit a wall: stick right there.
	_stuck = true
	velocity = Vector2.ZERO

func _explode() -> void:
	if is_queued_for_deletion():
		return
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.damage = damage
	explosion.penetration = penetration
	explosion.blast_scale = aoe_scale
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
	queue_free()
