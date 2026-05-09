# player_controller.gd — Player movement controller supporting three movement modes
class_name PlayerController
extends CharacterBody2D

const AUTOCANNON_SCENE   := preload("res://scenes/weapons/autocannon.tscn")
const LASER_SCENE        := preload("res://scenes/weapons/laser.tscn")
const FLAMETHROWER_SCENE := preload("res://scenes/weapons/flamethrower.tscn")
const RAILGUN_SCENE      := preload("res://scenes/weapons/railgun.tscn")
const PLASMA_GUN_SCENE   := preload("res://scenes/weapons/plasma_gun.tscn")
const ROCKET_POD_SCENE   := preload("res://scenes/weapons/rocket_pod.tscn")
const MACHINEGUN_SCENE   := preload("res://scenes/weapons/machinegun.tscn")
const RECON_DRONE_SCENE  := preload("res://scenes/player/recon_drone.tscn")
const _DirectionArrow    := preload("res://src/player/direction_arrow.gd")
const _UTILITY_MODULE_DATA_SCRIPT := preload("res://src/player/utility_module_data.gd")

const BASE_SPEED            := 200.0
const ROTATION_SPEED_SPIDER := 1.8   # rad/s — spider turns a bit quicker
const ROTATION_SPEED_TANK   := 1.2   # rad/s — tank turns very slowly
const ROTATION_SPEED_LANDSHIP := 0.45  # rad/s — landship turns even slower than tank
const TANK_FORWARD_MULT     := 1.3   # extra power in straight-line tank drive
const TORSO_ROTATION_SPEED  := 4.0   # rad/s — torso tracks mouse independently
const ROTATION_SPEED_WALKER := 3.0   # rad/s — walker body rotation toward mouse (Q held)
const TORSO_DEADSPOT_HALF_ANGLE := deg_to_rad(35.0)
const MAX_ENERGY := 100.0
const ENERGY_REGEN_PER_SECOND := 0.0
const ENERGY_REGEN_DELAY := 0.1
const BACKUP_BATTERY_MODULE_NAME := "Backup Battery"
const BACKUP_BATTERY_ENERGY_GAIN := 90.0
const DRONE_MODULE_NAME := "Drone"
const BOOSTER_MODULE_NAME := "Booster"
const BOOSTER_SPEED := 1250.0
const BOOSTER_DURATION := 0.18
const BOOST_VISUAL_EDGE := Color(1.0, 0.46, 0.14, 0.32)
const BOOST_VISUAL_CORE := Color(1.0, 0.9, 0.45, 0.72)
const BOOST_SPRITE_TINT := Color(1.0, 0.88, 0.72, 1.0)

enum TorsoDeadspotSide {
	NONE,
	FRONT,
	REAR,
}

@onready var legs_sprite:    Sprite2D = $LegsSprite
@onready var torso_sprite:   Sprite2D = $TorsoSprite
@onready var weapon_mount:   Node2D   = $TorsoSprite/WeaponMount
@onready var camera:         Camera2D = $Camera2D
@onready var _trample_area:  Area2D   = $TrampleArea

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
var _energy_current: float = MAX_ENERGY
var _energy_regen_block_timer: float = 0.0
var _energy_regen_bonus: float = 0.0  # Bonus from installed modules
var _backup_battery_action_indices: Array[int] = []
var _backup_battery_used: Array[bool] = []
var _drone_modules_by_action: Dictionary = {}
var _booster_modules_by_action: Dictionary = {}
var _active_drone: Node = null
var _drone_firecontrol_active: bool = false
var _boost_timer: float = 0.0
var _boost_velocity: Vector2 = Vector2.ZERO
var _boost_visual_alpha: float = 0.0

const MUD_SLOW_FACTOR := 0.4
const TRAMPLE_MIN_SPEED := 60.0   # px/s — must be moving to crush infantry
const TRAMPLE_DAMAGE    := 20     # enough to one-shot infantry (health=8)
const TRAMPLE_PENETRATION := 10  # guaranteed armor bypass

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
	
	# Calculate energy regen bonus from modules
	if loadout:
		_energy_regen_bonus = loadout.get_total_recharge_bonus()
	
	_setup_torsos_and_weapons(loadout)
	_setup_utility_modules(loadout)


func _exit_tree() -> void:
	if is_instance_valid(_active_drone):
		_active_drone.queue_free()
	_active_drone = null


