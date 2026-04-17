# game_hud.gd — Universal HUD component for integrity, armor, and timer display.
# Reusable across all levels. Levels add their own custom labels as siblings.
class_name GameHUD
extends VBoxContainer

@onready var _integrity_label: Label = $IntegrityRow/IntegrityLabel
@onready var _armor_label: Label = $ArmorLabel
@onready var _timer_label: Label = $TimerLabel

## Update all stat displays from the given player stats.
func update_stats(stats: PlayerStats) -> void:
	if not stats:
		return
	var filled := "◆".repeat(stats.integrity)
	var empty := "◇".repeat(stats.max_integrity - stats.integrity)
	_integrity_label.text = filled + empty
	_armor_label.text = "▰".repeat(stats.armor)
	_timer_label.text = GameManager.get_game_time_formatted()
