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
	stealth.tutorial_text  = "Low profile — harder for enemies to track\nSpeed bonus, minimal integrity"
	stealth.speed_modifier  = 1.2
	stealth.integrity       = 2
	stealth.light_weapon_slots = 1

	var heavy := TorsoData.new()
	heavy.name           = "Heavy Armour"
	heavy.description    = "Forward-facing dome hull. Absorbs tremendous punishment."
	heavy.torso_type     = TorsoData.TorsoType.HEAVY_ARMOUR
	heavy.tutorial_text  = "Maximum integrity — reduced mobility\nTakes hits the other torsos can't"
	heavy.speed_modifier  = 0.8
	heavy.integrity       = 8
	heavy.weapon_slots    = 2
	heavy.light_weapon_slots = 0

	var cargo := TorsoData.new()
	cargo.name           = "Cargo"
	cargo.description    = "Utility trapezoid hull. Balanced loadout with extra storage."
	cargo.torso_type     = TorsoData.TorsoType.CARGO
	cargo.tutorial_text  = "Balanced speed and integrity\nExtra pickup radius (passive)"
	cargo.speed_modifier  = 1.0
	cargo.integrity       = 4
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

	return [autocannon, flamethrower, railgun, laser]

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
