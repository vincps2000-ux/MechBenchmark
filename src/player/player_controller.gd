# player_controller.gd — Player movement controller supporting three movement modes
class_name PlayerController
extends CharacterBody2D

const AUTOCANNON_SCENE   := preload("res://scenes/weapons/autocannon.tscn")
const LASER_SCENE        := preload("res://scenes/weapons/laser.tscn")
const FLAMETHROWER_SCENE := preload("res://scenes/weapons/flamethrower.tscn")
const RAILGUN_SCENE      := preload("res://scenes/weapons/railgun.tscn")
const ROCKET_POD_SCENE   := preload("res://scenes/weapons/rocket_pod.tscn")
const MACHINEGUN_SCENE   := preload("res://scenes/weapons/machinegun.tscn")
const _DirectionArrow    := preload("res://src/player/direction_arrow.gd")

const BASE_SPEED            := 200.0
const ROTATION_SPEED_SPIDER := 1.8   # rad/s — spider turns a bit quicker
const ROTATION_SPEED_TANK   := 1.2   # rad/s — tank turns very slowly
const ROTATION_SPEED_LANDSHIP := 0.45  # rad/s — landship turns even slower than tank
const TANK_FORWARD_MULT     := 1.3   # extra power in straight-line tank drive
const TORSO_ROTATION_SPEED  := 4.0   # rad/s — torso tracks mouse independently
const ROTATION_SPEED_WALKER := 3.0   # rad/s — walker body rotation toward mouse (Q held)
const TORSO_DEADSPOT_HALF_ANGLE := deg_to_rad(35.0)

enum TorsoDeadspotSide {
	NONE,
	FRONT,
	REAR,
}

@onready var legs_sprite:    Sprite2D = $LegsSprite
@onready var torso_sprite:   Sprite2D = $TorsoSprite
@onready var weapon_mount:   Node2D   = $TorsoSprite/WeaponMount
@onready var camera:         Camera2D = $Camera2D

var _movement_type: LegData.MovementType = LegData.MovementType.LEGS
var _speed: float = BASE_SPEED
var _mud_zone_count: int = 0
var _weapons: Array[Node] = []
var _weapon_mounts: Array[Node2D] = []
var _weapon_torso_indices: Array[int] = []
var _weapon_default_actions: Array[String] = []
var _torso_sprites: Array[Sprite2D] = []
var _torso_mount_roots: Array[Node2D] = []
var _torso_deadspot_sides: Array[TorsoDeadspotSide] = []

const MUD_SLOW_FACTOR := 0.4

func enter_mud_zone() -> void:
	_mud_zone_count += 1

func exit_mud_zone() -> void:
	_mud_zone_count = max(0, _mud_zone_count - 1)

func _ready() -> void:
	add_to_group("player")
	# Sprites are drawn facing right (+X).
	# Walkers/spiders start facing up; landship starts horizontal for readability.
	rotation = -PI / 2.0

	# Red arrow showing body forward direction
	var arrow := _DirectionArrow.new()
	arrow.z_index = 5
	add_child(arrow)

	var loadout: MechLoadout = GameManager.current_loadout
	if loadout and loadout.selected_legs:
		_speed         = loadout.selected_legs.speed_modifier * BASE_SPEED
		_movement_type = loadout.selected_legs.movement_type
		_apply_leg_texture(_movement_type)
		if _movement_type == LegData.MovementType.LANDSHIP:
			rotation = 0.0
	_setup_torsos_and_weapons(loadout)

func _setup_torsos_and_weapons(loadout: MechLoadout) -> void:
	var torsos := _get_equipped_torsos(loadout)
	if torsos.is_empty():
		if loadout and loadout.selected_torso:
			torsos = [loadout.selected_torso]
		else:
			return

	var slot_count := torsos.size()
	if loadout and loadout.selected_legs:
		slot_count = mini(slot_count, max(loadout.selected_legs.torso_slots, 1))

	_create_torso_nodes(torsos, slot_count)
	_mount_weapons_for_torsos(torsos, loadout)
	_mount_light_weapons_for_torsos(torsos, loadout)

func _get_equipped_torsos(loadout: MechLoadout) -> Array[TorsoData]:
	var result: Array[TorsoData] = []
	if not loadout:
		return result
	for torso in loadout.selected_torsos:
		if torso:
			result.append(torso)
	if result.is_empty() and loadout.selected_torso:
		result.append(loadout.selected_torso)
	return result

