# level_5.gd - Level 5: "Base Attack"
# Massive 9x9-screen battlefield with a central enemy stronghold objective.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_INFANTRY_SCENE := preload("res://scenes/enemies/enemy_infantry.tscn")
const ENEMY_TANK_SCENE := preload("res://scenes/enemies/enemy_tank.tscn")
const EnergyHUD := preload("res://src/ui/energy_hud.gd")
const WeaponHUD := preload("res://src/ui/weapon_hud.gd")
const DroneBatteryHUD := preload("res://src/ui/drone_battery_hud.gd")
const VictoryScreen := preload("res://src/ui/victory_screen.gd")
const GameOverScreen := preload("res://src/ui/game_over_screen.gd")

const WIN_RETURN_DELAY := 2.0
const VICTORY_TITLE := "BASE SECURED"
const VICTORY_MESSAGE := "Enemy command node captured. Returning to workshop."
const GAME_OVER_SHOW_DELAY := 0.9
const GAME_OVER_RETURN_DELAY := 2.0
const GAME_OVER_TITLE := "MECH DESTROYED"
const GAME_OVER_MESSAGE := "Base assault failed. Returning to workshop."

const WALL_THICKNESS := 30.0
const SCREENS_WIDE := 7.0
const SCREENS_TALL := 7.0

const BASE_CENTER := Vector2.ZERO
const BASE_SIZE := Vector2(920.0, 760.0)
const BASE_GATE_WIDTH := 340.0
const BASE_WALL_THICKNESS := 28.0
const CAPTURE_ZONE_SIZE := Vector2(300.0, 240.0)
const HOLD_DURATION := 10.0

const BASE_INFANTRY_COUNT := 30
const BASE_TANK_COUNT := 4
const OUTER_INFANTRY_COUNT := 10
const OUTER_TANK_COUNT := 2
const ROAMING_INFANTRY_COUNT := 10
const ROAMING_TANK_COUNT := 2
const XP_PER_INFANTRY := 6
const XP_PER_TANK := 20

@onready var background_rect: ColorRect = %BackgroundRect
@onready var game_hud: GameHUD = %GameHUD
@onready var objective_label: Label = %ObjectiveLabel
@onready var mission_label: Label = %MissionLabel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _stats: PlayerStats
var _bg_material: ShaderMaterial

var _enemies_node: Node2D
var _base_node: Node2D
var _victory_screen: VictoryScreen
var _game_over_screen: GameOverScreen

var _arena_half_width: float = 2500.0
var _arena_half_height: float = 2500.0
var _hold_progress: float = 0.0
var _level_won: bool = false
var _enemies_alive: int = 0

func _ready() -> void:
	get_tree().call_group("level_effect", "queue_free")

	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player_camera = _player.get_node("Camera2D") as Camera2D

	_compute_arena_half_extents()
	_player.global_position = Vector2(0.0, _arena_half_height - 220.0)

	_stats = GameManager.player_stats

	var weapon_hud := WeaponHUD.new()
	$HUD/HUDControl.add_child(weapon_hud)
	weapon_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weapon_hud.setup(_player)

	var energy_hud := EnergyHUD.new()
	$HUD/HUDControl.add_child(energy_hud)
	energy_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	energy_hud.setup(_player)

	var drone_battery_hud := DroneBatteryHUD.new()
	$HUD/HUDControl.add_child(drone_battery_hud)
	drone_battery_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drone_battery_hud.setup(_player)

	if background_rect and background_rect.material is ShaderMaterial:
		_bg_material = (background_rect.material as ShaderMaterial).duplicate()
		background_rect.material = _bg_material

	if _stats:
		game_hud.update_stats(_stats)

	_enemies_node = Node2D.new()
	_enemies_node.name = "Enemies"
	add_child(_enemies_node)

	_base_node = Node2D.new()
	_base_node.name = "EnemyBase"
	add_child(_base_node)

	_create_arena_bounds()
	_create_base_walls()
	_spawn_base_defenders()
	_spawn_roaming_patrols()

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

	_update_objective_hud()
	queue_redraw()

func _process(delta: float) -> void:
	_scroll_background()
	game_hud.update_stats(_stats)

	if _stats and _stats.is_dead():
		return

	if not _level_won:
		_update_capture_progress(delta)

	_update_objective_hud()
	queue_redraw()

