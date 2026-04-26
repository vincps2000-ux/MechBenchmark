# mine.gd — Explosive ground hazard that detonates when player touches it
# Creates a unified explosion that deals area damage to enemies nearby
class_name Mine
extends Area2D

const Explosion := preload("res://src/combat/explosion.gd")

@export var mine_radius: float = 20.0
@export var mine_color: Color = Color(0.2, 0.2, 0.2, 0.9)  # Dark gray
@export var damage: int = 1
@export var explosion_radius: float = 60.0

var _triggered := false
var _player_ref: Node2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player (layer 1)
	monitorable = true

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = mine_radius + 5.0  # Slightly larger collision for detection
	col.shape = circle
	add_child(col)

	body_entered.connect(_on_body_entered)
	queue_redraw()

func trigger() -> void:
	if _triggered:
		return
	_triggered = true
	
	# Defer explosion creation to avoid physics state changes during collision callback
	call_deferred("_create_explosion")
	
	# Damage player who triggered it through GameManager
	if GameManager.player_stats:
		GameManager.player_stats.take_damage(damage)
	
	# Queue for deletion after brief visual delay
	await get_tree().create_timer(0.05).timeout
	queue_free()

func _create_explosion() -> void:
	"""Spawn the unified explosion effect."""
	var explosion := Explosion.new()
	explosion.global_position = global_position
	explosion.max_radius = explosion_radius
	explosion.damage = damage
	explosion.penetration = 0
	explosion.color_fill = Color(1.0, 0.5, 0.0, 0.7)   # Orange
	explosion.color_ring = Color(1.0, 0.8, 0.2, 0.9)   # Yellow
	get_parent().add_child(explosion)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_ref = body
		trigger()

func _draw() -> void:
	if _triggered:
		return

	# Draw mine body (circular spike pattern)
	draw_circle(Vector2.ZERO, mine_radius, mine_color)
	
	# Draw spike/prongs around the mine
	var spike_count := 8
	var spike_length := mine_radius * 0.6
	var spike_color := Color(mine_color.r * 0.6, mine_color.g * 0.6, mine_color.b * 0.6, 1.0)
	
	for i in spike_count:
		var angle := TAU * float(i) / float(spike_count)
		var start := Vector2(cos(angle), sin(angle)) * mine_radius
		var end := start + Vector2(cos(angle), sin(angle)) * spike_length
		draw_line(start, end, spike_color, 2.0)
	
	# Draw lighter circle in center for visibility
	var center_color := Color(mine_color.r * 1.3, mine_color.g * 1.3, mine_color.b * 1.3, 0.7)
	draw_circle(Vector2.ZERO, mine_radius * 0.4, center_color)