func _create_torso_nodes(torsos: Array[TorsoData], slot_count: int) -> void:
	_torso_sprites.clear()
	_torso_mount_roots.clear()
	_torso_deadspot_sides.clear()
	_weapons.clear()
	_weapon_mounts.clear()
	_weapon_torso_indices.clear()
	_weapon_default_actions.clear()

	var offsets := MechAssembler.get_torso_offsets(slot_count)
	for i in slot_count:
		var torso_data := torsos[i] if i < torsos.size() else null
		if torso_data == null:
			continue

		var sprite: Sprite2D
		var mount_root: Node2D
		if i == 0:
			sprite = torso_sprite
			mount_root = weapon_mount
		else:
			sprite = Sprite2D.new()
			sprite.name = "TorsoSprite%d" % (i + 1)
			sprite.z_index = torso_sprite.z_index
			add_child(sprite)

			mount_root = Node2D.new()
			mount_root.name = "WeaponMount"
			sprite.add_child(mount_root)

		sprite.position = offsets[i] if i < offsets.size() else Vector2.ZERO
		_apply_torso_texture_to_sprite(sprite, torso_data)
		_torso_sprites.append(sprite)
		_torso_mount_roots.append(mount_root)
		_torso_deadspot_sides.append(_get_deadspot_side_for_slot(i, slot_count))

func _get_deadspot_side_for_slot(index: int, slot_count: int) -> TorsoDeadspotSide:
	if slot_count <= 1:
		return TorsoDeadspotSide.NONE
	if slot_count == 2:
		if index == 0:
			return TorsoDeadspotSide.FRONT
		if index == 1:
			return TorsoDeadspotSide.REAR
	return TorsoDeadspotSide.NONE

func _apply_torso_texture(torso: TorsoData) -> void:
	_apply_torso_texture_to_sprite(torso_sprite, torso)

func _apply_torso_texture_to_sprite(target: Sprite2D, torso: TorsoData) -> void:
	var tex: Texture2D = load(torso.get_sprite_path())
	if tex:
		target.texture = tex

# ─── Weapon mounting ──────────────────────────────────────────────────────────
# Positions weapon mounts in TorsoSprite local space and spawns weapons.
# Heavy torso supports two mounts (left + right flank), others have one.
func _mount_weapons(torso_type: TorsoData.TorsoType) -> void:
	var offsets := MechAssembler.get_weapon_offsets(torso_type)
	var loadout: MechLoadout = GameManager.current_loadout
	var guns: Array[WeaponData] = loadout.selected_guns if loadout else []

	# Fallback: mount a default flamethrower if no guns
	if guns.is_empty():
		var default_gun := WeaponData.new()
		default_gun.weapon_type = WeaponData.WeaponType.FLAMETHROWER
		guns = [default_gun]

	for i in mini(offsets.size(), guns.size()):
		var mount: Node2D
		if i == 0:
			mount = weapon_mount
		else:
			mount = Node2D.new()
			mount.name = "WeaponMount%d" % (i + 1)
			torso_sprite.add_child(mount)
		mount.position = offsets[i]
		_weapon_mounts.append(mount)

		var weapon: Node = _instantiate_weapon(guns[i].weapon_type)
		weapon.setup(guns[i])
		var action_name := "fire_%d" % i
		if InputMap.has_action(action_name):
			weapon.fire_action = action_name
		mount.add_child(weapon)
		_weapons.append(weapon)

func _mount_weapons_for_torsos(torsos: Array[TorsoData], loadout: MechLoadout) -> void:
	var guns: Array[WeaponData] = loadout.selected_guns if loadout else []
	if guns.is_empty():
		var default_gun := WeaponData.new()
		default_gun.weapon_type = WeaponData.WeaponType.FLAMETHROWER
		guns = [default_gun]

	var gun_index := 0
	for torso_index in mini(torsos.size(), _torso_mount_roots.size()):
		var offsets := MechAssembler.get_weapon_offsets(torsos[torso_index].torso_type)
		var mount_root := _torso_mount_roots[torso_index]
		for mount_index in offsets.size():
			if gun_index >= guns.size():
				return

			var mount: Node2D
			if mount_index == 0:
				mount = mount_root
			else:
				mount = Node2D.new()
				mount.name = "WeaponMount%d" % (mount_index + 1)
				mount_root.add_child(mount)

			mount.position = offsets[mount_index]
			_weapon_mounts.append(mount)

			var weapon: Node = _instantiate_weapon(guns[gun_index].weapon_type)
			weapon.setup(guns[gun_index])
			var action_name := "fire_%d" % gun_index
			if InputMap.has_action(action_name):
				weapon.fire_action = action_name
			mount.add_child(weapon)
			_register_weapon(weapon, torso_index)
			gun_index += 1