func _compute_arena_half_extents() -> void:
	if not is_instance_valid(_player_camera):
		_arena_half_width = 1850.0
		_arena_half_height = 1850.0
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var zoom_x := maxf(_player_camera.zoom.x, 0.001)
	var zoom_y := maxf(_player_camera.zoom.y, 0.001)
	var world_screen := Vector2(viewport_size.x / zoom_x, viewport_size.y / zoom_y)

	_arena_half_width = maxf(1700.0, world_screen.x * (SCREENS_WIDE * 0.5))
	_arena_half_height = maxf(1700.0, world_screen.y * (SCREENS_TALL * 0.5))

func _scroll_background() -> void:
	if not (_bg_material and is_instance_valid(_player)):
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var active_camera := get_viewport().get_camera_2d()
	var zoom := Vector2.ONE
	if is_instance_valid(_player_camera):
		zoom = Vector2(maxf(_player_camera.zoom.x, 0.001), maxf(_player_camera.zoom.y, 0.001))
	if is_instance_valid(active_camera):
		zoom = Vector2(maxf(active_camera.zoom.x, 0.001), maxf(active_camera.zoom.y, 0.001))

	var world_vp: Vector2 = Vector2(vp_size.x / zoom.x, vp_size.y / zoom.y)
	_bg_material.set_shader_parameter("viewport_size", world_vp)
	_bg_material.set_shader_parameter("camera_world_pos", _get_background_anchor_position() - world_vp * 0.5)

func _get_background_anchor_position() -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO
	if _player.has_method("get_active_drone"):
		var active_drone: Variant = _player.call("get_active_drone")
		if active_drone is Node2D and is_instance_valid(active_drone):
			return (active_drone as Node2D).global_position
	return _player.global_position

func _update_capture_progress(delta: float) -> void:
	if not is_instance_valid(_player):
		_hold_progress = 0.0
		return

	if _capture_zone_rect().has_point(_player.global_position):
		_hold_progress = minf(HOLD_DURATION, _hold_progress + delta)
		if _hold_progress >= HOLD_DURATION:
			_trigger_win()
	else:
		_hold_progress = 0.0

func _update_objective_hud() -> void:
	if objective_label:
		if _level_won:
			objective_label.text = "MISSION COMPLETE"
		elif not is_instance_valid(_player):
			objective_label.text = "MECH DESTROYED"
		elif _capture_zone_rect().has_point(_player.global_position):
			objective_label.text = "Hold base: %.1f / %.1f s" % [_hold_progress, HOLD_DURATION]
		else:
			var delta_to_base := BASE_CENTER - _player.global_position
			var distance_to_base := delta_to_base.length()
			objective_label.text = "Reach base: %.0f m  [%s]" % [distance_to_base, _cardinal_hint(delta_to_base)]

	if mission_label:
		if _level_won:
			mission_label.text = "Base secured"
		elif not is_instance_valid(_player):
			mission_label.text = "Mission failed"
		elif _capture_zone_rect().has_point(_player.global_position):
			mission_label.text = "Holding under fire - enemies active: %d" % _enemies_alive
		else:
			mission_label.text = "BASE ATTACK - breach and hold for 10s"

func _cardinal_hint(dir: Vector2) -> String:
	if dir.length() <= 1.0:
		return "HERE"

	var vertical := ""
	if dir.y < -0.35:
		vertical = "N"
	elif dir.y > 0.35:
		vertical = "S"

	var horizontal := ""
	if dir.x > 0.35:
		horizontal = "E"
	elif dir.x < -0.35:
		horizontal = "W"

	var result := vertical + horizontal
	return result if not result.is_empty() else "CENTER"

