# start_screen.gd — Whimsical industrial start screen
extends Control

@onready var start_button: Button = %StartButton
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

var _title_bob_time: float = 0.0
var _button_pulse_time: float = 0.0
var _gear_particles_spawned := false

var _gears: Array[Sprite2D] = []
var _gems: Array[Sprite2D] = []
var _time: float = 0.0

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	start_button.mouse_entered.connect(_on_button_hover)
	start_button.mouse_exited.connect(_on_button_unhover)
	
	if subtitle_label:
		subtitle_label.visible = false
		
	var gear_tex = load("res://assets/sprites/gear.svg")
	var gem_tex = load("res://assets/sprites/xp_gem.svg")
	
	var gear_positions = [Vector2(150, 150), Vector2(1130, 200), Vector2(250, 550), Vector2(1000, 580)]
	for i in range(gear_positions.size()):
		var gear = Sprite2D.new()
		gear.texture = gear_tex
		gear.position = gear_positions[i]
		gear.scale = Vector2(3.0, 3.0) if i%2==0 else Vector2(2.0, 2.0)
		add_child(gear)
		move_child(gear, 1) # Behind UI
		_gears.append(gear)
		
	var gem_positions = [Vector2(200, 350), Vector2(1080, 350), Vector2(350, 250), Vector2(930, 250)]
	for i in range(gem_positions.size()):
		var gem = Sprite2D.new()
		gem.texture = gem_tex
		gem.position = gem_positions[i]
		gem.scale = Vector2(1.5, 1.5)
		add_child(gem)
		move_child(gem, 1) # Behind UI
		_gems.append(gem)

	# Fade in the whole screen
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_time += delta
	# Gentle bobbing on the title
	_title_bob_time += delta
	if title_label:
		title_label.position.y = -8.0 * sin(_title_bob_time * 1.2)

	for i in range(_gears.size()):
		var gear = _gears[i]
		gear.rotation += delta * (1.5 if i % 2 == 0 else -1.0)
		
	for i in range(_gems.size()):
		var gem = _gems[i]
		gem.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var scale_pulse = 1.0 + 0.3 * sin(_time * 10.0 + i)
		gem.scale = Vector2(scale_pulse * 1.5, scale_pulse * 1.5)
		gem.position.y += sin(_time * 2.0 + i) * 10.0 * delta

	# Button glow pulse
	_button_pulse_time += delta
	if start_button:
		var pulse = 0.85 + 0.15 * sin(_button_pulse_time * 2.5)
		start_button.modulate = Color(pulse, pulse * 0.95, pulse * 0.8, 1.0)

func _on_start_pressed() -> void:
	# Dramatic fade-out, then start game
	start_button.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(_go_to_game)

func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/workshop_screen.tscn")

func _on_button_hover() -> void:
	var tween := create_tween()
	tween.tween_property(start_button, "scale", Vector2(1.08, 1.08), 0.15).set_ease(Tween.EASE_OUT)

func _on_button_unhover() -> void:
	var tween := create_tween()
	tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
