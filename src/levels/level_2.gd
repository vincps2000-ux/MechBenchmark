# level_2.gd — Level 2: "Storm the Trenches"
# A long vertical battlefield where the player advances north to extraction.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_INFANTRY_SCENE := preload("res://scenes/enemies/enemy_infantry.tscn")
const WeaponHUD := preload("res://src/ui/weapon_hud.gd")
const VictoryScreen := preload("res://src/ui/victory_screen.gd")
const TrenchObstacle := preload("res://src/levels/trench_obstacle.gd")
const MudPit := preload("res://src/levels/mud_pit.gd")
const Mine := preload("res://src/levels/mine.gd")
const WIN_RETURN_DELAY := 2.0
const VICTORY_TITLE := "EXTRACTION REACHED"
const VICTORY_MESSAGE := "You broke through the trench line. Returning to workshop."

const ARENA_HALF_WIDTH := 900.0
const WALL_THICKNESS := 30.0

# Total playable height is 3 screens.
const SCREENS_TALL := 3.0

# Objective trigger near the top edge.
const GOAL_REACH_BUFFER := 80.0

# Enemy plan: a front-loaded opening wave, then pressure from the top edge.
const INITIAL_ENEMY_COUNT := 10
const TOP_EDGE_SPAWN_INTERVAL := 5.0
const TOP_EDGE_SPAWN_BATCH := 1
const MAX_ENEMIES_ALIVE := 20
const TOP_EDGE_SPAWN_INSET := 90.0
const SPAWN_X_MARGIN := 110.0

const XP_PER_KILL := 5

@onready var background_rect: ColorRect = %BackgroundRect
@onready var game_hud: GameHUD = %GameHUD
@onready var objective_label: Label = %ObjectiveLabel
@onready var mission_label: Label = %MissionLabel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _stats: PlayerStats
var _bg_material: ShaderMaterial

var _enemies_node: Node2D
var _victory_screen: VictoryScreen
var _arena_half_height: float = 1500.0

var _level_won := false
var _enemies_alive := 0
var _spawn_timer := 0.0

func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player_camera = _player.get_node("Camera2D") as Camera2D

	_arena_half_height = _compute_arena_half_height()
	_player.global_position = Vector2(0.0, _arena_half_height - 140.0)

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

	_enemies_node = Node2D.new()
	_enemies_node.name = "Enemies"
	add_child(_enemies_node)

	_create_arena_bounds()
	_create_obstacles()
	_create_mud_pits()
	_create_mines()
	_spawn_initial_enemies()

	_spawn_timer = TOP_EDGE_SPAWN_INTERVAL

	_victory_screen = VictoryScreen.new()
	$HUD/HUDControl.add_child(_victory_screen)
	_victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_screen.configure(VICTORY_TITLE, VICTORY_MESSAGE, WIN_RETURN_DELAY)

	_update_objective_hud()
	queue_redraw()

func _process(delta: float) -> void:
	_scroll_background()
	_update_hud()

	if _level_won:
		return

	if is_instance_valid(_player):
		if _player.global_position.y <= -_arena_half_height + GOAL_REACH_BUFFER:
			_trigger_win()
			return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = TOP_EDGE_SPAWN_INTERVAL
		if _enemies_alive < MAX_ENEMIES_ALIVE:
			for _i in TOP_EDGE_SPAWN_BATCH:
				_spawn_top_edge_enemy()

func _compute_arena_half_height() -> float:
	if not is_instance_valid(_player_camera):
		return 1500.0
	var viewport_height := get_viewport().get_visible_rect().size.y
	var zoom_y := maxf(_player_camera.zoom.y, 0.001)
	var world_screen_height := viewport_height / zoom_y
	# Half-height = 1.5x one screen -> 3 screens total.
	return maxf(900.0, world_screen_height * (SCREENS_TALL * 0.5))

func _scroll_background() -> void:
	if not (_bg_material and _player_camera and is_instance_valid(_player)):
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = _player_camera.zoom.x
	var world_vp: Vector2 = vp_size / zoom
	var cam_offset: Vector2 = world_vp * 0.5
	_bg_material.set_shader_parameter("viewport_size", world_vp)
	_bg_material.set_shader_parameter("camera_world_pos", _player.global_position - cam_offset)

func _update_hud() -> void:
	game_hud.update_stats(_stats)
	_update_objective_hud()