func _spawn_base_defenders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 905106

	var base_half := BASE_SIZE * 0.5
	var outer_min := base_half + Vector2(120.0, 120.0)
	var outer_max := base_half + Vector2(420.0, 360.0)

	for _i in BASE_INFANTRY_COUNT:
		var enemy := ENEMY_INFANTRY_SCENE.instantiate() as EnemyInfantry
		enemy.global_position = Vector2(
			rng.randf_range(BASE_CENTER.x - base_half.x + 70.0, BASE_CENTER.x + base_half.x - 70.0),
			rng.randf_range(BASE_CENTER.y - base_half.y + 70.0, BASE_CENTER.y + base_half.y - 70.0)
		)
		enemy.starts_dormant = true
		enemy.alert_range = 520.0
		enemy.died.connect(_on_enemy_died.bind(XP_PER_INFANTRY))
		_enemies_node.add_child(enemy)
		_enemies_alive += 1
		GameManager.enemies_alive += 1

	for _i in OUTER_INFANTRY_COUNT:
		var outer_enemy := ENEMY_INFANTRY_SCENE.instantiate() as EnemyInfantry
		outer_enemy.global_position = _random_perimeter_point(rng, outer_min, outer_max)
		outer_enemy.starts_dormant = true
		outer_enemy.alert_range = 480.0
		outer_enemy.died.connect(_on_enemy_died.bind(XP_PER_INFANTRY))
		_enemies_node.add_child(outer_enemy)
		_enemies_alive += 1
		GameManager.enemies_alive += 1

	for i in BASE_TANK_COUNT:
		var tank := ENEMY_TANK_SCENE.instantiate() as EnemyTank
		var ring_t := float(i) / float(maxi(BASE_TANK_COUNT, 1))
		var ring_angle := TAU * ring_t
		var ring_radius := 170.0
		tank.global_position = BASE_CENTER + Vector2.from_angle(ring_angle) * ring_radius
		tank.rotation = wrapf(ring_angle + PI, -PI, PI)
		tank.starts_dormant = true
		tank.alert_range = 620.0
		tank.move_speed = 52.0
		tank.configure_level_path(_build_gate_route(tank.global_position), 160.0)
		tank.died.connect(_on_enemy_died.bind(XP_PER_TANK))
		_enemies_node.add_child(tank)
		_enemies_alive += 1
		GameManager.enemies_alive += 1

	for _i in OUTER_TANK_COUNT:
		var outer_tank := ENEMY_TANK_SCENE.instantiate() as EnemyTank
		outer_tank.global_position = _random_perimeter_point(rng, outer_min, outer_max)
		outer_tank.rotation = randf_range(0.0, TAU)
		outer_tank.starts_dormant = true
		outer_tank.alert_range = 540.0
		outer_tank.move_speed = 50.0
		outer_tank.configure_level_path(_build_gate_route(outer_tank.global_position), 180.0)
		outer_tank.died.connect(_on_enemy_died.bind(XP_PER_TANK))
		_enemies_node.add_child(outer_tank)
		_enemies_alive += 1
		GameManager.enemies_alive += 1

func _build_gate_route(start_pos: Vector2) -> Array[Vector2]:
	var route: Array[Vector2] = []
	var half := BASE_SIZE * 0.5
	var south_gate := BASE_CENTER + Vector2(0.0, half.y + 80.0)
	var north_gate := BASE_CENTER + Vector2(0.0, -half.y - 80.0)
	var preferred_gate := south_gate if start_pos.y >= BASE_CENTER.y else north_gate
	var alternate_gate := north_gate if preferred_gate == south_gate else south_gate

	route.append(_clamp_inside_arena(preferred_gate, 120.0))
	route.append(_clamp_inside_arena(BASE_CENTER + Vector2(0.0, 0.0), 120.0))
	route.append(_clamp_inside_arena(alternate_gate, 120.0))
	route.append(_clamp_inside_arena(BASE_CENTER + Vector2(half.x + 220.0, 0.0), 120.0))
	return route

func _spawn_roaming_patrols() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 905901

	for _i in ROAMING_INFANTRY_COUNT:
		var rover := ENEMY_INFANTRY_SCENE.instantiate() as EnemyInfantry
		rover.global_position = _random_map_point_away_from_base(rng, 900.0)
		rover.starts_dormant = false
		rover.move_speed = rng.randf_range(62.0, 78.0)
		rover.preferred_range = rng.randf_range(300.0, 420.0)
		rover.died.connect(_on_enemy_died.bind(XP_PER_INFANTRY))
		_enemies_node.add_child(rover)
		_enemies_alive += 1
		GameManager.enemies_alive += 1

	for i in ROAMING_TANK_COUNT:
		var patrol_tank := ENEMY_TANK_SCENE.instantiate() as EnemyTank
		var patrol_center := _random_map_point_away_from_base(rng, 1100.0)
		patrol_tank.global_position = patrol_center + Vector2.from_angle(randf_range(0.0, TAU)) * 120.0
		patrol_tank.rotation = randf_range(0.0, TAU)
		patrol_tank.starts_dormant = false
		patrol_tank.move_speed = 56.0
		patrol_tank.turn_speed = 120.0
		patrol_tank.configure_level_path(_build_patrol_path(patrol_center, 170.0 + float(i) * 35.0), 240.0)
		patrol_tank.died.connect(_on_enemy_died.bind(XP_PER_TANK))
		_enemies_node.add_child(patrol_tank)
		_enemies_alive += 1
		GameManager.enemies_alive += 1

