# mech_catalog.gd — Static factory that constructs all available mech parts.
# Keeps MechLoadout as a pure data container by moving part-creation logic here.
# Add entries to each method to expand the in-game selection.
class_name MechCatalog

## Returns all available torso configurations
static func get_all_torsos() -> Array[TorsoData]:
	var stealth := TorsoData.new()
	stealth.name           = "Stealth"
	stealth.description    = "Sleek triangular hull. Cuts through resistance — fast but thin armour."
	stealth.torso_type     = TorsoData.TorsoType.STEALTH
	stealth.tutorial_text  = "Low profile — harder for enemies to track\nHigh speed, light armour"
	stealth.speed_modifier  = 1.2
	stealth.light_weapon_slots = 1

	var heavy := TorsoData.new()
	heavy.name           = "Heavy Armour"
	heavy.description    = "Forward-facing dome hull. Absorbs tremendous punishment."
	heavy.torso_type     = TorsoData.TorsoType.HEAVY_ARMOUR
	heavy.tutorial_text  = "Reinforced hull plating — reduced mobility\nExcellent weapon coverage"
	heavy.speed_modifier  = 0.8
	heavy.weapon_slots    = 2
	heavy.light_weapon_slots = 0

	var cargo := TorsoData.new()
	cargo.name           = "Cargo"
	cargo.description    = "Utility trapezoid hull. Balanced loadout with extra storage."
	cargo.torso_type     = TorsoData.TorsoType.CARGO
	cargo.tutorial_text  = "Balanced speed and utility\nExtra pickup radius (passive)"
	cargo.speed_modifier  = 1.0
	cargo.light_weapon_slots = 2

	return [stealth, heavy, cargo]

## Returns all available leg configurations
static func get_all_legs() -> Array[LegData]:
	var tank := LegData.new()
	tank.name           = "Tank"
	tank.description    = "Treaded chassis. Incredibly tough but very slow."
	tank.movement_type  = LegData.MovementType.TANK
	tank.tutorial_text  = "[W/S]  Drive forward / reverse\n[Q/E]  Rotate hull slowly\nSlow but tough — wide turning circle"
	tank.speed_modifier  = 0.6

	var landship := LegData.new()
	landship.name           = "Landship"
	landship.description    = "Massive treaded behemoth. Extremely slow, built for dual-torso broadsides."
	landship.movement_type  = LegData.MovementType.LANDSHIP
	landship.tutorial_text  = "[W/S]  Drive forward / reverse\n[Q/E]  Rotate hull very slowly\nTwin torso hardpoints with blocked inward arcs"
	landship.speed_modifier = 0.35
	landship.torso_slots    = 2

	var heavy_walker := LegData.new()
	heavy_walker.name           = "Heavy Walker"
	heavy_walker.description    = "Bipedal heavy frame. Good armor, moderate speed."
	heavy_walker.movement_type  = LegData.MovementType.LEGS
	heavy_walker.tutorial_text  = "[W/S]  Forward / back toward cursor\n[A/D]  Lateral strafe\n[Mouse]  Robot auto-aims\nSturdy frame — steady pace"
	heavy_walker.speed_modifier  = 0.85

	var light_walker := LegData.new()
	light_walker.name           = "Light Walker"
	light_walker.description    = "Nimble bipedal frame. Balanced speed and armor."
	light_walker.movement_type  = LegData.MovementType.LEGS
	light_walker.tutorial_text  = "[W/S]  Forward / back toward cursor\n[A/D]  Lateral strafe\n[Mouse]  Robot auto-aims\nFast & nimble — lightweight"
	light_walker.speed_modifier  = 1.1

	var spider := LegData.new()
	spider.name           = "Spider"
	spider.description    = "Multi-legged chassis. Very fast but fragile."
	spider.movement_type  = LegData.MovementType.SPIDER
	spider.tutorial_text  = "[WASD]  Strafe any direction\n[Q/E]  Rotate hull slowly\nBlinding speed — lightweight"
	spider.speed_modifier  = 1.5

	return [tank, landship, heavy_walker, light_walker, spider]

## Returns all available weapon configurations
static func get_all_guns() -> Array[WeaponData]:
	var autocannon := WeaponData.new()
	autocannon.name             = "Autocannon"
	autocannon.weapon_type      = WeaponData.WeaponType.AUTOCANNON
	autocannon.damage           = 8
	autocannon.cooldown         = 0.3
	autocannon.projectile_speed = 500.0
	autocannon.projectile_count = 1
	autocannon.pierce           = 1

	var flamethrower := WeaponData.new()
	flamethrower.name             = "Chemical thrower"
	flamethrower.weapon_type      = WeaponData.WeaponType.FLAMETHROWER
	flamethrower.damage           = 3
	flamethrower.cooldown         = 0.1
	flamethrower.projectile_speed = 200.0
	flamethrower.projectile_count = 3
	flamethrower.pierce           = 3
	flamethrower.area             = 1.5

	var railgun := WeaponData.new()
	railgun.name             = "Railgun"
	railgun.weapon_type      = WeaponData.WeaponType.RAILGUN
	railgun.damage           = 50
	railgun.cooldown         = 2.0
	railgun.projectile_speed = 1200.0
	railgun.projectile_count = 1
	railgun.pierce           = 10

	var laser := WeaponData.new()
	laser.name             = "Laser"
	laser.weapon_type      = WeaponData.WeaponType.LASER
	laser.damage           = 12
	laser.cooldown         = 0.05
	laser.projectile_speed = 0.0
	laser.projectile_count = 1
	laser.pierce           = 99
	laser.area             = 0.5

	var plasma_gun := WeaponData.new()
	plasma_gun.name             = "Plasma Gun"
	plasma_gun.weapon_type      = WeaponData.WeaponType.PLASMA_GUN
	plasma_gun.damage           = 24
	plasma_gun.cooldown         = 1.1
	plasma_gun.projectile_speed = 360.0
	plasma_gun.projectile_count = 1
	plasma_gun.pierce           = 2
	plasma_gun.penetration      = 5
	plasma_gun.projectile_lifetime = 2.2

	return [autocannon, flamethrower, railgun, laser, plasma_gun]