func _update_objective_hud() -> void:
	if objective_label:
		if _level_won:
			objective_label.text = "MISSION COMPLETE"
		else:
			var distance_to_top := maxf(0.0, _player.global_position.y + _arena_half_height)
			objective_label.text = "Advance north: %.0f m to extraction" % distance_to_top
	if mission_label:
		if _level_won:
			mission_label.text = "Trenches secured"
		else:
			mission_label.text = "Enemy pressure from the north edge"

func _create_obstacles() -> void:
	var obstacles_node := Node2D.new()
	obstacles_node.name = "Obstacles"
	add_child(obstacles_node)

	# Each entry: [shape, position, size]
	# Layout spans from near-bottom (y ~ +half_h - 350) to near-top (y ~ -half_h + 220)
	# Row 1 — first defensive line the player encounters
	var half_h := _arena_half_height
	var defs: Array = [
		# Row 1 — low trench line
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2(-480.0,  half_h - 360.0), Vector2(180, 32)],
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2(-160.0,  half_h - 360.0), Vector2(200, 32)],
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2( 200.0,  half_h - 360.0), Vector2(180, 32)],
		[TrenchObstacle.Shape.BUNKER,       Vector2( 500.0,  half_h - 370.0), Vector2(110, 70)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2(-650.0,  half_h - 430.0), Vector2(140, 24)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2(  60.0,  half_h - 430.0), Vector2(120, 24)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2( 650.0,  half_h - 430.0), Vector2(140, 24)],
		# Row 2 — mid-field debris
		[TrenchObstacle.Shape.WRECKAGE,     Vector2(-550.0,  half_h * 0.25),   Vector2(120, 55)],
		[TrenchObstacle.Shape.WRECKAGE,     Vector2( 380.0,  half_h * 0.20),   Vector2(140, 55)],
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2(-100.0,  half_h * 0.18),   Vector2(160, 32)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2(-700.0,  half_h * 0.10),   Vector2(130, 24)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2( 620.0,  half_h * 0.10),   Vector2(130, 24)],
		# Row 3 — upper defensive line
		[TrenchObstacle.Shape.BUNKER,       Vector2(-580.0, -half_h * 0.25),   Vector2(110, 70)],
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2(-260.0, -half_h * 0.28),   Vector2(200, 32)],
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2( 120.0, -half_h * 0.28),   Vector2(180, 32)],
		[TrenchObstacle.Shape.BUNKER,       Vector2( 560.0, -half_h * 0.25),   Vector2(110, 70)],
		[TrenchObstacle.Shape.WRECKAGE,     Vector2(  -40.0, -half_h * 0.50),  Vector2(130, 55)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2(-720.0, -half_h * 0.55),   Vector2(130, 24)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2(  80.0, -half_h * 0.52),   Vector2(120, 24)],
		[TrenchObstacle.Shape.BARBED_WIRE,  Vector2( 680.0, -half_h * 0.55),   Vector2(130, 24)],
		# Row 4 — near extraction
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2(-500.0, -half_h + 280.0),  Vector2(160, 32)],
		[TrenchObstacle.Shape.SANDBAG_WALL, Vector2( 100.0, -half_h + 280.0),  Vector2(160, 32)],
		[TrenchObstacle.Shape.WRECKAGE,     Vector2( 650.0, -half_h + 290.0),  Vector2(120, 55)],
	]

	for d in defs:
		var obs := TrenchObstacle.new()
		obs.shape_type = d[0]
		obs.rect_size  = d[2]
		obs.global_position = d[1]
		obstacles_node.add_child(obs)

