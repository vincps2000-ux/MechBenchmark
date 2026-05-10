# player_stats.gd — Pure data class for player stats (easy to unit test)
class_name PlayerStats
extends Resource

@export var max_health: int = 30
@export var health: int = 30
@export var armor: int = 0
@export var speed: float = 200.0
@export var experience: int = 0
@export var level: int = 1
@export var pickup_range: float = 50.0
@export var recharge_rate_bonus: float = 0.0  # Energy regen bonus per second

# XP required to reach the next level
func xp_for_next_level() -> int:
	return level * 10 + int(pow(level, 1.5) * 5)

# Returns true if leveled up
func add_experience(amount: int) -> bool:
	experience += amount
	var needed = xp_for_next_level()
	if experience >= needed:
		experience -= needed
		level += 1
		return true
	return false

func take_damage(amount: int = 1) -> void:
	health = max(0, health - amount)

func heal(amount: int = 1) -> void:
	health = min(max_health, health + amount)

func is_dead() -> bool:
	return health <= 0
