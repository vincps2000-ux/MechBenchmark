# level_3.gd — Level 3: "The Duel"
# A quiet forest clearing where the player faces a single enemy tank.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_TANK_SCENE := preload("res://scenes/enemies/enemy_tank.tscn")
const WeaponHUD := preload("res://src/ui/weapon_hud.gd")
const VictoryScreen := preload("res://src/ui/victory_screen.gd")

const WIN_RETURN_DELAY := 2.0
const VICTORY_TITLE := "DUEL OVER"
const VICTORY_MESSAGE := "The forest is silent again. Returning to workshop."

const ARENA_HALF_SIZE := 700.0
const WALL_THICKNESS  := 30.0

const XP_PER_KILL := 10

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

var _level_won := false
var _enemy_alive := true

func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player_camera = _player.get_node("Camera2D") as Camera2D
	_player.global_position = Vector2(0.0, ARENA_HALF_SIZE - 140.0)

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

	_enemies_node = Node2D.new()
	_enemies_node.name = "Enemies"
	add_child(_enemies_node)

	_create_arena_bounds()
	_spawn_enemy()

	_victory_screen = VictoryScreen.new()
	$HUD/HUDControl.add_child(_victory_screen)
	_victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_screen.configure(VICTORY_TITLE, VICTORY_MESSAGE, WIN_RETURN_DELAY)

	_update_objective_hud()
	queue_redraw()

func _process(_delta: float) -> void:
	_scroll_background()
	game_hud.update_stats(_stats)

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
		objective_label.text = "DUEL OVER" if _level_won else "Eliminate the enemy"
	if mission_label:
		mission_label.text = "Duel complete" if _level_won else "One enemy remains"

func _spawn_enemy() -> void:
	var enemy := ENEMY_TANK_SCENE.instantiate() as CharacterBody2D
	# Place the tank at the north end of the clearing, facing south toward the player.
	enemy.global_position = Vector2(0.0, -(ARENA_HALF_SIZE - 200.0))
	# Face south (toward player) on spawn — rotation 90deg = pointing down (+Y)
	enemy.rotation = PI * 0.5
	enemy.died.connect(_on_enemy_died)
	_enemies_node.add_child(enemy)
	_enemy_alive = true
	GameManager.enemies_alive += 1

func _on_enemy_died(_enemy: Node) -> void:
	_enemy_alive = false
	GameManager.on_enemy_killed(XP_PER_KILL)
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

	var h := ARENA_HALF_SIZE
	var t := WALL_THICKNESS
	var wall_defs := [
		[Vector2(0.0, -(h + t * 0.5)), Vector2((h + t) * 2.0, t)],
		[Vector2(0.0,  (h + t * 0.5)), Vector2((h + t) * 2.0, t)],
		[Vector2(-(h + t * 0.5), 0.0), Vector2(t, h * 2.0)],
		[Vector2( (h + t * 0.5), 0.0), Vector2(t, h * 2.0)],
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
	var h := ARENA_HALF_SIZE

	# Clearing boundary.
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(0.28, 0.45, 0.18, 0.60), false, 4.0)

	# Tree ring: decorative trees around the perimeter (visual only, no collision).
	var tree_positions := [
		Vector2(-580, -620), Vector2(-320, -650), Vector2( 100, -660),
		Vector2( 420, -630), Vector2( 620, -580), Vector2( 660,  -80),
		Vector2( 640,  340), Vector2( 500,  620), Vector2( 180,  660),
		Vector2(-200,  650), Vector2(-520,  610), Vector2(-660,  260),
		Vector2(-650,  -60), Vector2(-600, -320), Vector2( 300, -400),
		Vector2(-300,  200), Vector2( 260,  300), Vector2(-100, -500),
		Vector2( 500,  100), Vector2(-480,  440),
	]

	for tp in tree_positions:
		# Trunk
		draw_circle(tp, 14.0, Color(0.28, 0.21, 0.13, 1.0))
		# Canopy (outer ring, darker)
		draw_circle(tp, 42.0, Color(0.16, 0.28, 0.10, 0.70))
		# Canopy (inner, brighter)
		draw_circle(tp, 26.0, Color(0.24, 0.40, 0.14, 0.85))

	# Duel zone marker (faint circle in the center).
	draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 48, Color(0.35, 0.50, 0.22, 0.25), 2.0)