func _random_perimeter_point(rng: RandomNumberGenerator, min_extents: Vector2, max_extents: Vector2) -> Vector2:
	for _attempt in 16:
		var angle := rng.randf_range(0.0, TAU)
		var radius := Vector2(rng.randf_range(min_extents.x, max_extents.x), rng.randf_range(min_extents.y, max_extents.y))
		var candidate := BASE_CENTER + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		if candidate.y < BASE_CENTER.y + BASE_SIZE.y * 0.5 + 100.0:
			return _clamp_inside_arena(candidate, 80.0)
	return _clamp_inside_arena(BASE_CENTER + Vector2(0.0, BASE_SIZE.y * 0.5 + 220.0), 80.0)

func _random_map_point_away_from_base(rng: RandomNumberGenerator, min_distance: float) -> Vector2:
	for _attempt in 20:
		var candidate := Vector2(
			rng.randf_range(-_arena_half_width + 180.0, _arena_half_width - 180.0),
			rng.randf_range(-_arena_half_height + 180.0, _arena_half_height - 180.0)
		)
		if candidate.distance_to(BASE_CENTER) >= min_distance:
			return candidate
	return Vector2(_arena_half_width * 0.55, -_arena_half_height * 0.35)

func _build_patrol_path(center: Vector2, radius: float) -> Array[Vector2]:
	var path: Array[Vector2] = []
	for i in 5:
		var a := (TAU * float(i) / 5.0) + PI * 0.2
		var p := center + Vector2.from_angle(a) * radius
		path.append(_clamp_inside_arena(p, 120.0))
	return path

func _clamp_inside_arena(pos: Vector2, margin: float) -> Vector2:
	return Vector2(
		clampf(pos.x, -_arena_half_width + margin, _arena_half_width - margin),
		clampf(pos.y, -_arena_half_height + margin, _arena_half_height - margin)
	)

func _on_enemy_died(_enemy: Node, xp_reward: int) -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	GameManager.on_enemy_killed(xp_reward)

func _trigger_win() -> void:
	if _level_won:
		return
	_level_won = true
	GameManager.is_running = false
	get_tree().call_group("level_effect", "queue_free")
	_update_objective_hud()
	if _victory_screen:
		_victory_screen.show_victory()

func _on_game_over() -> void:
	if _level_won:
		return
	if _game_over_screen:
		_game_over_screen.show_game_over_delayed(GAME_OVER_SHOW_DELAY)

func _capture_zone_rect() -> Rect2:
	return Rect2(BASE_CENTER - CAPTURE_ZONE_SIZE * 0.5, CAPTURE_ZONE_SIZE)

func _create_arena_bounds() -> void:
	var bounds := Node2D.new()
	bounds.name = "ArenaBounds"
	add_child(bounds)

	var half_w := _arena_half_width
	var half_h := _arena_half_height
	var t := WALL_THICKNESS
	var defs := [
		[Vector2(0.0, -(half_h + t * 0.5)), Vector2((half_w + t) * 2.0, t)],
		[Vector2(0.0,  (half_h + t * 0.5)), Vector2((half_w + t) * 2.0, t)],
		[Vector2(-(half_w + t * 0.5), 0.0), Vector2(t, half_h * 2.0)],
		[Vector2( (half_w + t * 0.5), 0.0), Vector2(t, half_h * 2.0)],
	]
	for d in defs:
		_create_wall(bounds, d[0], d[1], WALL_THICKNESS)