func _create_mud_pits() -> void:
	var mud_node := Node2D.new()
	mud_node.name = "MudPits"
	add_child(mud_node)

	var half_h := _arena_half_height
	# Each entry: [position, radii (rx, ry)]
	var pits: Array = [
		# --- southern third ---
		[Vector2(-480.0,  half_h - 480.0), Vector2(90,  65)],
		[Vector2(-180.0,  half_h - 510.0), Vector2(75,  55)],
		[Vector2( 120.0,  half_h - 490.0), Vector2(100, 70)],
		[Vector2( 460.0,  half_h - 500.0), Vector2(80,  60)],
		[Vector2( 720.0,  half_h - 460.0), Vector2(70,  55)],
		[Vector2(-720.0,  half_h - 550.0), Vector2(75,  50)],
		[Vector2(-350.0,  half_h - 640.0), Vector2(95,  70)],
		[Vector2(  60.0,  half_h - 650.0), Vector2(85,  60)],
		[Vector2( 560.0,  half_h - 620.0), Vector2(100, 75)],
		[Vector2(-680.0,  half_h - 720.0), Vector2(80,  55)],
		[Vector2( 300.0,  half_h - 750.0), Vector2(90,  65)],
		[Vector2( 720.0,  half_h - 700.0), Vector2(75,  55)],
		# --- middle third ---
		[Vector2(-600.0,  half_h * 0.30),  Vector2(110, 75)],
		[Vector2(-280.0,  half_h * 0.28),  Vector2(90,  65)],
		[Vector2(  80.0,  half_h * 0.32),  Vector2(100, 70)],
		[Vector2( 420.0,  half_h * 0.25),  Vector2(85,  60)],
		[Vector2( 740.0,  half_h * 0.30),  Vector2(75,  50)],
		[Vector2(-750.0,  half_h * 0.10),  Vector2(80,  60)],
		[Vector2(-420.0,  half_h * 0.08),  Vector2(95,  70)],
		[Vector2(  -60.0, half_h * 0.05),  Vector2(110, 80)],
		[Vector2( 280.0,  half_h * 0.02),  Vector2(90,  65)],
		[Vector2( 620.0,  half_h * 0.08),  Vector2(80,  55)],
		[Vector2(-580.0, -half_h * 0.10),  Vector2(100, 70)],
		[Vector2(-200.0, -half_h * 0.12),  Vector2(85,  60)],
		[Vector2( 180.0, -half_h * 0.10),  Vector2(95,  68)],
		[Vector2( 560.0, -half_h * 0.12),  Vector2(80,  58)],
		[Vector2( 760.0, -half_h * 0.05),  Vector2(70,  50)],
		# --- upper middle ---
		[Vector2(-740.0, -half_h * 0.28),  Vector2(85,  60)],
		[Vector2(-400.0, -half_h * 0.30),  Vector2(100, 70)],
		[Vector2( -60.0, -half_h * 0.32),  Vector2(90,  65)],
		[Vector2( 320.0, -half_h * 0.28),  Vector2(95,  68)],
		[Vector2( 680.0, -half_h * 0.30),  Vector2(80,  55)],
		[Vector2(-560.0, -half_h * 0.46),  Vector2(110, 78)],
		[Vector2(-160.0, -half_h * 0.48),  Vector2(90,  65)],
		[Vector2( 220.0, -half_h * 0.46),  Vector2(85,  60)],
		[Vector2( 600.0, -half_h * 0.48),  Vector2(95,  68)],
		# --- northern third ---
		[Vector2(-720.0, -half_h * 0.62),  Vector2(90,  65)],
		[Vector2(-380.0, -half_h * 0.60),  Vector2(100, 72)],
		[Vector2(   0.0, -half_h * 0.63),  Vector2(85,  60)],
		[Vector2( 360.0, -half_h * 0.60),  Vector2(95,  68)],
		[Vector2( 700.0, -half_h * 0.62),  Vector2(80,  55)],
		[Vector2(-540.0, -half_h * 0.76),  Vector2(95,  70)],
		[Vector2(-160.0, -half_h * 0.78),  Vector2(85,  62)],
		[Vector2( 220.0, -half_h * 0.76),  Vector2(100, 72)],
		[Vector2( 600.0, -half_h * 0.78),  Vector2(80,  56)],
		[Vector2(-700.0, -half_h * 0.88),  Vector2(75,  54)],
		[Vector2(-300.0, -half_h * 0.88),  Vector2(90,  65)],
		[Vector2( 100.0, -half_h * 0.90),  Vector2(95,  68)],
		[Vector2( 480.0, -half_h * 0.88),  Vector2(80,  58)],
		[Vector2( 760.0, -half_h * 0.85),  Vector2(70,  50)],
	]

	for p in pits:
		var pit := MudPit.new()
		pit.radii = p[1]
		pit.global_position = p[0]
		mud_node.add_child(pit)

