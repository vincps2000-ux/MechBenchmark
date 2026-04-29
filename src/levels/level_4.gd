# level_4.gd — Level 4: "Columnn Ambush"
# Five enemy tanks cross from west to east in a curved column route.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_TANK_SCENE := preload("res://scenes/enemies/enemy_tank.tscn")
const WeaponHUD := preload("res://src/ui/weapon_hud.gd")
const VictoryScreen := preload("res://src/ui/victory_screen.gd")

const WIN_RETURN_DELAY := 2.0
const VICTORY_TITLE := "COLUMNN AMBUSH CLEARED"
const VICTORY_MESSAGE := "Convoy neutralized before breakthrough. Returning to workshop."

const ARENA_HALF_WIDTH := 1200.0
const ARENA_HALF_HEIGHT := 700.0
const WALL_THICKNESS := 30.0

const TANK_COUNT := 5
const XP_PER_KILL := 20
const ALERT_RANGE := 340.0
const SPAWN_CLAMP_MARGIN := 70.0
const CONVOY_SPAWN_DELAY := 2.0  # seconds between each tank entering the arena
const PLAYER_SPAWN := Vector2(ARENA_HALF_WIDTH - 230.0, 0.0)

const LOOSING_ZONE_WIDTH := 180.0
const LOOSING_ZONE_RECT := Rect2(
	ARENA_HALF_WIDTH - LOOSING_ZONE_WIDTH,
	-ARENA_HALF_HEIGHT,
	LOOSING_ZONE_WIDTH,
	ARENA_HALF_HEIGHT * 2.0
)

const FOREST_OBSTACLE_DEFS: Array[Array] = [
	[Vector2(-860.0, -520.0), Vector2(180.0, 70.0), 18.0],
	[Vector2(-560.0, 500.0), Vector2(160.0, 60.0), -10.0],
	[Vector2(-70.0, -500.0), Vector2(220.0, 70.0), 8.0],
	[Vector2(250.0, 470.0), Vector2(170.0, 60.0), -14.0],
	[Vector2(640.0, -470.0), Vector2(210.0, 72.0), 12.0],
	[Vector2(930.0, 470.0), Vector2(140.0, 56.0), -6.0],
]

const BASE_PATH: Array[Vector2] = [
	Vector2(-1080.0, -260.0),
	Vector2(-820.0, -120.0),
	Vector2(-560.0, 170.0),
	Vector2(-250.0, 90.0),
	Vector2(120.0, -190.0),
	Vector2(520.0, -80.0),
	Vector2(880.0, 160.0),
	Vector2(1020.0, 40.0),
	Vector2(1090.0, -80.0),
	Vector2(1140.0, 20.0),
]

@onready var background_rect: ColorRect = %BackgroundRect
@onready var game_hud: GameHUD = %GameHUD
@onready var objective_label: Label = %ObjectiveLabel
@onready var mission_label: Label = %MissionLabel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _stats: PlayerStats
var _bg_material: ShaderMaterial
var _tanks_node: Node2D
var _obstacles_node: Node2D
var _victory_screen: VictoryScreen

var _level_won := false
var _tanks_alive := 0
var _firing_actions: Array[String] = []

func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player_camera = _player.get_node("Camera2D") as Camera2D
	_player.global_position = PLAYER_SPAWN

	_stats = GameManager.player_stats

	var weapon_hud := WeaponHUD.new()
	$HUD/HUDControl.add_child(weapon_hud)
	weapon_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weapon_hud.setup(_player)

	if background_rect and background_rect.material is ShaderMaterial:
		_bg_material = (background_rect.material as ShaderMaterial).duplicate()
		background_rect.material = _bg_material

	if _stats:
		game_hud.update_stats(_stats)

	_tanks_node = Node2D.new()
	_tanks_node.name = "EnemyTanks"
	add_child(_tanks_node)

	_obstacles_node = Node2D.new()
	_obstacles_node.name = "ForestObstacles"
	add_child(_obstacles_node)

	_create_arena_bounds()
	_create_forest_obstacles()
	_spawn_column()
	_cache_fire_actions()

	_victory_screen = VictoryScreen.new()
	$HUD/HUDControl.add_child(_victory_screen)
	_victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_screen.configure(VICTORY_TITLE, VICTORY_MESSAGE, WIN_RETURN_DELAY)

	_update_objective_hud()
	queue_redraw()

func _process(_delta: float) -> void:
	_scroll_background()
	game_hud.update_stats(_stats)
	_update_objective_hud()

	if _level_won:
		return

	if _did_player_fire_this_frame():
		_alert_column()

	_trigger_loosing_zone_orbit()

func _scroll_background() -> void:
	if not (_bg_material and _player_camera and is_instance_valid(_player)):
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = _player_camera.zoom.x
	var world_vp: Vector2 = vp_size / zoom
	_bg_material.set_shader_parameter("viewport_size", world_vp)
	_bg_material.set_shader_parameter("camera_world_pos", _player.global_position - world_vp * 0.5)

func _update_objective_hud() -> void:
	if objective_label:
		if _level_won:
			objective_label.text = "MISSION COMPLETE"
		else:
			objective_label.text = "Destroy all tanks before they settle in red zone"

	if mission_label:
		if _level_won:
			mission_label.text = "Column neutralized"
		else:
			mission_label.text = "Tanks remaining: %d" % _tanks_alive

