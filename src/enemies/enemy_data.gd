# enemy_data.gd — Data class for enemy configuration
class_name EnemyData
extends Resource

@export var name: String = "Unnamed"
@export var max_health: int = 20
@export var health: int = 20
@export var armor: int = 0
@export var damage: int = 5
@export var speed: float = 80.0
@export var xp_reward: int = 5

func take_damage(amount: int, _penetration: int = 10) -> void:
	health = max(0, health - amount)

func is_dead() -> bool:
	return health <= 0

func reset() -> void:
	health = max_health