func _create_base_walls() -> void:
	var walls := Node2D.new()
	walls.name = "BaseWalls"
	_base_node.add_child(walls)

	var half := BASE_SIZE * 0.5
	var t := BASE_WALL_THICKNESS
	var gate_half := BASE_GATE_WIDTH * 0.5
	var segment_w := (BASE_SIZE.x - BASE_GATE_WIDTH) * 0.5

	# Top wall split to create a north gate and improve in/out circulation.
	_create_wall(
		walls,
		BASE_CENTER + Vector2(-(gate_half + segment_w * 0.5), -half.y - t * 0.5),
		Vector2(segment_w, t),
		t
	)
	_create_wall(
		walls,
		BASE_CENTER + Vector2(gate_half + segment_w * 0.5, -half.y - t * 0.5),
		Vector2(segment_w, t),
		t
	)

	# Left and right walls stay closed to keep base identity.
	_create_wall(walls, BASE_CENTER + Vector2(-half.x - t * 0.5, 0.0), Vector2(t, BASE_SIZE.y + t * 2.0), t)
	_create_wall(walls, BASE_CENTER + Vector2(half.x + t * 0.5, 0.0), Vector2(t, BASE_SIZE.y + t * 2.0), t)

	# Bottom wall split into two pieces to leave an entrance gate.
	_create_wall(
		walls,
		BASE_CENTER + Vector2(-(gate_half + segment_w * 0.5), half.y + t * 0.5),
		Vector2(segment_w, t),
		t
	)
	_create_wall(
		walls,
		BASE_CENTER + Vector2(gate_half + segment_w * 0.5, half.y + t * 0.5),
		Vector2(segment_w, t),
		t
	)

func _create_wall(parent: Node, pos: Vector2, size: Vector2, _thickness: float) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 16
	wall.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	wall.add_child(col)
	parent.add_child(wall)

func _draw() -> void:
	_draw_arena_frame()
	_draw_base_layout()
	_draw_objective_pointer()

func _draw_arena_frame() -> void:
	draw_rect(
		Rect2(-_arena_half_width, -_arena_half_height, _arena_half_width * 2.0, _arena_half_height * 2.0),
		Color(0.40, 0.18, 0.14, 0.38),
		false,
		5.0
	)

func _draw_base_layout() -> void:
	var base_rect := Rect2(BASE_CENTER - BASE_SIZE * 0.5, BASE_SIZE)
	var capture_rect := _capture_zone_rect()
	draw_rect(base_rect, Color(0.78, 0.16, 0.10, 0.10), true)

	# Draw wall visuals with explicit gate gaps so collision and graphics match.
	var wall_color := Color(0.78, 0.16, 0.10, 0.70)
	var wall_thickness := 4.0
	var left := BASE_CENTER.x - BASE_SIZE.x * 0.5
	var right := BASE_CENTER.x + BASE_SIZE.x * 0.5
	var top := BASE_CENTER.y - BASE_SIZE.y * 0.5
	var bottom := BASE_CENTER.y + BASE_SIZE.y * 0.5
	var gate_half := BASE_GATE_WIDTH * 0.5

	# Side walls (closed).
	draw_line(Vector2(left, top), Vector2(left, bottom), wall_color, wall_thickness)
	draw_line(Vector2(right, top), Vector2(right, bottom), wall_color, wall_thickness)

	# Top wall split by north gate.
	draw_line(Vector2(left, top), Vector2(-gate_half, top), wall_color, wall_thickness)
	draw_line(Vector2(gate_half, top), Vector2(right, top), wall_color, wall_thickness)

	# Bottom wall split by south gate.
	draw_line(Vector2(left, bottom), Vector2(-gate_half, bottom), wall_color, wall_thickness)
	draw_line(Vector2(gate_half, bottom), Vector2(right, bottom), wall_color, wall_thickness)

	# Gate highlight lines.
	draw_line(Vector2(-gate_half, top), Vector2(gate_half, top), Color(0.95, 0.55, 0.24, 0.85), 5.0)
	draw_line(Vector2(-gate_half, bottom), Vector2(gate_half, bottom), Color(0.95, 0.55, 0.24, 0.85), 5.0)
	draw_rect(capture_rect, Color(0.98, 0.74, 0.22, 0.30), false, 3.0)

func _draw_objective_pointer() -> void:
	if not is_instance_valid(_player) or _level_won:
		return
	if _capture_zone_rect().has_point(_player.global_position):
		return

	var to_base := BASE_CENTER - _player.global_position
	if to_base.length() < 1.0:
		return
	var dir := to_base.normalized()
	var pointer_start := _player.global_position + dir * 120.0
	var pointer_tip := _player.global_position + dir * 245.0
	var pointer_color := Color(0.96, 0.70, 0.22, 0.92)
	var perp := Vector2(-dir.y, dir.x)

	draw_line(pointer_start, pointer_tip, pointer_color, 6.0)

	var tri := PackedVector2Array([
		pointer_tip,
		pointer_tip - dir * 26.0 + perp * 12.0,
		pointer_tip - dir * 26.0 - perp * 12.0,
	])
	draw_colored_polygon(tri, pointer_color)