func _spawn_column() -> void:
	# Pre-register the full count so the HUD is correct from the start and
	# the win condition fires only when ALL tanks are dead.
	_tanks_alive = TANK_COUNT
	for i in TANK_COUNT:
		var timer := get_tree().create_timer(float(i) * CONVOY_SPAWN_DELAY)
		timer.timeout.connect(_spawn_single_tank.bind(i))

func _spawn_single_tank(index: int) -> void:
	if _level_won:
		return
	var tank := ENEMY_TANK_SCENE.instantiate() as EnemyTank
	tank.global_position = _clamp_inside_arena(BASE_PATH[0], SPAWN_CLAMP_MARGIN)
	tank.rotation = 0.0
	tank.turn_speed = 105.0
	tank.move_speed = 58.0
	tank.configure_level_path(_build_path_for_index(index), ALERT_RANGE)
	tank.died.connect(_on_tank_died)
	_tanks_node.add_child(tank)
	GameManager.enemies_alive += 1

func _build_path_for_index(index: int) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var lane_offset := 0.0
	for p in BASE_PATH:
		path.append(p + Vector2(0.0, lane_offset))
	return path

func _trigger_loosing_zone_orbit() -> void:
	var zone_center: Vector2 = LOOSING_ZONE_RECT.get_center()
	for child in _tanks_node.get_children():
		if not (child is EnemyTank):
			continue
		var tank: EnemyTank = child as EnemyTank
		if not is_instance_valid(tank):
			continue
		if tank.is_path_end_circling():
			continue
		if LOOSING_ZONE_RECT.has_point(tank.global_position):
			tank.begin_loosing_zone_orbit(zone_center)

func _clamp_inside_arena(pos: Vector2, margin: float) -> Vector2:
	return Vector2(
		clampf(pos.x, -ARENA_HALF_WIDTH + margin, ARENA_HALF_WIDTH - margin),
		clampf(pos.y, -ARENA_HALF_HEIGHT + margin, ARENA_HALF_HEIGHT - margin)
	)

func _create_forest_obstacles() -> void:
	for d in FOREST_OBSTACLE_DEFS:
		var pos: Vector2 = d[0] as Vector2
		var size: Vector2 = d[1] as Vector2
		var rot_deg: float = float(d[2])

		var body := StaticBody2D.new()
		body.global_position = pos
		body.rotation_degrees = rot_deg
		body.collision_layer = 16
		body.collision_mask = 0

		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		col.shape = rect
		body.add_child(col)
		_obstacles_node.add_child(body)

func _cache_fire_actions() -> void:
	_firing_actions.clear()
	var binding_count: int = GameManager.weapon_bindings.size()
	var max_actions: int = maxi(binding_count, 8)
	for i in max_actions:
		var action_name: String = "fire_%d" % i
		if InputMap.has_action(action_name):
			_firing_actions.append(action_name)

func _did_player_fire_this_frame() -> bool:
	for action_name in _firing_actions:
		if Input.is_action_just_pressed(action_name):
			return true
	return false

func _alert_column() -> void:
	for child in _tanks_node.get_children():
		if child is EnemyTank:
			(child as EnemyTank).alert_to_player()

func _on_tank_died(_enemy: EnemyTank) -> void:
	_tanks_alive = maxi(0, _tanks_alive - 1)
	GameManager.on_enemy_killed(XP_PER_KILL)
	if _tanks_alive <= 0:
		_trigger_win()

func _trigger_win() -> void:
	if _level_won:
		return
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
	var half_h := ARENA_HALF_HEIGHT
	var t := WALL_THICKNESS
	var wall_defs := [
		[Vector2(0.0, -(half_h + t * 0.5)), Vector2((half_w + t) * 2.0, t)],
		[Vector2(0.0, (half_h + t * 0.5)), Vector2((half_w + t) * 2.0, t)],
		[Vector2(-(half_w + t * 0.5), 0.0), Vector2(t, half_h * 2.0)],
		[Vector2((half_w + t * 0.5), 0.0), Vector2(t, half_h * 2.0)],
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
	var half_h := ARENA_HALF_HEIGHT

	draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), Color(0.24, 0.37, 0.20, 0.65), false, 3.0)

	for d in FOREST_OBSTACLE_DEFS:
		var pos: Vector2 = d[0] as Vector2
		var size: Vector2 = d[1] as Vector2
		var rot: float = deg_to_rad(float(d[2]))
		var half_size: Vector2 = size * 0.5
		var local_points := [
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		]
		var world_points := PackedVector2Array()
		for p in local_points:
			world_points.append(pos + p.rotated(rot))
		draw_colored_polygon(world_points, Color(0.30, 0.24, 0.16, 0.82))
		draw_polyline(world_points, Color(0.14, 0.10, 0.07, 0.95), 2.0, true)

		# Red loosing zone where tanks regroup and orbit if they make it through.
		draw_rect(LOOSING_ZONE_RECT, Color(0.85, 0.12, 0.12, 0.09), true)
		draw_rect(LOOSING_ZONE_RECT, Color(0.95, 0.24, 0.18, 0.45), false, 3.0)

	# Faint dirt convoy trail through the forest.
	for i in BASE_PATH.size() - 1:
		var from_pt := BASE_PATH[i]
		var to_pt := BASE_PATH[i + 1]
		draw_line(from_pt, to_pt, Color(0.56, 0.43, 0.27, 0.16), 56.0)
		draw_line(from_pt, to_pt, Color(0.52, 0.40, 0.24, 0.28), 34.0)
		draw_line(from_pt, to_pt, Color(0.22, 0.18, 0.12, 0.62), 4.0)
