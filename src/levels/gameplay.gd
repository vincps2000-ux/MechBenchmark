# gameplay.gd — Root controller for the Testing Area
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TARGET_SCENE := preload("res://scenes/enemies/shoot_target.tscn")

## How many targets to keep alive at once
const TARGET_COUNT   := 15
## Minimum / maximum spawn distance from the world origin
const SPAWN_DIST_MIN := 180.0
const SPAWN_DIST_MAX := 550.0

## Arena boundary (half-size from origin in each direction)
const ARENA_HALF_SIZE := 1000.0
const WALL_THICKNESS  := 30.0

@onready var background_rect: ColorRect  = %BackgroundRect
@onready var health_bar:      ProgressBar = %HealthBar
@onready var timer_label:     Label       = %TimerLabel
@onready var hp_label:        Label       = %HpLabel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _bg_material: ShaderMaterial
var _targets_node: Node2D   # container so targets don't clutter the root
var _alive_targets: int = 0
var _stats: PlayerStats     # cached reference — avoids repeated autoload lookup per frame

func _ready() -> void:
	# Spawn the player at the world origin
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_player_camera = _player.get_node("Camera2D") as Camera2D

	# Cache stats reference once; GameManager owns the object and it lives for the run
	_stats = GameManager.player_stats

	# Duplicate the material so we own a local instance — avoids flicker from
	# modifying a shared sub-resource every frame.
	if background_rect and background_rect.material is ShaderMaterial:
		_bg_material = (background_rect.material as ShaderMaterial).duplicate()
		background_rect.material = _bg_material

	# Init HUD health bar from stats
	if _stats:
		health_bar.max_value = _stats.max_health
		health_bar.value     = _stats.health
		hp_label.text        = "%d / %d" % [_stats.health, _stats.max_health]

	# Spawn shootable target range
	_targets_node = Node2D.new()
	_targets_node.name = "Targets"
	add_child(_targets_node)
	for _i in TARGET_COUNT:
		_spawn_target()

	# Create arena boundary walls and visuals
	_create_arena_bounds()
	queue_redraw()

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
	if not _stats:
		return
	health_bar.value = _stats.health
	hp_label.text    = "%d / %d" % [_stats.health, _stats.max_health]
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

# ─── Arena bounds ────────────────────────────────────────────────────────────────

func _create_arena_bounds() -> void:
	var bounds := Node2D.new()
	bounds.name = "ArenaBounds"
	add_child(bounds)

	# [position , full_size] for each wall segment
	var half := ARENA_HALF_SIZE
	var t    := WALL_THICKNESS
	var wall_defs := [
		# top
		[Vector2(0, -(half + t * 0.5)), Vector2((half + t) * 2, t)],
		# bottom
		[Vector2(0, half + t * 0.5),    Vector2((half + t) * 2, t)],
		# left
		[Vector2(-(half + t * 0.5), 0), Vector2(t, half * 2)],
		# right
		[Vector2(half + t * 0.5, 0),    Vector2(t, half * 2)],
	]

	for def in wall_defs:
		var wall := StaticBody2D.new()
		wall.position        = def[0]
		wall.collision_layer = 16   # physics layer 5 (environment)
		wall.collision_mask  = 0
		var col  := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size  = def[1]
		col.shape  = rect
		wall.add_child(col)
		bounds.add_child(wall)

func _draw() -> void:
	var half := ARENA_HALF_SIZE
	var arena_rect := Rect2(-half, -half, half * 2, half * 2)

	# Outer glow
	var glow := Color(0.9, 0.55, 0.1, 0.1)
	draw_rect(Rect2(-half - 18, -half - 18, (half + 18) * 2, (half + 18) * 2), glow, false, 36.0)

	# Main boundary
	var boundary := Color(0.9, 0.55, 0.1, 0.65)
	draw_rect(arena_rect, boundary, false, 4.0)

	# Inner warning line
	var warning := Color(0.95, 0.3, 0.1, 0.2)
	var inset   := 25.0
	draw_rect(Rect2(-half + inset, -half + inset, (half - inset) * 2, (half - inset) * 2), warning, false, 2.0)

	# Corner brackets
	var bracket_len   := 80.0
	var bracket_color := Color(0.95, 0.7, 0.15, 0.85)
	var corners := [
		[Vector2(-half, -half), Vector2(1, 0), Vector2(0, 1)],
		[Vector2( half, -half), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(-half,  half), Vector2(1, 0), Vector2(0, -1)],
		[Vector2( half,  half), Vector2(-1, 0), Vector2(0, -1)],
	]
	for c in corners:
		draw_line(c[0], c[0] + c[1] * bracket_len, bracket_color, 3.0)
		draw_line(c[0], c[0] + c[2] * bracket_len, bracket_color, 3.0)

	# Hazard tick marks along each edge
	var tick_spacing := 100.0
	var tick_len     := 12.0
	var tick_color   := Color(0.9, 0.6, 0.1, 0.35)
	# Top & bottom edges
	var x := -half + tick_spacing
	while x < half:
		draw_line(Vector2(x, -half), Vector2(x, -half + tick_len), tick_color, 1.5)
		draw_line(Vector2(x,  half), Vector2(x,  half - tick_len), tick_color, 1.5)
		x += tick_spacing
	# Left & right edges
	var y := -half + tick_spacing
	while y < half:
		draw_line(Vector2(-half, y), Vector2(-half + tick_len, y), tick_color, 1.5)
		draw_line(Vector2( half, y), Vector2( half - tick_len, y), tick_color, 1.5)
		y += tick_spacing
