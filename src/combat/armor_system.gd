# armor_system.gd — Static utility for armor vs penetration calculations.
#
# Penetration chance formula:
#   pen > armor  → 100% penetrate
#   pen == armor → 50% penetrate
#   Each armor level above penetration halves the chance further.
#   chance = pow(0.5, max(0, armor - pen + 1))
class_name ArmorSystem

## Returns the probability (0.0–1.0) that an attack with the given
## penetration value will pierce through the given armor value.
static func penetration_chance(penetration: int, armor: int) -> float:
	if penetration > armor:
		return 1.0
	return pow(0.5, armor - penetration + 1)

## Rolls whether an attack penetrates armour.  Returns true = damage dealt.
static func roll_penetration(penetration: int, armor: int) -> bool:
	var chance := penetration_chance(penetration, armor)
	if chance >= 1.0:
		return true
	return randf() < chance