func _setup_utility_modules(loadout: MechLoadout) -> void:
	_backup_battery_action_indices.clear()
	_backup_battery_used.clear()
	_drone_modules_by_action.clear()
	_booster_modules_by_action.clear()
	if loadout == null:
		return

	var utility_action_index := 0
	var utility_module_data = _UTILITY_MODULE_DATA_SCRIPT.new()
	for module in loadout.selected_utility_modules:
		var module_data = utility_module_data.ensure_module_data(module)
		var module_name := utility_module_data.get_module_name(module_data)
		if module_name.is_empty():
			continue
		if module_name == BACKUP_BATTERY_MODULE_NAME:
			_backup_battery_action_indices.append(utility_action_index)
			_backup_battery_used.append(false)
		elif module_name == DRONE_MODULE_NAME:
			_drone_modules_by_action[utility_action_index] = module_data
		elif module_name == BOOSTER_MODULE_NAME:
			_booster_modules_by_action[utility_action_index] = module_data
		utility_action_index += 1

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
		var gun_data := guns[i]
		if gun_data == null:
			continue

		var mount: Node2D
		if i == 0:
			mount = weapon_mount
		else:
			mount = Node2D.new()
			mount.name = "WeaponMount%d" % (i + 1)
			torso_sprite.add_child(mount)
		mount.position = offsets[i]
		_weapon_mounts.append(mount)

		var weapon: Node = _instantiate_weapon(gun_data.weapon_type)
		weapon.setup(gun_data)
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

			var action_name := "fire_%d" % gun_index
			var gun_data := guns[gun_index]
			gun_index += 1
			if gun_data == null:
				continue

			var mount: Node2D
			if mount_index == 0:
				mount = mount_root
			else:
				mount = Node2D.new()
				mount.name = "WeaponMount%d" % (mount_index + 1)
				mount_root.get_parent().add_child(mount)

			mount.position = offsets[mount_index]
			_weapon_mounts.append(mount)

			var weapon: Node = _instantiate_weapon(gun_data.weapon_type)
			weapon.setup(gun_data)
			if InputMap.has_action(action_name):
				weapon.fire_action = action_name
			mount.add_child(weapon)
			_register_weapon(weapon, torso_index)

func _instantiate_weapon(weapon_type: WeaponData.WeaponType) -> Node:
	match weapon_type:
		WeaponData.WeaponType.AUTOCANNON:   return AUTOCANNON_SCENE.instantiate()
		WeaponData.WeaponType.LASER:        return LASER_SCENE.instantiate()
		WeaponData.WeaponType.RAILGUN:      return RAILGUN_SCENE.instantiate()
		WeaponData.WeaponType.PLASMA_GUN:   return PLASMA_GUN_SCENE.instantiate()
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
		var gun_data := guns[i]
		if gun_data == null:
			continue

		var mount := Node2D.new()
		mount.name = "LightWeaponMount%d" % (i + 1)
		torso_sprite.add_child(mount)
		mount.position = offsets[i]
		_weapon_mounts.append(mount)

		var weapon: Node = _instantiate_weapon(gun_data.weapon_type)
		weapon.setup(gun_data)
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

			var light_action := "fire_%d" % (medium_count + light_index)
			var gun_data := guns[light_index]
			light_index += 1
			if gun_data == null:
				continue

			var mount := Node2D.new()
			mount.name = "LightWeaponMount%d" % (mount_index + 1)
			mount.position = offsets[mount_index]
			mount_root.add_child(mount)
			_weapon_mounts.append(mount)

			var weapon: Node = _instantiate_weapon(gun_data.weapon_type)
			weapon.setup(gun_data)
			if InputMap.has_action(light_action):
				weapon.fire_action = light_action
			mount.add_child(weapon)
			_register_weapon(weapon, torso_index)

func _register_weapon(weapon: Node, torso_index: int) -> void:
	_weapons.append(weapon)
	_weapon_torso_indices.append(torso_index)
	_weapon_default_actions.append(String(weapon.get("fire_action")))

# ─── Weapon management API ────────────────────────────────────────────────────
func get_weapons() -> Array[Node]:
	return _weapons

func get_energy() -> float:
	return _energy_current

func get_max_energy() -> float:
	return MAX_ENERGY

func get_energy_ratio() -> float:
	return _energy_current / MAX_ENERGY if MAX_ENERGY > 0.0 else 0.0


