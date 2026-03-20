# level_1.gd — Level 1: first real mission (wasteland)
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var background_rect: ColorRect  = %BackgroundRect
@onready var health_bar:      ProgressBar = %HealthBar
@onready var timer_label:     Label       = %TimerLabel
@onready var hp_label:        Label       = %HpLabel

var _player: CharacterBody2D
var _player_camera: Camera2D
var _bg_material: ShaderMaterial
var _stats: PlayerStats

func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_player_camera = _player.get_node("Camera2D") as Camera2D

	_stats = GameManager.player_stats

	if background_rect and background_rect.material is ShaderMaterial:
		_bg_material = (background_rect.material as ShaderMaterial).duplicate()
		background_rect.material = _bg_material

	if _stats:
		health_bar.max_value = _stats.max_health
		health_bar.value     = _stats.health
		hp_label.text        = "%d / %d" % [_stats.health, _stats.max_health]

func _process(_delta: float) -> void:
	_scroll_background()
	_update_hud()

func _scroll_background() -> void:
	if not (_bg_material and _player_camera):
		return
	var vp_size  := get_viewport().get_visible_rect().size
	var zoom     := _player_camera.zoom.x
	var world_vp := vp_size / zoom
	var cam_off  := world_vp * 0.5
	_bg_material.set_shader_parameter("viewport_size",    world_vp)
	_bg_material.set_shader_parameter("camera_world_pos", _player.global_position - cam_off)

func _update_hud() -> void:
	if not _stats:
		return
	health_bar.value = _stats.health
	hp_label.text    = "%d / %d" % [_stats.health, _stats.max_health]
	timer_label.text = GameManager.get_game_time_formatted()
