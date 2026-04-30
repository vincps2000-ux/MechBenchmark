# gameplay.gd — Root controller for the Testing Area
# Player must destroy all targets to complete the course.
extends Node2D

const PLAYER_SCENE  := preload("res://scenes/player/player.tscn")
const TARGET_SCENE  := preload("res://scenes/enemies/shoot_target.tscn")
const WeaponHUD := preload("res://src/ui/weapon_hud.gd")
const VictoryScreen := preload("res://src/ui/victory_screen.gd")
const GameOverScreen := preload("res://src/ui/game_over_screen.gd")
const WIN_RETURN_DELAY := 2.0
const VICTORY_TITLE := "COURSE CLEAR"
const VICTORY_MESSAGE := "All targets destroyed. Returning to the workshop."
const GAME_OVER_SHOW_DELAY := 0.9
const GAME_OVER_RETURN_DELAY := 2.0
const GAME_OVER_TITLE := "MECH DESTROYED"
const GAME_OVER_MESSAGE := "Training mech lost. Returning to the workshop."

## Total number of targets the player must destroy to win.
@export var target_count: int = 10

## Arena boundary (half-size from origin in each direction)
const ARENA_HALF_SIZE := 1000.0
const WALL_THICKNESS  := 30.0

## Predefined target positions — spread across the arena, some behind obstacles.
## If target_count > this list, extras are placed randomly.
const TARGET_POSITIONS: Array[Vector2] = [
	Vector2(250,  -150),
	Vector2(-300,  200),
	Vector2(500,   350),
	Vector2(-450, -400),
	Vector2(100,   500),
	Vector2(-600,  -50),
	Vector2(650,  -300),
	Vector2(-200,  650),
	Vector2(400,  -550),
	Vector2(-550,  450),
	Vector2(0,    -700),
	Vector2(700,   100),
]

## Obstacle layout: [position, shape_type, rect_size, rotation_deg]
## Shape types: 0=CRATE, 1=WALL_H, 2=WALL_V, 3=BARREL, 4=L_SHAPE
const OBSTACLE_DEFS := [
	# Crates scattered around
	[Vector2(180, -80),   0, Vector2(50, 50),    0.0],
	[Vector2(-220, 130),  0, Vector2(60, 60),    15.0],
	[Vector2(380, 280),   0, Vector2(45, 45),    -10.0],
	# Horizontal walls — barriers player must go around
	[Vector2(0,   300),   1, Vector2(250, 30),   0.0],
	[Vector2(-350, -200), 1, Vector2(200, 30),   0.0],
	[Vector2(500,  0),    1, Vector2(180, 30),   25.0],
	# Vertical walls
	[Vector2(200,  -350), 2, Vector2(30, 200),   0.0],
	[Vector2(-500,  300), 2, Vector2(30, 160),   0.0],
	# Barrels
	[Vector2(-150, -350), 3, Vector2.ZERO,       0.0],
	[Vector2(350, -100),  3, Vector2.ZERO,       0.0],
	[Vector2(-400, 500),  3, Vector2.ZERO,       0.0],
	[Vector2(600, 450),   3, Vector2.ZERO,       0.0],
	# L-shapes
	[Vector2(-650, -350), 4, Vector2(120, 120),  0.0],
	[Vector2(300,  600),  4, Vector2(100, 100),  90.0],
]

@onready var background_rect: ColorRect  = %BackgroundRect
@onready var game_hud:        GameHUD    = %GameHUD
@onready var target_label:    Label       = %TargetLabel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _bg_material: ShaderMaterial
var _targets_node: Node2D
var _obstacles_node: Node2D
var _victory_screen: VictoryScreen
var _game_over_screen: GameOverScreen
var _alive_targets: int = 0
var _total_targets: int = 0
var _level_won: bool = false
var _stats: PlayerStats

func _ready() -> void:
	# Spawn the player at the world origin
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_player_camera = _player.get_node("Camera2D") as Camera2D

	_stats = GameManager.player_stats

	# Weapon toggle HUD (bottom-right)
	var weapon_hud := WeaponHUD.new()
	$HUD/HUDControl.add_child(weapon_hud)
	weapon_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weapon_hud.setup(_player)

	if background_rect and background_rect.material is ShaderMaterial:
		_bg_material = (background_rect.material as ShaderMaterial).duplicate()
		background_rect.material = _bg_material

	if _stats:
		game_hud.update_stats(_stats)

	# Background decorations
	var decorations := ArenaDecorations.new()
	decorations.arena_half_size = ARENA_HALF_SIZE
	add_child(decorations)

	# Blocking obstacles
	_obstacles_node = Node2D.new()
	_obstacles_node.name = "Obstacles"
	add_child(_obstacles_node)
	_spawn_obstacles()

	# Spawn finite set of targets
	_targets_node = Node2D.new()
	_targets_node.name = "Targets"
	add_child(_targets_node)
	_total_targets = target_count
	_spawn_all_targets()

	# Arena boundary walls and visuals
	_create_arena_bounds()

	_victory_screen = VictoryScreen.new()
	$HUD/HUDControl.add_child(_victory_screen)
	_victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_screen.configure(VICTORY_TITLE, VICTORY_MESSAGE, WIN_RETURN_DELAY)

	_game_over_screen = GameOverScreen.new()
	$HUD/HUDControl.add_child(_game_over_screen)
	_game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_screen.configure(GAME_OVER_TITLE, GAME_OVER_MESSAGE, GAME_OVER_RETURN_DELAY)

	var game_over_cb := Callable(self, "_on_game_over")
	if not GameManager.game_over.is_connected(game_over_cb):
		GameManager.game_over.connect(game_over_cb)

	_update_target_hud()
	queue_redraw()

