# level_1.gd — Level 1: "Urban Surprise"
# City-block arena with ambush enemy waves, mission objectives,
# and urban environment obstacles (buildings, cars, dumpsters, barricades).
extends Node2D

const PLAYER_SCENE  := preload("res://scenes/player/player.tscn")
const ENEMY_INFANTRY_SCENE := preload("res://scenes/enemies/enemy_infantry.tscn")
const WeaponHUD := preload("res://src/ui/weapon_hud.gd")

## Arena boundary (half-size from origin in each direction)
const ARENA_HALF_SIZE := 1200.0
const WALL_THICKNESS  := 30.0

# ─── Mission objectives ─────────────────────────────────────────────────────────
## Total waves in this level
const TOTAL_WAVES := 3

## Enemy counts per wave (escalating)
const WAVE_ENEMY_COUNTS: Array[int] = [4, 6, 10]

## Seconds between waves
const WAVE_DELAY := 3.0

## XP per infantry kill
const XP_PER_KILL := 5

## Ambush spawn directions per wave — enemies come from unexpected angles
## Each sub-array contains Vector2 *directions* (normalised) from which the wave spawns.
const WAVE_SPAWN_DIRS: Array[Array] = [
	# Wave 1: enemies from the north alley
	[Vector2(0.5, -1), Vector2(-0.5, -1), Vector2(0, -1), Vector2(0.8, -0.6)],
	# Wave 2: surprise flank from east + west
	[Vector2(1, 0.3), Vector2(1, -0.3), Vector2(-1, 0.3), Vector2(-1, -0.3), Vector2(1, 0), Vector2(-1, 0)],
	# Wave 3: full surround — the big surprise
	[Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	 Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7),
	 Vector2(0.3, 1), Vector2(-0.3, -1)],
]

## Spawn distance from player (enemies appear from off-screen via streets)
const SPAWN_DISTANCE_MIN := 500.0
const SPAWN_DISTANCE_MAX := 800.0

# ─── Urban obstacle layout ──────────────────────────────────────────────────────
## Road grid: block_size = 480, road_width = 90.  Roads are 180px bands centered
## at multiples of 480 in both axes.  Sidewalk blocks sit between them.
## Cars are placed on road shoulders; everything else lives on the sidewalk.
## [position, shape_type (UrbanObstacle.Shape), rect_size, rotation_deg]
const OBSTACLE_DEFS := [
	# ── Buildings (sidewalk blocks, between road bands) ────────────────────────
	[Vector2(-240, -240),  0, Vector2(160, 140), 0.0],
	[Vector2(240, -240),   0, Vector2(130, 170), 0.0],
	[Vector2(-720, -240),  0, Vector2(140, 130), 0.0],
	[Vector2(720, 240),    0, Vector2(180, 150), 0.0],
	[Vector2(-240, 720),   0, Vector2(140, 160), 0.0],
	[Vector2(240, 720),    0, Vector2(200, 120), 0.0],
	[Vector2(-720, -720),  0, Vector2(120, 180), 0.0],
	# ── Cars (parked on road shoulders, within ±90 of road centre lines) ──────
	# Horizontal road y ≈ 0
	[Vector2(-300, -55),   1, Vector2(80, 40), 0.0],
	[Vector2(350, 55),     1, Vector2(80, 40), 5.0],
	# Vertical road x ≈ 0
	[Vector2(55, -350),    1, Vector2(80, 40), 90.0],
	[Vector2(-55, 300),    1, Vector2(75, 38), 90.0],
	# Horizontal road y ≈ -480
	[Vector2(-600, -535),  1, Vector2(80, 40), 0.0],
	[Vector2(550, -430),   1, Vector2(80, 40), -5.0],
	# Horizontal road y ≈ 480
	[Vector2(200, 530),    1, Vector2(80, 40), 10.0],
	[Vector2(-550, 435),   1, Vector2(70, 35), 0.0],
	# Vertical road x ≈ -480
	[Vector2(-535, 200),   1, Vector2(80, 40), 90.0],
	[Vector2(-430, -600),  1, Vector2(75, 38), 85.0],
	# Vertical road x ≈ 480
	[Vector2(535, -200),   1, Vector2(80, 40), 90.0],
	[Vector2(430, 600),    1, Vector2(80, 40), 90.0],
	# ── Dumpsters (sidewalk, near buildings) ──────────────────────────────────
	[Vector2(-340, -170),  2, Vector2(50, 35), 0.0],
	[Vector2(340, -330),   2, Vector2(50, 35), 0.0],
	[Vector2(-630, -320),  2, Vector2(45, 30), 10.0],
	[Vector2(830, 340),    2, Vector2(50, 35), -5.0],
	# ── Barricades (on roads, blocking lanes) ─────────────────────────────────
	[Vector2(0, 20),       3, Vector2(120, 18), 90.0],
	[Vector2(-200, 0),     3, Vector2(100, 18), 0.0],
	[Vector2(480, -300),   3, Vector2(100, 18), 0.0],
	[Vector2(100, -480),   3, Vector2(140, 18), 90.0],
	# ── Bus stops (sidewalk edge, near road) ──────────────────────────────────
	[Vector2(-150, -100),  4, Vector2(60, 20), 0.0],
	[Vector2(150, 380),    4, Vector2(60, 20), 0.0],
	# ── Lampposts (sidewalk side of road edges) ──────────────────────────────
	[Vector2(-120, -100),  5, Vector2.ZERO, 0.0],
	[Vector2(110, 100),    5, Vector2.ZERO, 0.0],
	[Vector2(-90, 383),    5, Vector2.ZERO, 0.0],
	[Vector2(105, -385),   5, Vector2.ZERO, 0.0],
	[Vector2(383, 95),     5, Vector2.ZERO, 0.0],
	[Vector2(-385, -110),  5, Vector2.ZERO, 0.0],
]

