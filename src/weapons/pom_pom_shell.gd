# pom_pom_shell.gd — Chunky flak shell fired by the Pom-Pom Gun.
#
# Flies straight with a slight cartoony wobble, then pops into a small
# airburst at the end of its fuse — or on impact, whichever comes first.
class_name PomPomShell
extends Area2D

const EXPLOSION_SCENE := preload("res://scenes/weapons/autocannon_explosion.tscn")

## Seconds of flight before the shell airbursts on its own.
const FUSE_TIME := 0.55
## Wobble frequency (Hz) and amplitude (radians) for the visual only.
const WOBBLE_FREQ := 9.0
const WOBBLE_AMPLITUDE := 0.25

var velocity: Vector2 = Vector2.ZERO
var damage: int = 6
var pierce: int = 1
var penetration: int = 3
var aoe_scale: float = 0.6

var _elapsed: float = 0.0
var _pierced: int = 0
var _visual: Node2D = null

func _ready() -> void:
	add_to_group("level_effect")
	collision_layer = 8       # bit 3 = projectiles
	collision_mask  = 2 | 16  # bit 1 (enemies) + bit 4 (environment)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_visual = get_node_or_null("ShellVisual") as Node2D

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_elapsed += delta
	# Cartoony tumble on the visual only — flight path stays straight.
	if is_instance_valid(_visual):
		_visual.rotation = sin(_elapsed * WOBBLE_FREQ * TAU) * WOBBLE_AMPLITUDE
	if _elapsed >= FUSE_TIME:
		call_deferred("_deferred_pop_and_die")

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage, penetration)
	elif area.get_parent() != null and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, penetration)
	call_deferred("_deferred_pop_and_pierce")

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, penetration)
		call_deferred("_deferred_pop_and_pierce")
	else:
		call_deferred("_deferred_pop_and_die")

func _deferred_pop_and_pierce() -> void:
	_spawn_airburst()
	_pierced += 1
	if _pierced >= pierce:
		queue_free()

func _deferred_pop_and_die() -> void:
	if not is_queued_for_deletion():
		_spawn_airburst()
		queue_free()

func _spawn_airburst() -> void:
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.damage = damage
	explosion.penetration = penetration
	explosion.blast_scale = aoe_scale
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
