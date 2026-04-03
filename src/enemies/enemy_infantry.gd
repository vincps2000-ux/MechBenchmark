# enemy_infantry.gd — Small green circle enemy that chases and shoots at the player.
class_name EnemyInfantry
extends CharacterBody2D

signal died(enemy: EnemyInfantry)

const ENEMY_PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")
const BLOOD_SPLATTER := preload("res://src/enemies/blood_splatter.gd")

## Movement
@export var move_speed: float = 60.0
## How close the enemy tries to stay from the player before stopping approach
@export var preferred_range: float = 200.0

## Combat
@export var max_health: int = 8
@export var armor: int = 3
@export var fire_rate: float = 0.25          # seconds between shots
@export var projectile_speed: float = 280.0
@export var projectile_damage: int = 5
@export var projectile_penetration: int = 2

var health: int
var _player: Node2D = null
var _fire_timer: float = 0.0

# ── Visual ────────────────────────────────────────────────────────────────────
@onready var _visual: Polygon2D = $Visual
@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	health = max_health
	# Find the player in the tree (layer 1 / group)
	_player = _find_player()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not _player:
			return

	var dir_to_player := global_position.direction_to(_player.global_position)
	var dist_to_player := global_position.distance_to(_player.global_position)

	# Move toward the player until within preferred range
	if dist_to_player > preferred_range:
		velocity = dir_to_player * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Shooting
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_rate
		_shoot(dir_to_player)

func _shoot(direction: Vector2) -> void:
	var proj: Area2D = ENEMY_PROJECTILE_SCENE.instantiate()
	proj.velocity = direction * projectile_speed
	proj.damage = projectile_damage
	proj.penetration = projectile_penetration
	proj.global_position = global_position
	get_tree().root.add_child(proj)

## Called by player projectiles / weapons.  penetration defaults high so
## callers that don't pass it always penetrate (backward-compat).
func take_damage(amount: int, penetration: int = 10) -> void:
	if not ArmorSystem.roll_penetration(penetration, armor):
		_spawn_deflection()
		return

	health -= amount
	# Flash white briefly
	_visual.color = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_visual, "color", Color(0.15, 0.75, 0.2, 1.0), 0.1)

	if health <= 0:
		_spawn_blood_splatter()
		died.emit(self)
		queue_free()

func _spawn_blood_splatter() -> void:
	var splat := BloodSplatter.new()
	splat.add_to_group("blood_splatter")
	get_tree().root.add_child(splat)
	splat.global_position = global_position

func _spawn_deflection() -> void:
	var sparks := DeflectionSparks.new()
	get_tree().root.add_child(sparks)
	sparks.global_position = global_position

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