func _instantiate_weapon(weapon_type: WeaponData.WeaponType) -> Node:
	match weapon_type:
		WeaponData.WeaponType.AUTOCANNON:   return AUTOCANNON_SCENE.instantiate()
		WeaponData.WeaponType.LASER:        return LASER_SCENE.instantiate()
		WeaponData.WeaponType.RAILGUN:      return RAILGUN_SCENE.instantiate()
		WeaponData.WeaponType.ROCKET_POD:   return ROCKET_POD_SCENE.instantiate()
		WeaponData.WeaponType.MACHINEGUN:   return MACHINEGUN_SCENE.instantiate()
		_:                                  return FLAMETHROWER_SCENE.instantiate()

static func _get_weapon_offsets(torso_type: TorsoData.TorsoType) -> Array[Vector2]:
	return MechAssembler.get_weapon_offsets(torso_type)

## Mount light weapons on light-slot positions.
func _mount_light_weapons(torso_type: TorsoData.TorsoType) -> void:
	var offsets := MechAssembler.get_light_weapon_offsets(torso_type)
	var loadout: MechLoadout = GameManager.current_loadout
	var guns: Array[WeaponData] = loadout.selected_light_guns if loadout else []

	if guns.is_empty() or offsets.is_empty():
		return

	for i in mini(offsets.size(), guns.size()):
		var mount := Node2D.new()
		mount.name = "LightWeaponMount%d" % (i + 1)
		torso_sprite.add_child(mount)
		mount.position = offsets[i]
		_weapon_mounts.append(mount)

		var weapon: Node = _instantiate_weapon(guns[i].weapon_type)
		weapon.setup(guns[i])
		var light_action := "fire_%d" % (loadout.selected_guns.size() + i)
		if InputMap.has_action(light_action):
			weapon.fire_action = light_action
		mount.add_child(weapon)
		_weapons.append(weapon)

func _mount_light_weapons_for_torsos(torsos: Array[TorsoData], loadout: MechLoadout) -> void:
	var guns: Array[WeaponData] = loadout.selected_light_guns if loadout else []
	if guns.is_empty():
		return

	var light_index := 0
	var medium_count := loadout.selected_guns.size() if loadout else 0
	for torso_index in mini(torsos.size(), _torso_mount_roots.size()):
		var offsets := MechAssembler.get_light_weapon_offsets(torsos[torso_index].torso_type)
		var mount_root := _torso_mount_roots[torso_index]
		for mount_index in offsets.size():
			if light_index >= guns.size():
				return

			var mount := Node2D.new()
			mount.name = "LightWeaponMount%d" % (mount_index + 1)
			mount.position = offsets[mount_index]
			mount_root.add_child(mount)
			_weapon_mounts.append(mount)

			var weapon: Node = _instantiate_weapon(guns[light_index].weapon_type)
			weapon.setup(guns[light_index])
			var light_action := "fire_%d" % (medium_count + light_index)
			if InputMap.has_action(light_action):
				weapon.fire_action = light_action
			mount.add_child(weapon)
			_register_weapon(weapon, torso_index)
			light_index += 1

func _register_weapon(weapon: Node, torso_index: int) -> void:
	_weapons.append(weapon)
	_weapon_torso_indices.append(torso_index)
	_weapon_default_actions.append(String(weapon.get("fire_action")))

# ─── Weapon management API ────────────────────────────────────────────────────
func get_weapons() -> Array[Node]:
	return _weapons

func set_weapon_active(index: int, active: bool) -> void:
	if index < 0 or index >= _weapons.size():
		return
	var weapon := _weapons[index]
	weapon.set_process(active)
	if not active and weapon.has_method("stop_firing"):
		weapon.stop_firing()

func is_weapon_active(index: int) -> bool:
	if index < 0 or index >= _weapons.size():
		return false
	return _weapons[index].is_processing()

func _apply_leg_texture(mtype: LegData.MovementType) -> void:
	var loadout: MechLoadout = GameManager.current_loadout
	if loadout and loadout.selected_legs:
		var tex: Texture2D = load(loadout.selected_legs.get_sprite_path())
		if tex:
			legs_sprite.texture = tex

func _physics_process(delta: float) -> void:
	match _movement_type:
		LegData.MovementType.SPIDER: _move_spider(delta)
		LegData.MovementType.TANK:   _move_tank(delta)
		LegData.MovementType.LANDSHIP: _move_landship(delta)
		LegData.MovementType.LEGS:   _move_legs(delta)
	_rotate_torso_toward_mouse(delta)
	_update_weapon_deadspot_blocks()
	move_and_slide()

