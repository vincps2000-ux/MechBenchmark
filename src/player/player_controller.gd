# player_controller.gd — Player movement controller supporting three movement modes
class_name PlayerController
extends CharacterBody2D

const LASER_SCENE        := preload("res://scenes/weapons/laser.tscn")
const FLAMETHROWER_SCENE := preload("res://scenes/weapons/flamethrower.tscn")

const BASE_SPEED            := 200.0
const ROTATION_SPEED_SPIDER := 1.8   # rad/s — spider turns a bit quicker
const ROTATION_SPEED_TANK   := 1.2   # rad/s — tank turns very slowly
const TANK_FORWARD_MULT     := 1.3   # extra power in straight-line tank drive
const TORSO_ROTATION_SPEED  := 4.0   # rad/s — torso tracks mouse independently

@onready var legs_sprite:    Sprite2D = $LegsSprite
@onready var torso_sprite:   Sprite2D = $TorsoSprite
@onready var weapon_mount:   Node2D   = $TorsoSprite/WeaponMount
@onready var camera:         Camera2D = $Camera2D

var _movement_type: LegData.MovementType = LegData.MovementType.LEGS
var _speed: float = BASE_SPEED

func _ready() -> void:
	# Sprites are drawn facing right (+X); start the robot facing up
	rotation = -PI / 2.0

	var loadout: MechLoadout = GameManager.current_loadout
	if loadout and loadout.selected_legs:
		_speed         = loadout.selected_legs.speed_modifier * BASE_SPEED
		_movement_type = loadout.selected_legs.movement_type
		_apply_leg_texture(_movement_type)
	if loadout and loadout.selected_torso:
		_apply_torso_texture(loadout.selected_torso)
		_mount_weapon(loadout.selected_torso.torso_type)

func _apply_torso_texture(torso: TorsoData) -> void:
	var tex: Texture2D = load(torso.get_sprite_path())
	if tex:
		torso_sprite.texture = tex

# ─── Weapon mounting ──────────────────────────────────────────────────────────
# Positions the weapon mount in TorsoSprite local space, then spawns the laser.
#
# All torso SVGs are 48×48.  With centred=true the sprite origin sits at the
# texture centre (pixel 24,24).  Local +X = forward (right in sprite space);
# local +Y = right-flank (down in sprite space).
#
# ▸ HEAVY   — half-dome: gun mounts on the RIGHT flank
# ▸ STEALTH — triangle:  gun sits ON the torso (forward-centre)
# ▸ CARGO   — trapezoid: gun is bolted to the BACK
func _mount_weapon(torso_type: TorsoData.TorsoType) -> void:
	# Offset in TorsoSprite-local pixels
	var offset: Vector2
	match torso_type:
		TorsoData.TorsoType.HEAVY_ARMOUR: offset = Vector2(4.0,  17.0)   # right flank
		TorsoData.TorsoType.STEALTH:      offset = Vector2(10.0,  0.0)   # on torso
		TorsoData.TorsoType.CARGO:        offset = Vector2(-17.0, 0.0)   # back
		_:                                offset = Vector2(0.0,   0.0)
	weapon_mount.position = offset

	var loadout: MechLoadout = GameManager.current_loadout
	var gun_data: WeaponData = loadout.selected_gun if loadout else null

	# Dispatch to the correct scene based on the typed enum — no magic strings
	var weapon: Node
	if gun_data and gun_data.weapon_type == WeaponData.WeaponType.LASER:
		weapon = LASER_SCENE.instantiate()
	else:
		weapon = FLAMETHROWER_SCENE.instantiate()

	# Give the weapon its data so it can read damage / cooldown from the loadout
	if gun_data:
		weapon.setup(gun_data)
	weapon_mount.add_child(weapon)

func _apply_leg_texture(mtype: LegData.MovementType) -> void:
	var path: String
	match mtype:
		LegData.MovementType.SPIDER: path = "res://assets/sprites/legs_spider.svg"
		LegData.MovementType.TANK:   path = "res://assets/sprites/legs_tank.svg"
		LegData.MovementType.LEGS:   path = "res://assets/sprites/legs_bipedal.svg"
		_:                           path = "res://assets/sprites/legs_bipedal.svg"
	var tex: Texture2D = load(path)
	if tex:
		legs_sprite.texture = tex

func _physics_process(delta: float) -> void:
	match _movement_type:
		LegData.MovementType.SPIDER: _move_spider(delta)
		LegData.MovementType.TANK:   _move_tank(delta)
		LegData.MovementType.LEGS:   _move_legs()
	_rotate_torso_toward_mouse(delta)
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
	var diff := angle_difference(torso_sprite.rotation, desired_local)
	var step := TORSO_ROTATION_SPEED * delta
	torso_sprite.rotation += clampf(diff, -step, step)

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
	velocity = (transform.x * local_fwd + transform.y * local_strafe) * _speed

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
	velocity = transform.x * fwd * _speed * TANK_FORWARD_MULT

	var rot_dir := (
		float(Input.is_key_pressed(KEY_E)) -
		float(Input.is_key_pressed(KEY_Q))
	)
	rotation += rot_dir * ROTATION_SPEED_TANK * delta

# ─── Legs (Bipedal — Heavy Walker / Light Walker) ─────────────────────────────
# Auto  →  robot snaps to face the mouse cursor first
# W / S →  walk forward / backward along that facing direction
# A / D →  lateral strafe perpendicular to facing
# (diagonal is normalised so speed is always consistent)
func _move_legs() -> void:
	# Rotate to face mouse BEFORE computing velocity so the axes are up to date
	var mouse_world := get_global_mouse_position()
	if global_position.distance_squared_to(mouse_world) > 16.0:
		look_at(mouse_world)

	# transform.x = local forward (toward mouse)
	# transform.y = local right   (perpendicular, clockwise from forward)
	var fwd    := float(Input.is_action_pressed("move_up"))   - float(Input.is_action_pressed("move_down"))
	var strafe := float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))
	var move_dir := transform.x * fwd + transform.y * strafe
	if move_dir.length_squared() > 0.01:
		move_dir = move_dir.normalized()
	velocity = move_dir * _speed
