# game_manager.gd — Autoload singleton for game state
extends Node

signal wave_started(wave_number: int)
signal game_over
signal level_up(new_level: int)

var player_stats: PlayerStats
var current_loadout: MechLoadout
var current_wave: int = 0
var enemies_alive: int = 0
var game_time: float = 0.0
var is_running: bool = false

func _ready() -> void:
	player_stats = PlayerStats.new()

func start_game() -> void:
	player_stats = PlayerStats.new()
	if current_loadout:
		current_loadout.apply_to_stats(player_stats)
	current_wave = 0
	enemies_alive = 0
	game_time = 0.0
	is_running = true

func _process(delta: float) -> void:
	if is_running:
		game_time += delta

func end_game() -> void:
	is_running = false
	game_over.emit()

func on_enemy_killed(xp: int) -> void:
	enemies_alive -= 1
	var leveled_up = player_stats.add_experience(xp)
	if leveled_up:
		level_up.emit(player_stats.level)

func get_game_time_formatted() -> String:
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	return "%02d:%02d" % [minutes, seconds]