func _create_mines() -> void:
	var mines_node := Node2D.new()
	mines_node.name = "Mines"
	add_child(mines_node)

	var half_h := _arena_half_height
	# Each entry: [position] — mines placed at strategic locations in the trenches
	# Concentrated around defensive lines and narrow passages
	var mine_positions: Array = [
		# --- southern defenses (first wave) ---
		Vector2(-420.0,  half_h - 380.0),
		Vector2( 160.0,  half_h - 380.0),
		Vector2( 540.0,  half_h - 390.0),
		Vector2(-250.0,  half_h - 520.0),
		Vector2( 380.0,  half_h - 540.0),
		Vector2( 720.0,  half_h - 520.0),
		
		# --- middle field (approaching defenses) ---
		Vector2(-520.0,  half_h * 0.22),
		Vector2( 420.0,  half_h * 0.18),
		Vector2(-120.0,  half_h * 0.15),
		Vector2( 680.0,  half_h * 0.12),
		Vector2(-680.0,  half_h * 0.05),
		Vector2( 280.0, -half_h * 0.02),
		
		# --- upper defenses (beyond bunkers) ---
		Vector2(-640.0, -half_h * 0.26),
		Vector2( 600.0, -half_h * 0.26),
		Vector2(-300.0, -half_h * 0.32),
		Vector2( 140.0, -half_h * 0.30),
		Vector2( 520.0, -half_h * 0.34),
		
		# --- northern approach (leading to extraction) ---
		Vector2(-480.0, -half_h * 0.58),
		Vector2(  80.0, -half_h * 0.60),
		Vector2( 620.0, -half_h * 0.62),
		Vector2(-280.0, -half_h * 0.80),
		Vector2( 340.0, -half_h * 0.82),
	]

	for mine_pos in mine_positions:
		var mine := Mine.new()
		mine.global_position = mine_pos
		mines_node.add_child(mine)

func _spawn_initial_enemies() -> void:
	for i in INITIAL_ENEMY_COUNT:
		var t := float(i) / float(max(INITIAL_ENEMY_COUNT - 1, 1))
		var y := lerpf(-_arena_half_height + 260.0, 200.0, t)
		var x := randf_range(-ARENA_HALF_WIDTH + 100.0, ARENA_HALF_WIDTH - 100.0)
		_spawn_enemy(Vector2(x, y))

func _spawn_top_edge_enemy() -> void:
	var x := randf_range(-ARENA_HALF_WIDTH + SPAWN_X_MARGIN, ARENA_HALF_WIDTH - SPAWN_X_MARGIN)
	var y := -_arena_half_height + TOP_EDGE_SPAWN_INSET
	_spawn_enemy(Vector2(x, y))

func _spawn_enemy(pos: Vector2) -> void:
	var enemy := ENEMY_INFANTRY_SCENE.instantiate() as CharacterBody2D
	enemy.global_position = pos
	enemy.died.connect(_on_enemy_died)
	_enemies_node.add_child(enemy)
	_enemies_alive += 1
	GameManager.enemies_alive += 1

func _on_enemy_died(_enemy: EnemyInfantry) -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	GameManager.on_enemy_killed(XP_PER_KILL)

func _trigger_win() -> void:
	_level_won = true
	GameManager.is_running = false
	_update_objective_hud()
	if _victory_screen:
		_victory_screen.show_victory()

func _create_arena_bounds() -> void:
	var bounds := Node2D.new()
	bounds.name = "ArenaBounds"
	add_child(bounds)

	var half_w := ARENA_HALF_WIDTH
	var half_h := _arena_half_height
	var t := WALL_THICKNESS
	var wall_defs := [
		[Vector2(0, -(half_h + t * 0.5)), Vector2((half_w + t) * 2, t)],
		[Vector2(0, half_h + t * 0.5), Vector2((half_w + t) * 2, t)],
		[Vector2(-(half_w + t * 0.5), 0), Vector2(t, half_h * 2)],
		[Vector2(half_w + t * 0.5, 0), Vector2(t, half_h * 2)],
	]

	for d in wall_defs:
		var wall := StaticBody2D.new()
		wall.position = d[0]
		wall.collision_layer = 16
		wall.collision_mask = 0
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = d[1]
		col.shape = rect
		wall.add_child(col)
		bounds.add_child(wall)

func _draw() -> void:
	var half_w := ARENA_HALF_WIDTH
	var half_h := _arena_half_height

	# Main arena boundary.
	draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), Color(0.36, 0.44, 0.34, 0.55), false, 3.0)

	# Extraction strip at the top edge.
	draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, 140.0), Color(0.25, 0.48, 0.24, 0.16), true)
	for i in 18:
		var x := lerpf(-half_w + 50.0, half_w - 50.0, float(i) / 17.0)
		draw_line(Vector2(x, -half_h + 10.0), Vector2(x + 26.0, -half_h + 64.0), Color(0.4, 0.62, 0.35, 0.25), 2.0)

	# Trench lines to communicate uphill movement.
	var trench_color := Color(0.35, 0.27, 0.2, 0.28)
	for row in 22:
		var y := lerpf(-half_h + 170.0, half_h - 120.0, float(row) / 21.0)
		var offset := 40.0 if row % 2 == 0 else -40.0
		draw_line(Vector2(-half_w + 80.0 + offset, y), Vector2(half_w - 80.0 + offset, y), trench_color, 6.0)
