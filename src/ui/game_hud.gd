# game_hud.gd — Universal HUD component for structure, armor, and timer display.
# Reusable across all levels. Levels add their own custom labels as siblings.
class_name GameHUD
extends VBoxContainer

@onready var _structure_label: Label = $StructureLabel
@onready var _structure_bar: ProgressBar = $StructureBar
@onready var _armor_label: Label = $ArmorLabel
@onready var _timer_label: Label = $TimerLabel

## Update all stat displays from the given player stats.
func update_stats(stats: PlayerStats) -> void:
	if not stats:
		return
	_structure_label.text = "STRUCTURE %d / %d" % [stats.health, stats.max_health]
	_structure_bar.max_value = stats.max_health
	_structure_bar.value = stats.health
	_armor_label.text = "ARMOR %d" % stats.armor
	_timer_label.text = GameManager.get_game_time_formatted()