# ─── Torso aiming ─────────────────────────────────────────────────────────────
# The torso sprite rotates in local space so it always faces the mouse,
# independent of which direction the hull / legs are pointing.
func _rotate_torso_toward_mouse(delta: float) -> void:
	var mouse_world := get_global_mouse_position()
	var to_mouse := mouse_world - global_position
	if to_mouse.length_squared() < 16.0:
		return
	# Desired angle in world space → convert to torso local space
	var desired_local := to_mouse.angle() - global_rotation
	var step := TORSO_ROTATION_SPEED * delta
	for i in _torso_sprites.size():
		var side := _torso_deadspot_sides[i] if i < _torso_deadspot_sides.size() else TorsoDeadspotSide.NONE
		var clamped_local := apply_torso_deadspot(desired_local, side)
		var sprite := _torso_sprites[i]
		var diff := _compute_deadspot_safe_diff(sprite.rotation, clamped_local, side)
		sprite.rotation += clampf(diff, -step, step)

static func apply_torso_deadspot(
		desired_local: float,
		deadspot_side: TorsoDeadspotSide,
		half_angle: float = TORSO_DEADSPOT_HALF_ANGLE
	) -> float:
	if deadspot_side == TorsoDeadspotSide.NONE or half_angle <= 0.0:
		return desired_local

	var blocked_center := 0.0 if deadspot_side == TorsoDeadspotSide.FRONT else PI
	var rel := wrapf(desired_local - blocked_center, -PI, PI)
	if absf(rel) > half_angle:
		return desired_local

	var left_boundary := wrapf(blocked_center - half_angle, -PI, PI)
	var right_boundary := wrapf(blocked_center + half_angle, -PI, PI)
	var to_left := absf(angle_difference(desired_local, left_boundary))
	var to_right := absf(angle_difference(desired_local, right_boundary))
	return left_boundary if to_left <= to_right else right_boundary

static func _is_angle_in_deadspot(
		angle_local: float,
		deadspot_side: TorsoDeadspotSide,
		half_angle: float = TORSO_DEADSPOT_HALF_ANGLE
	) -> bool:
	if deadspot_side == TorsoDeadspotSide.NONE or half_angle <= 0.0:
		return false
	var blocked_center := 0.0 if deadspot_side == TorsoDeadspotSide.FRONT else PI
	return absf(wrapf(angle_local - blocked_center, -PI, PI)) <= half_angle

static func _path_crosses_deadspot(
		from_angle: float,
		diff: float,
		deadspot_side: TorsoDeadspotSide,
		half_angle: float = TORSO_DEADSPOT_HALF_ANGLE
	) -> bool:
	if deadspot_side == TorsoDeadspotSide.NONE or absf(diff) <= 0.0001:
		return false
	for i in range(1, 9):
		var t := float(i) / 9.0
		var sample := wrapf(from_angle + diff * t, -PI, PI)
		if _is_angle_in_deadspot(sample, deadspot_side, half_angle):
			return true
	return false

static func _compute_deadspot_safe_diff(
		current_angle: float,
		target_angle: float,
		deadspot_side: TorsoDeadspotSide,
		half_angle: float = TORSO_DEADSPOT_HALF_ANGLE
	) -> float:
	var shortest := angle_difference(current_angle, target_angle)
	if deadspot_side == TorsoDeadspotSide.NONE:
		return shortest
	if not _path_crosses_deadspot(current_angle, shortest, deadspot_side, half_angle):
		return shortest
	var long_way := shortest - signf(shortest) * TAU
	if absf(shortest) <= 0.0001:
		long_way = TAU
	if _path_crosses_deadspot(current_angle, long_way, deadspot_side, half_angle):
		return shortest
	return long_way

func _update_weapon_deadspot_blocks() -> void:
	if _torso_sprites.is_empty():
		return
	var mouse_world := get_global_mouse_position()
	var to_mouse := mouse_world - global_position
	if to_mouse.length_squared() < 16.0:
		return
	var desired_local := wrapf(to_mouse.angle() - global_rotation, -PI, PI)

	for i in _weapons.size():
		var torso_index := _weapon_torso_indices[i] if i < _weapon_torso_indices.size() else 0
		var side := _torso_deadspot_sides[torso_index] if torso_index < _torso_deadspot_sides.size() else TorsoDeadspotSide.NONE
		var blocked := _is_angle_in_deadspot(desired_local, side)
		var weapon := _weapons[i]
		if blocked:
			weapon.set("fire_action", "__deadspot_blocked__")
			if weapon.has_method("stop_firing"):
				weapon.stop_firing()
		else:
			if i < _weapon_default_actions.size():
				weapon.set("fire_action", _weapon_default_actions[i])

