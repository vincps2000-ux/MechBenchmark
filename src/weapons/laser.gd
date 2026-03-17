# laser.gd — Laser weapon: instant-hit raycast firing on right-click
class_name Laser
extends Node2D

const BEAM_SCENE := preload("res://scenes/weapons/laser_beam.tscn")
const MAX_RANGE  := 900.0
## Collision layer bits to test against (layer 2 = enemies / targets)
const HIT_MASK   := 2
const DAMAGE     := 25

@onready var _cooldown: Timer = $CooldownTimer

var _can_fire: bool = true

func _ready() -> void:
	_cooldown.one_shot = true
	_cooldown.timeout.connect(_on_cooldown_done)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _can_fire:
			_fire()

func _fire() -> void:
	_can_fire = false
	_cooldown.start()

	# Muzzle tip: 14 px forward from centre along the weapon's +X axis
	# (the laser SVG is 28 px wide and centred, so the tip is at +14 local units)
	var fire_dir:   Vector2 = global_transform.x            # already normalised
	var muzzle_pos: Vector2 = global_position + fire_dir * 14.0

	var target_pos := muzzle_pos + fire_dir * MAX_RANGE

	# Instant-hit raycast — only test areas (targets are Area2D nodes)
	var space := get_world_2d().direct_space_state
	var query  := PhysicsRayQueryParameters2D.create(muzzle_pos, target_pos)
	query.collision_mask     = HIT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := space.intersect_ray(query)

	var hit_pos: Vector2
	if result.is_empty():
		hit_pos = target_pos
	else:
		hit_pos = result["position"]
		var collider = result["collider"]
		if collider.has_method("take_damage"):
			collider.take_damage(DAMAGE)

	# Spawn beam visual at the scene root
	var beam := BEAM_SCENE.instantiate()
	get_tree().root.add_child(beam)
	(beam as Node2D).call("fire", muzzle_pos, hit_pos)

func _on_cooldown_done() -> void:
	_can_fire = true