## Returns all available light weapon configurations
static func get_all_light_guns() -> Array[WeaponData]:
	var rocket_pod := WeaponData.new()
	rocket_pod.name             = "Rocket Pod"
	rocket_pod.weapon_type      = WeaponData.WeaponType.ROCKET_POD
	rocket_pod.slot_size        = WeaponData.SlotSize.LIGHT
	rocket_pod.damage           = 15
	rocket_pod.cooldown         = 1.2
	rocket_pod.projectile_speed = 400.0
	rocket_pod.projectile_count = 3
	rocket_pod.pierce           = 1
	rocket_pod.area             = 1.2

	var machinegun := WeaponData.new()
	machinegun.name             = "Machinegun"
	machinegun.weapon_type      = WeaponData.WeaponType.MACHINEGUN
	machinegun.slot_size        = WeaponData.SlotSize.LIGHT
	machinegun.damage           = 3
	machinegun.cooldown         = 0.1
	machinegun.projectile_speed = 600.0
	machinegun.projectile_count = 1
	machinegun.pierce           = 1
	machinegun.penetration      = 4

	return [rocket_pod, machinegun]

## Returns all available module configurations
static func get_all_modules() -> Array:
	const _ModuleData = preload("res://src/player/module_data.gd")
	
	# 2x2 Reactor: Larger footprint, bigger bonus
	var reactor_2x2 = _ModuleData.new()
	reactor_2x2.name              = "Reactor (2x2)"
	reactor_2x2.description       = "Large power reactor. Significantly boosts energy regeneration."
	reactor_2x2.tutorial_text     = "Occupies 4 grid slots. Adds +5 energy per second."
	reactor_2x2.recharge_rate_bonus = 5.0
	var shape_2x2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	reactor_2x2.grid_shape        = shape_2x2
	reactor_2x2.grid_cell_color   = Color.DODGER_BLUE
	reactor_2x2.module_icon_path  = "res://assets/sprites/module_reactor_2x2.svg"

	# 1x1 Reactor Module: Single slot, smaller bonus
	var reactor_1x1 = _ModuleData.new()
	reactor_1x1.name              = "Reactor Module"
	reactor_1x1.description       = "Compact energy module. Modest energy regeneration boost."
	reactor_1x1.tutorial_text     = "Occupies 1 grid slot. Adds +1 energy per second."
	reactor_1x1.recharge_rate_bonus = 1.0
	var shape_1x1: Array[Vector2i] = [Vector2i(0, 0)]
	reactor_1x1.grid_shape        = shape_1x1
	reactor_1x1.grid_cell_color   = Color.CORNFLOWER_BLUE
	reactor_1x1.module_icon_path  = "res://assets/sprites/module_reactor_1x1.svg"

	# 2x1 Armor Module: Two slots, strong armor bonus
	var armor_2x1 = _ModuleData.new()
	armor_2x1.name              = "Armor Module (2x1)"
	armor_2x1.description       = "Reinforced plating strip. Improves survivability."
	armor_2x1.tutorial_text     = "Occupies 2 grid slots. Adds +3 armor."
	armor_2x1.armor_bonus       = 3
	var shape_2x1: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	armor_2x1.grid_shape        = shape_2x1
	armor_2x1.grid_cell_color   = Color(0.86, 0.58, 0.18, 1.0)
	armor_2x1.module_icon_path  = "res://assets/sprites/module_reactor_2x2.svg"

	# 1x1 Armor Module: Single slot, light armor bonus
	var armor_1x1 = _ModuleData.new()
	armor_1x1.name              = "Armor Module (1x1)"
	armor_1x1.description       = "Compact armor tile. Adds a small armor boost."
	armor_1x1.tutorial_text     = "Occupies 1 grid slot. Adds +1 armor."
	armor_1x1.armor_bonus       = 1
	armor_1x1.grid_shape        = shape_1x1
	armor_1x1.grid_cell_color   = Color(0.95, 0.74, 0.24, 1.0)
	armor_1x1.module_icon_path  = "res://assets/sprites/module_reactor_1x1.svg"

	# Diagonal 1-1 Super-Structure Module: two diagonal cells, large structure bonus
	var redundant_super_structure = _ModuleData.new()
	redundant_super_structure.name              = "Redundant Super-Structure"
	redundant_super_structure.description       = "Reinforced internal lattice that greatly increases survivability."
	redundant_super_structure.tutorial_text     = "Diagonal 1-1 footprint. Adds +30 structure HP."
	redundant_super_structure.max_health_bonus  = 30
	var shape_diagonal_1_1: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
	redundant_super_structure.grid_shape        = shape_diagonal_1_1
	redundant_super_structure.grid_cell_color   = Color.GREEN
	redundant_super_structure.module_icon_path  = "res://assets/sprites/module_reactor_1x1.svg"

	return [reactor_2x2, reactor_1x1, armor_2x1, armor_1x1, redundant_super_structure]