# ─── Node refs ───────────────────────────────────────────────────────────────────
@onready var background_rect: ColorRect    = %BackgroundRect
@onready var game_hud:        GameHUD      = %GameHUD
@onready var objective_label: Label         = %ObjectiveLabel
@onready var wave_label:      Label         = %WaveLabel
@onready var win_panel:       PanelContainer = %WinPanel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _bg_material: ShaderMaterial
var _stats: PlayerStats
var _enemies_node: Node2D
var _obstacles_node: Node2D

# ─── State ────────────────────────────────────────────────────────────────────
var _current_wave: int = 0        # 0 = not started yet
var _enemies_alive: int = 0
var _total_killed: int = 0
var _wave_active: bool = false
var _level_won: bool = false
var _wave_delay_timer: float = 0.0
var _waiting_for_wave: bool = false

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

	# Urban background decorations
	var decorations := UrbanDecorations.new()
	decorations.arena_half_size = ARENA_HALF_SIZE
	add_child(decorations)

	# Blocking obstacles (buildings, cars, etc.)
	_obstacles_node = Node2D.new()
	_obstacles_node.name = "Obstacles"
	add_child(_obstacles_node)
	_spawn_obstacles()

	# Enemy container
	_enemies_node = Node2D.new()
	_enemies_node.name = "Enemies"
	add_child(_enemies_node)

	# Arena boundary walls
	_create_arena_bounds()

	# Hide win panel
	if win_panel:
		win_panel.visible = false

	_update_objective_hud()

	# Kick off first wave after brief delay
	_waiting_for_wave = true
	_wave_delay_timer = 1.5  # short lead-in

	queue_redraw()

func _process(delta: float) -> void:
	_scroll_background()
	_update_hud()

	# Wave progression
	if _waiting_for_wave:
		_wave_delay_timer -= delta
		if _wave_delay_timer <= 0.0:
			_waiting_for_wave = false
			_start_next_wave()

func _scroll_background() -> void:
	if not (_bg_material and _player_camera):
		return
	var vp_size: Vector2    = get_viewport().get_visible_rect().size
	var zoom: float         = _player_camera.zoom.x
	var world_vp: Vector2   = vp_size / zoom
	var cam_offset: Vector2 = world_vp * 0.5
	_bg_material.set_shader_parameter("viewport_size",    world_vp)
	_bg_material.set_shader_parameter("camera_world_pos", _player.global_position - cam_offset)

func _update_hud() -> void:
	game_hud.update_stats(_stats)
	_update_objective_hud()

func _update_objective_hud() -> void:
	if objective_label:
		if _level_won:
			objective_label.text = "MISSION COMPLETE"
		elif _current_wave == 0:
			objective_label.text = "Prepare for contact..."
		else:
			objective_label.text = "Hostiles remaining: %d" % _enemies_alive
	if wave_label:
		if _level_won:
			wave_label.text = "All waves cleared!"
		elif _current_wave > 0:
			wave_label.text = "WAVE %d / %d" % [_current_wave, TOTAL_WAVES]
		else:
			wave_label.text = "URBAN SURPRISE"

# ─── Wave management ────────────────────────────────────────────────────────────

func _start_next_wave() -> void:
	_current_wave += 1
	if _current_wave > TOTAL_WAVES:
		_trigger_win()
		return

	_wave_active = true
	var count: int = WAVE_ENEMY_COUNTS[_current_wave - 1] if _current_wave - 1 < WAVE_ENEMY_COUNTS.size() else 8
	var dirs: Array = WAVE_SPAWN_DIRS[_current_wave - 1] if _current_wave - 1 < WAVE_SPAWN_DIRS.size() else [Vector2(1,0)]
	_spawn_wave(count, dirs)
	_update_objective_hud()

	# Flash "SURPRISE!" for ambush waves (wave 2+)
	if _current_wave >= 2 and wave_label:
		_flash_surprise()