# ─── Spider ───────────────────────────────────────────────────────────────────
# WASD  →  world-space strafe, equal speed in every direction
# Q / E →  slowly rotate the whole robot (no momentum)
func _move_spider(delta: float) -> void:
	# get_vector returns: x = left(-1)/right(+1), y = up(-1)/down(+1)
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Cardinal only — dominant axis wins
	if absf(raw.x) >= absf(raw.y):
		raw.y = 0.0
	else:
		raw.x = 0.0

	# Project onto hull-local axes so rotation affects movement direction:
	#   transform.x = hull forward (+X in sprite space)
	#   transform.y = hull right   (+Y in sprite space)
	# move_up(W) → -raw.y = forward, move_right(D) → +raw.x = strafe right
	var local_fwd    := -raw.y  # W forward / S backward
	var local_strafe :=  raw.x  # D right   / A left
	var speed_mod := MUD_SLOW_FACTOR if _mud_zone_count > 0 else 1.0
	velocity = (transform.x * local_fwd + transform.y * local_strafe) * _speed * speed_mod

	var rot_dir := (
		float(Input.is_key_pressed(KEY_E)) -
		float(Input.is_key_pressed(KEY_Q))
	)
	rotation += rot_dir * ROTATION_SPEED_SPIDER * delta

# ─── Tank ─────────────────────────────────────────────────────────────────────
# W / S →  drive forward / reverse along facing direction (speed boost)
# Q / E →  slowly rotate the hull
func _move_tank(delta: float) -> void:
	# transform.x = local +X = the facing direction of the sprite
	var fwd := (
		float(Input.is_action_pressed("move_up")) -
		float(Input.is_action_pressed("move_down"))
	)
	var speed_mod := MUD_SLOW_FACTOR if _mud_zone_count > 0 else 1.0
	velocity = transform.x * fwd * _speed * TANK_FORWARD_MULT * speed_mod

	var rot_dir := (
		float(Input.is_key_pressed(KEY_E)) -
		float(Input.is_key_pressed(KEY_Q))
	)
	rotation += rot_dir * ROTATION_SPEED_TANK * delta

# ─── Landship ────────────────────────────────────────────────────────────────
# Same control scheme as tank, but with much slower hull turning.
func _move_landship(delta: float) -> void:
	# transform.x = local +X = the facing direction of the sprite
	var fwd := (
		float(Input.is_action_pressed("move_up")) -
		float(Input.is_action_pressed("move_down"))
	)
	var speed_mod := MUD_SLOW_FACTOR if _mud_zone_count > 0 else 1.0
	velocity = transform.x * fwd * _speed * TANK_FORWARD_MULT * speed_mod

	var rot_dir := (
		float(Input.is_key_pressed(KEY_E)) -
		float(Input.is_key_pressed(KEY_Q))
	)
	rotation += rot_dir * ROTATION_SPEED_LANDSHIP * delta

# ─── Legs (Bipedal — Heavy Walker / Light Walker) ─────────────────────────────
# Q held →  body slowly rotates toward mouse pointer
# W / S  →  walk forward / backward along body facing
# A / D  →  lateral strafe perpendicular to facing
# (diagonal is normalised so speed is always consistent)
func _move_legs(delta: float) -> void:
	# Q held → slowly rotate body toward mouse
	if Input.is_key_pressed(KEY_Q):
		var mouse_world := get_global_mouse_position()
		if global_position.distance_squared_to(mouse_world) > 16.0:
			var desired_angle := (mouse_world - global_position).angle()
			var diff := angle_difference(rotation, desired_angle)
			var step := ROTATION_SPEED_WALKER * delta
			rotation += clampf(diff, -step, step)

	# transform.x = local forward (body facing)
	# transform.y = local right   (perpendicular, clockwise from forward)
	var fwd    := float(Input.is_action_pressed("move_up"))   - float(Input.is_action_pressed("move_down"))
	var strafe := float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))
	var move_dir := transform.x * fwd + transform.y * strafe
	if move_dir.length_squared() > 0.01:
		move_dir = move_dir.normalized()
	var speed_mod := MUD_SLOW_FACTOR if _mud_zone_count > 0 else 1.0
	velocity = move_dir * _speed * speed_mod
