# gameplay.gd — Root controller for the main gameplay scene
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TARGET_SCENE := preload("res://scenes/enemies/shoot_target.tscn")

## How many targets to keep alive at once
const TARGET_COUNT   := 15
## Minimum / maximum spawn distance from the world origin
const SPAWN_DIST_MIN := 180.0
const SPAWN_DIST_MAX := 550.0

@onready var background_rect: ColorRect  = %BackgroundRect
@onready var health_bar:      ProgressBar = %HealthBar
@onready var timer_label:     Label       = %TimerLabel
@onready var hp_label:        Label       = %HpLabel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _bg_material: ShaderMaterial
var _targets_node: Node2D   # container so targets don't clutter the root
var _alive_targets: int = 0

func _ready() -> void:
	# Spawn the player at the world origin
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_player_camera = _player.get_node("Camera2D") as Camera2D

	# Duplicate the material so we own a local instance — avoids flicker from
	# modifying a shared sub-resource every frame.
	if background_rect and background_rect.material is ShaderMaterial:
		_bg_material = (background_rect.material as ShaderMaterial).duplicate()
		background_rect.material = _bg_material

	# Init HUD health bar from stats
	var stats: PlayerStats = GameManager.player_stats
	if stats:
		health_bar.max_value = stats.max_health
		health_bar.value     = stats.health
		hp_label.text        = "%d / %d" % [stats.health, stats.max_health]

	# Spawn shootable target range
	_targets_node = Node2D.new()
	_targets_node.name = "Targets"
	add_child(_targets_node)
	for _i in TARGET_COUNT:
		_spawn_target()

func _process(_delta: float) -> void:
	_scroll_background()
	_update_hud()

# Passes the top-left world corner to the shader so the grid tiles correctly.
# viewport_size must be in WORLD units (screen pixels / zoom) so that UV→world
# conversion inside the shader matches the actual camera projection.
func _scroll_background() -> void:
	if not (_bg_material and _player_camera):
		return
	var vp_size: Vector2    = get_viewport().get_visible_rect().size
	var zoom: float         = _player_camera.zoom.x
	var world_vp: Vector2   = vp_size / zoom          # world units visible on screen
	var cam_offset: Vector2 = world_vp * 0.5          # half that = top-left offset
	_bg_material.set_shader_parameter("viewport_size",    world_vp)
	_bg_material.set_shader_parameter("camera_world_pos", _player.global_position - cam_offset)

func _update_hud() -> void:
	var stats: PlayerStats = GameManager.player_stats
	if not stats:
		return
	health_bar.value = stats.health
	hp_label.text    = "%d / %d" % [stats.health, stats.max_health]
	timer_label.text = GameManager.get_game_time_formatted()

# ─── Target management ──────────────────────────────────────────────────────────
func _spawn_target() -> void:
	var angle  := randf_range(0.0, TAU)
	var dist   := randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
	var pos    := Vector2(cos(angle), sin(angle)) * dist

	var target := TARGET_SCENE.instantiate() as Area2D
	_targets_node.add_child(target)
	target.global_position = pos
	target.connect("destroyed", _on_target_destroyed)
	_alive_targets += 1

func _on_target_destroyed(_target: Node) -> void:
	_alive_targets -= 1
	# Respawn a fresh target after a short delay so the range never empties
	get_tree().create_timer(0.6).timeout.connect(_spawn_target, CONNECT_ONE_SHOT)