func _process(_delta: float) -> void:
	_scroll_background()
	_update_hud()
	if _stats and _stats.is_dead():
		return

func _scroll_background() -> void:
	if not (_bg_material and is_instance_valid(_player_camera) and is_instance_valid(_player)):
		return
	var vp_size: Vector2    = get_viewport().get_visible_rect().size
	var zoom: float         = _player_camera.zoom.x
	var world_vp: Vector2   = vp_size / zoom
	var cam_offset: Vector2 = world_vp * 0.5
	_bg_material.set_shader_parameter("viewport_size",    world_vp)
	_bg_material.set_shader_parameter("camera_world_pos", _player.global_position - cam_offset)

func _update_hud() -> void:
	game_hud.update_stats(_stats)

func _update_target_hud() -> void:
	var destroyed := _total_targets - _alive_targets
	if target_label:
		target_label.text = "TARGETS  %d / %d" % [destroyed, _total_targets]

# ─── Target management ──────────────────────────────────────────────────────────

func _spawn_all_targets() -> void:
	for i in target_count:
		var pos: Vector2
		if i < TARGET_POSITIONS.size():
			pos = TARGET_POSITIONS[i]
		else:
			# Fallback: random position for extra targets
			var angle := randf_range(0.0, TAU)
			var dist  := randf_range(200.0, ARENA_HALF_SIZE * 0.85)
			pos = Vector2(cos(angle), sin(angle)) * dist

		var target := TARGET_SCENE.instantiate() as Area2D
		_targets_node.add_child(target)
		target.global_position = pos
		target.connect("destroyed", _on_target_destroyed)
		_alive_targets += 1

func _on_target_destroyed(_target: Node) -> void:
	_alive_targets -= 1
	_update_target_hud()
	if _alive_targets <= 0 and not _level_won:
		_trigger_win()

func _trigger_win() -> void:
	_level_won = true
	GameManager.is_running = false
	if _victory_screen:
		_victory_screen.show_victory()

func _on_game_over() -> void:
	if _level_won:
		return
	if _game_over_screen:
		_game_over_screen.show_game_over_delayed(GAME_OVER_SHOW_DELAY)

## External access — e.g. for tests
func get_alive_targets() -> int:
	return _alive_targets

func is_won() -> bool:
	return _level_won

# ─── Obstacles ───────────────────────────────────────────────────────────────────

func _spawn_obstacles() -> void:
	for def in OBSTACLE_DEFS:
		var obstacle := ArenaObstacle.new()
		obstacle.position   = def[0]
		obstacle.shape_type = def[1] as ArenaObstacle.Shape
		if def[1] != 3:   # non-barrel shapes use rect_size
			obstacle.rect_size = def[2]
		obstacle.rotation_degrees = def[3]
		_obstacles_node.add_child(obstacle)

# ─── Arena bounds ────────────────────────────────────────────────────────────────

func _create_arena_bounds() -> void:
	var bounds := Node2D.new()
	bounds.name = "ArenaBounds"
	add_child(bounds)

	var half := ARENA_HALF_SIZE
	var t    := WALL_THICKNESS
	var wall_defs := [
		[Vector2(0, -(half + t * 0.5)), Vector2((half + t) * 2, t)],
		[Vector2(0, half + t * 0.5),    Vector2((half + t) * 2, t)],
		[Vector2(-(half + t * 0.5), 0), Vector2(t, half * 2)],
		[Vector2(half + t * 0.5, 0),    Vector2(t, half * 2)],
	]

	for d in wall_defs:
		var wall := StaticBody2D.new()
		wall.position        = d[0]
		wall.collision_layer = 16
		wall.collision_mask  = 0
		var col  := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size  = d[1]
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
	var x := -half + tick_spacing
	while x < half:
		draw_line(Vector2(x, -half), Vector2(x, -half + tick_len), tick_color, 1.5)
		draw_line(Vector2(x,  half), Vector2(x,  half - tick_len), tick_color, 1.5)
		x += tick_spacing
	var y := -half + tick_spacing
	while y < half:
		draw_line(Vector2(-half, y), Vector2(-half + tick_len, y), tick_color, 1.5)
		draw_line(Vector2( half, y), Vector2( half - tick_len, y), tick_color, 1.5)
		y += tick_spacing
