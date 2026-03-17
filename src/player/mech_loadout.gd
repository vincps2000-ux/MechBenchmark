# mech_loadout.gd — Holds the player's workshop selections (legs + torso + gun)
class_name MechLoadout
extends Resource

@export var selected_legs: LegData = null
@export var selected_torso: TorsoData = null
@export var selected_gun: WeaponData = null

## Returns true if the loadout has legs, a torso, and a gun selected
func is_valid() -> bool:
	return selected_legs != null and selected_torso != null and selected_gun != null

## Apply the loadout modifiers to the given PlayerStats
func apply_to_stats(stats: PlayerStats) -> void:
	if selected_legs:
		selected_legs.apply_to_stats(stats)
	if selected_torso:
		selected_torso.apply_to_stats(stats)

## Factory: returns all 3 available torso types
static func get_all_torsos() -> Array[TorsoData]:
	var stealth = TorsoData.new()
	stealth.name = "Stealth"
	stealth.description = "Sleek triangular hull. Cuts through resistance — fast but thin armour."
	stealth.torso_type = TorsoData.TorsoType.STEALTH
	stealth.tutorial_text = "Low profile — harder for enemies to track\nSpeed bonus, reduced HP"
	stealth.speed_modifier = 1.2
	stealth.health_modifier = 0.8

	var heavy = TorsoData.new()
	heavy.name = "Heavy Armour"
	heavy.description = "Forward-facing dome hull. Absorbs tremendous punishment."
	heavy.torso_type = TorsoData.TorsoType.HEAVY_ARMOUR
	heavy.tutorial_text = "Massive HP pool — reduced mobility\nTakes hits the other torsos can't"
	heavy.speed_modifier = 0.8
	heavy.health_modifier = 1.6

	var cargo = TorsoData.new()
	cargo.name = "Cargo"
	cargo.description = "Utility trapezoid hull. Balanced loadout with extra storage."
	cargo.torso_type = TorsoData.TorsoType.CARGO
	cargo.tutorial_text = "Balanced speed and armour\nExtra pickup radius (passive)"
	cargo.speed_modifier = 1.0
	cargo.health_modifier = 1.1

	return [stealth, heavy, cargo]

## Factory: returns all 4 available leg types
static func get_all_legs() -> Array[LegData]:
	var tank = LegData.new()
	tank.name = "Tank"
	tank.description = "Treaded chassis. Incredibly tough but very slow."
	tank.movement_type = LegData.MovementType.TANK
	tank.tutorial_text = "[W/S]  Drive forward / reverse\n[Q/E]  Rotate hull slowly\nHigh armour — wide turning circle"
	tank.speed_modifier = 0.6
	tank.health_modifier = 1.8

	var heavy_walker = LegData.new()
	heavy_walker.name = "Heavy Walker"
	heavy_walker.description = "Bipedal heavy frame. Good armor, moderate speed."
	heavy_walker.movement_type = LegData.MovementType.LEGS
	heavy_walker.tutorial_text = "[W/S]  Forward / back toward cursor\n[A/D]  Lateral strafe\n[Mouse]  Robot auto-aims\nGood armour — steady pace"
	heavy_walker.speed_modifier = 0.85
	heavy_walker.health_modifier = 1.4

	var light_walker = LegData.new()
	light_walker.name = "Light Walker"
	light_walker.description = "Nimble bipedal frame. Balanced speed and armor."
	light_walker.movement_type = LegData.MovementType.LEGS
	light_walker.tutorial_text = "[W/S]  Forward / back toward cursor\n[A/D]  Lateral strafe\n[Mouse]  Robot auto-aims\nFast & nimble — low armour"
	light_walker.speed_modifier = 1.1
	light_walker.health_modifier = 1.0

	var spider = LegData.new()
	spider.name = "Spider"
	spider.description = "Multi-legged chassis. Very fast but fragile."
	spider.movement_type = LegData.MovementType.SPIDER
	spider.tutorial_text = "[WASD]  Strafe any direction\n[Q/E]  Rotate hull slowly\nBlinding speed — very fragile"
	spider.speed_modifier = 1.5
	spider.health_modifier = 0.7

	return [tank, heavy_walker, light_walker, spider]

## Factory: returns all 4 available gun types
static func get_all_guns() -> Array[WeaponData]:
	var autocannon = WeaponData.new()
	autocannon.name = "Autocannon"
	autocannon.damage = 8
	autocannon.cooldown = 0.3
	autocannon.projectile_speed = 500.0
	autocannon.projectile_count = 1
	autocannon.pierce = 1

	var flamethrower = WeaponData.new()
	flamethrower.name = "Flamethrower"
	flamethrower.damage = 3
	flamethrower.cooldown = 0.1
	flamethrower.projectile_speed = 200.0
	flamethrower.projectile_count = 3
	flamethrower.pierce = 3
	flamethrower.area = 1.5

	var railgun = WeaponData.new()
	railgun.name = "Railgun"
	railgun.damage = 50
	railgun.cooldown = 2.0
	railgun.projectile_speed = 1200.0
	railgun.projectile_count = 1
	railgun.pierce = 10

	var laser = WeaponData.new()
	laser.name = "Laser"
	laser.damage = 12
	laser.cooldown = 0.05
	laser.projectile_speed = 0.0
	laser.projectile_count = 1
	laser.pierce = 99
	laser.area = 0.5

	return [autocannon, flamethrower, railgun, laser]