func add_energy(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var previous := _energy_current
	_energy_current = minf(MAX_ENERGY, _energy_current + amount)
	return _energy_current - previous

func has_energy_for(amount: float) -> bool:
	return _energy_current + 0.0001 >= amount

func consume_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not has_energy_for(amount):
		return false
	_energy_current = maxf(0.0, _energy_current - amount)
	_energy_regen_block_timer = ENERGY_REGEN_DELAY
	return true


func get_backup_battery_count() -> int:
	var remaining := 0
	for used in _backup_battery_used:
		if not used:
			remaining += 1
	return remaining


func is_boosting() -> bool:
	return _boost_timer > 0.0


func get_boost_velocity() -> Vector2:
	return _boost_velocity


func get_boost_visual_intensity() -> float:
	return _boost_visual_alpha


func is_drone_view_active() -> bool:
	return is_instance_valid(_active_drone)


func get_active_drone() -> Node:
	return _active_drone


func is_drone_firecontrol_active() -> bool:
	return _drone_firecontrol_active and is_drone_view_active()


func set_drone_firecontrol_active(active: bool) -> void:
	_drone_firecontrol_active = active and is_drone_view_active()
	_update_weapon_deadspot_blocks()


func exit_active_drone() -> void:
	if is_instance_valid(_active_drone):
		_active_drone.queue_free()
	else:
		_end_recon_drone_view()


func get_drone_battery() -> float:
	if not is_instance_valid(_active_drone):
		return 0.0
	if _active_drone.has_method("get_battery"):
		return float(_active_drone.call("get_battery"))
	return 0.0


func get_drone_max_battery() -> float:
	if not is_instance_valid(_active_drone):
		return 100.0
	if _active_drone.has_method("get_max_battery"):
		return float(_active_drone.call("get_max_battery"))
	return 100.0


## Returns one icon key per currently available consumable utility.
## This is intentionally generic so HUD can render consumables without
## utility-specific labels.
func get_consumable_utility_icon_keys() -> Array[String]:
	var keys: Array[String] = []
	for _i in get_backup_battery_count():
		keys.append("backup_battery")
	for _action_index in _drone_modules_by_action:
		keys.append("drone")
	for _action_index in _booster_modules_by_action:
		keys.append("booster")
	return keys


func _consume_backup_battery_for_action(action_index: int) -> bool:
	for i in _backup_battery_action_indices.size():
		if _backup_battery_used[i]:
			continue
		if _backup_battery_action_indices[i] != action_index:
			continue
		_backup_battery_used[i] = true
		add_energy(BACKUP_BATTERY_ENERGY_GAIN)
		return true
	return false


func _activate_booster_for_action(action_index: int) -> bool:
	if not _booster_modules_by_action.has(action_index):
		return false
	var module = _booster_modules_by_action[action_index]
	_booster_modules_by_action.erase(action_index)
	var direction_angle := float(module.get("direction_angle") if module != null else 0.0)
	var local_direction := Vector2.RIGHT.rotated(direction_angle)
	var world_direction := transform.x * local_direction.x + transform.y * local_direction.y
	if world_direction.length_squared() <= 0.0001:
		world_direction = transform.x
	_boost_timer = BOOSTER_DURATION
	_boost_velocity = world_direction.normalized() * BOOSTER_SPEED
	velocity = _boost_velocity
	_update_boost_visuals()
	return true


func _activate_drone_for_action(action_index: int) -> bool:
	if is_drone_view_active():
		return false
	if not _drone_modules_by_action.has(action_index):
		return false
	_drone_modules_by_action.erase(action_index)
	_spawn_recon_drone()
	return true


func _spawn_recon_drone() -> void:
	var drone := RECON_DRONE_SCENE.instantiate()
	if drone == null:
		return

	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(drone)
	drone.global_position = global_position + transform.x * 28.0

	if drone.has_method("set_launch_velocity"):
		drone.call("set_launch_velocity", transform.x)

	_active_drone = drone
	_drone_firecontrol_active = false
	if drone.has_signal("battery_depleted"):
		drone.connect("battery_depleted", Callable(self, "_on_recon_drone_battery_depleted"), CONNECT_ONE_SHOT)
	drone.tree_exited.connect(_on_recon_drone_exited, CONNECT_ONE_SHOT)

	camera.enabled = false
	if drone.has_method("set_active_view"):
		drone.call("set_active_view", true)


func _on_recon_drone_battery_depleted() -> void:
	_end_recon_drone_view()


func _on_recon_drone_exited() -> void:
	_end_recon_drone_view()


func _end_recon_drone_view() -> void:
	_drone_firecontrol_active = false
	_active_drone = null
	if is_instance_valid(camera):
		camera.enabled = true
		if camera.is_inside_tree():
			camera.make_current()
	_restore_default_weapon_actions()


func _restore_default_weapon_actions() -> void:
	for i in _weapons.size():
		if i < _weapon_default_actions.size():
			_weapons[i].set("fire_action", _weapon_default_actions[i])


func _update_boost(delta: float) -> bool:
	if _boost_timer <= 0.0:
		if _boost_visual_alpha > 0.0:
			_update_boost_visuals()
		return false
	_boost_timer = maxf(0.0, _boost_timer - delta)
	velocity = _boost_velocity
	if _boost_timer == 0.0:
		_boost_velocity = Vector2.ZERO
	_update_boost_visuals()
	return true


func _update_boost_visuals() -> void:
	var next_alpha := 0.0
	if _boost_timer > 0.0 and BOOSTER_DURATION > 0.0:
		next_alpha = clampf(_boost_timer / BOOSTER_DURATION, 0.0, 1.0)
	if is_equal_approx(next_alpha, _boost_visual_alpha):
		return
	_boost_visual_alpha = next_alpha
	var tint_strength := _boost_visual_alpha * 0.45
	legs_sprite.modulate = Color.WHITE.lerp(BOOST_SPRITE_TINT, tint_strength)
	for sprite in _torso_sprites:
		sprite.modulate = Color.WHITE.lerp(BOOST_SPRITE_TINT, tint_strength)
	queue_redraw()


func _draw() -> void:
	if _boost_visual_alpha <= 0.0 or _boost_velocity.length_squared() <= 0.001:
		return
	var local_boost_direction: Vector2 = _boost_velocity.normalized().rotated(-global_rotation)
	if local_boost_direction.length_squared() <= 0.001:
		return
	local_boost_direction = local_boost_direction.normalized()
	var trail_direction := -local_boost_direction
	var trail_side := local_boost_direction.orthogonal().normalized()
	var edge_length := lerpf(20.0, 52.0, _boost_visual_alpha)
	var core_length := edge_length * 0.62
	var edge_width := lerpf(10.0, 24.0, _boost_visual_alpha)
	var core_width := edge_width * 0.45
	var edge_tip := trail_direction * edge_length
	var core_tip := trail_direction * core_length
	var edge_poly := PackedVector2Array([
		trail_side * 6.0,
		-trail_side * 6.0,
		edge_tip - trail_side * edge_width,
		edge_tip + trail_side * edge_width,
	])
	var core_poly := PackedVector2Array([
		trail_side * 3.0,
		-trail_side * 3.0,
		core_tip - trail_side * core_width,
		core_tip + trail_side * core_width,
	])
	var edge_color := BOOST_VISUAL_EDGE
	edge_color.a *= _boost_visual_alpha
	var core_color := BOOST_VISUAL_CORE
	core_color.a *= _boost_visual_alpha
	draw_colored_polygon(edge_poly, edge_color)
	draw_colored_polygon(core_poly, core_color)
	draw_line(Vector2.ZERO, core_tip, core_color, lerpf(3.0, 8.0, _boost_visual_alpha), true)


func _process_utility_modules_input() -> void:
	if _backup_battery_action_indices.is_empty() and _drone_modules_by_action.is_empty() and _booster_modules_by_action.is_empty():
		return
	var pressed_action_indices: Array[int] = []
	for action_index in GameManager.utility_bindings.size():
		var action_name := "utility_%d" % action_index
		if not InputMap.has_action(action_name):
			continue
		if not Input.is_action_just_pressed(action_name):
			continue
		pressed_action_indices.append(action_index)
	_process_pressed_utility_actions(pressed_action_indices)


func _process_pressed_utility_actions(action_indices: Array[int]) -> void:
	for action_index in action_indices:
		if _activate_drone_for_action(action_index):
			break
		if _activate_booster_for_action(action_index):
			break
		# If several utilities share one key, consume only one per press.
		if _consume_backup_battery_for_action(action_index):
			break

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
	_regen_energy(delta)
	if is_drone_view_active():
		velocity = Vector2.ZERO
		if _drone_firecontrol_active:
			_rotate_torso_toward_mouse(delta)
		_update_weapon_deadspot_blocks()
		return
	_process_utility_modules_input()
	if not _update_boost(delta):
		match _movement_type:
			LegData.MovementType.SPIDER: _move_spider(delta)
			LegData.MovementType.TANK:   _move_tank(delta)
			LegData.MovementType.LANDSHIP: _move_landship(delta)
			LegData.MovementType.LEGS:   _move_legs(delta)
	_rotate_torso_toward_mouse(delta)
	_update_weapon_deadspot_blocks()
	move_and_slide()
	_trample_infantry()

func _trample_infantry() -> void:
	if velocity.length() < TRAMPLE_MIN_SPEED:
		return
	for body in _trample_area.get_overlapping_bodies():
		if body is EnemyInfantry:
			body.take_damage(TRAMPLE_DAMAGE, TRAMPLE_PENETRATION)

func _regen_energy(delta: float) -> void:
	if _energy_regen_block_timer > 0.0:
		_energy_regen_block_timer = maxf(0.0, _energy_regen_block_timer - delta)
		return
	if _energy_current >= MAX_ENERGY:
		return
	var total_regen := ENERGY_REGEN_PER_SECOND + _energy_regen_bonus
	_energy_current = minf(MAX_ENERGY, _energy_current + total_regen * delta)

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
	if _weapons.is_empty():
		return

	if is_drone_view_active() and not _drone_firecontrol_active:
		for weapon in _weapons:
			weapon.set("fire_action", "__drone_firecontrol_off__")
			if weapon.has_method("stop_firing"):
				weapon.stop_firing()
		return

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