func _spawn_wave(count: int, directions: Array) -> void:
	var player_pos := _player.global_position if is_instance_valid(_player) else Vector2.ZERO
	for i in count:
		var dir_idx := i % directions.size()
		var dir: Vector2 = (directions[dir_idx] as Vector2).normalized()
		var dist := randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
		var spread := randf_range(-0.3, 0.3)  # slight random spread
		var spawn_dir := dir.rotated(spread)
		var spawn_pos := player_pos + spawn_dir * dist

		# Clamp within arena
		spawn_pos.x = clampf(spawn_pos.x, -ARENA_HALF_SIZE + 50, ARENA_HALF_SIZE - 50)
		spawn_pos.y = clampf(spawn_pos.y, -ARENA_HALF_SIZE + 50, ARENA_HALF_SIZE - 50)

		var enemy: CharacterBody2D = ENEMY_INFANTRY_SCENE.instantiate()
		enemy.global_position = spawn_pos
		enemy.died.connect(_on_enemy_died)
		_enemies_node.add_child(enemy)
		_enemies_alive += 1
		GameManager.enemies_alive += 1

func _on_enemy_died(_enemy: EnemyInfantry) -> void:
	_enemies_alive -= 1
	_total_killed += 1
	GameManager.on_enemy_killed(XP_PER_KILL)

	if _enemies_alive <= 0 and _wave_active:
		_wave_active = false
		if _current_wave >= TOTAL_WAVES:
			_trigger_win()
		else:
			# Queue next wave after delay
			_waiting_for_wave = true
			_wave_delay_timer = WAVE_DELAY

func _trigger_win() -> void:
	_level_won = true
	GameManager.is_running = false
	_update_objective_hud()
	if win_panel:
		win_panel.visible = true

func _flash_surprise() -> void:
	if not wave_label:
		return
	var original_text := wave_label.text
	var original_color: Color = wave_label.get("theme_override_colors/font_color")
	wave_label.text = "!! SURPRISE !!"
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.15, 1.0))
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(func():
		wave_label.text = original_text
		if original_color:
			wave_label.add_theme_color_override("font_color", original_color)
		else:
			wave_label.remove_theme_color_override("font_color")
	)

# ─── External access — for tests ────────────────────────────────────────────────
func get_enemies_alive() -> int:
	return _enemies_alive

func get_total_killed() -> int:
	return _total_killed

func get_current_wave() -> int:
	return _current_wave

func is_won() -> bool:
	return _level_won

# ─── Obstacles ───────────────────────────────────────────────────────────────────

func _spawn_obstacles() -> void:
	for def in OBSTACLE_DEFS:
		var obstacle := UrbanObstacle.new()
		obstacle.position   = def[0]
		obstacle.shape_type = def[1] as UrbanObstacle.Shape
		if def[1] != 5:  # lampposts don't use rect_size
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

	# Outer glow — urban orange/red
	var glow := Color(0.8, 0.25, 0.1, 0.08)
	draw_rect(Rect2(-half - 18, -half - 18, (half + 18) * 2, (half + 18) * 2), glow, false, 36.0)

	# Main boundary — chain-link fence style
	var boundary := Color(0.5, 0.5, 0.5, 0.5)
	draw_rect(arena_rect, boundary, false, 3.0)
	# Inner boundary
	draw_rect(Rect2(-half + 4, -half + 4, (half - 4) * 2, (half - 4) * 2), Color(0.5, 0.5, 0.5, 0.25), false, 1.5)

	# Danger tape corners
	var bracket_len   := 90.0
	var bracket_color := Color(0.9, 0.3, 0.1, 0.75)
	var corners := [
		[Vector2(-half, -half), Vector2(1, 0), Vector2(0, 1)],
		[Vector2( half, -half), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(-half,  half), Vector2(1, 0), Vector2(0, -1)],
		[Vector2( half,  half), Vector2(-1, 0), Vector2(0, -1)],
	]
	for c in corners:
		draw_line(c[0], c[0] + c[1] * bracket_len, bracket_color, 4.0)
		draw_line(c[0], c[0] + c[2] * bracket_len, bracket_color, 4.0)

	# "RESTRICTED AREA" tick marks along boundary
	var tick_spacing := 80.0
	var tick_len     := 10.0
	var tick_color   := Color(0.7, 0.3, 0.1, 0.3)
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
