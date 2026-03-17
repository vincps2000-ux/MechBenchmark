# workshop_screen.gd — Workshop screen for mech customization
extends Control

signal deploy_pressed(loadout: MechLoadout)

@onready var legs_container: HBoxContainer = %LegsContainer
@onready var torsos_container: HBoxContainer = %TorsosContainer
@onready var guns_container: HBoxContainer = %GunsContainer
@onready var deploy_button: Button = %DeployButton
@onready var stats_label: Label = %StatsLabel

var _loadout := MechLoadout.new()
var _all_legs: Array[LegData] = []
var _all_torsos: Array[TorsoData] = []
var _all_guns: Array[WeaponData] = []
var _leg_buttons: Array[Button] = []
var _torso_buttons: Array[Button] = []
var _gun_buttons: Array[Button] = []

var _selected_leg_index: int = -1
var _selected_torso_index: int = -1
var _selected_gun_index: int = -1

func _ready() -> void:
	_all_legs = MechLoadout.get_all_legs()
	_all_torsos = MechLoadout.get_all_torsos()
	_all_guns = MechLoadout.get_all_guns()
	_build_leg_buttons()
	_build_torso_buttons()
	_build_gun_buttons()
	deploy_button.pressed.connect(_on_deploy_pressed)
	deploy_button.disabled = true
	_update_stats_preview()

func _build_leg_buttons() -> void:
	for child in legs_container.get_children():
		child.queue_free()
	_leg_buttons.clear()
	for i in _all_legs.size():
		var leg = _all_legs[i]
		var btn = _create_option_button(leg.name, leg.tutorial_text)
		btn.pressed.connect(_on_leg_selected.bind(i))
		legs_container.add_child(btn)
		_leg_buttons.append(btn)

func _build_torso_buttons() -> void:
	for child in torsos_container.get_children():
		child.queue_free()
	_torso_buttons.clear()
	for i in _all_torsos.size():
		var torso = _all_torsos[i]
		var desc = torso.tutorial_text
		var btn = _create_option_button(torso.name, desc)
		var tex: Texture2D = load(torso.get_sprite_path())
		if tex:
			btn.icon = tex
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = false
			btn.add_theme_constant_override("icon_max_width", 56)
		btn.pressed.connect(_on_torso_selected.bind(i))
		torsos_container.add_child(btn)
		_torso_buttons.append(btn)

func _build_gun_buttons() -> void:
	for child in guns_container.get_children():
		child.queue_free()
	_gun_buttons.clear()
	for i in _all_guns.size():
		var gun = _all_guns[i]
		var desc = "DMG: %d  CD: %.1fs" % [gun.damage, gun.cooldown]
		var btn = _create_option_button(gun.name, desc)
		btn.pressed.connect(_on_gun_selected.bind(i))
		guns_container.add_child(btn)
		_gun_buttons.append(btn)

func _create_option_button(title: String, desc: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 100)
	btn.text = title + "\n\n" + desc
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Style: dark panel with accent border
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.1, 0.15, 0.9)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.4, 0.35, 0.3, 0.6)
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.corner_radius_bottom_left = 10

	var style_hover = style_normal.duplicate()
	style_hover.border_color = Color(0.85, 0.6, 0.2, 0.8)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.7, 1.0))
	btn.add_theme_font_size_override("font_size", 18)

	return btn

func _highlight_button(buttons: Array[Button], index: int) -> void:
	for i in buttons.size():
		var btn = buttons[i]
		var style: StyleBoxFlat
		if i == index:
			style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.15, 0.1, 0.95)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.95, 0.7, 0.2, 1.0)
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_right = 10
			style.corner_radius_bottom_left = 10
			style.shadow_color = Color(0.95, 0.7, 0.2, 0.3)
			style.shadow_size = 6
		else:
			style = StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.1, 0.15, 0.9)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.4, 0.35, 0.3, 0.6)
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_right = 10
			style.corner_radius_bottom_left = 10
		btn.add_theme_stylebox_override("normal", style)

func _on_leg_selected(index: int) -> void:
	_selected_leg_index = index
	_loadout.selected_legs = _all_legs[index]
	_highlight_button(_leg_buttons, index)
	_update_deploy_state()
	_update_stats_preview()

func _on_torso_selected(index: int) -> void:
	_selected_torso_index = index
	_loadout.selected_torso = _all_torsos[index]
	_highlight_button(_torso_buttons, index)
	_update_deploy_state()
	_update_stats_preview()

func _on_gun_selected(index: int) -> void:
	_selected_gun_index = index
	_loadout.selected_gun = _all_guns[index]
	_highlight_button(_gun_buttons, index)
	_update_deploy_state()
	_update_stats_preview()

func _update_deploy_state() -> void:
	deploy_button.disabled = not _loadout.is_valid()

func _update_stats_preview() -> void:
	if not stats_label:
		return
	if not _loadout.is_valid():
		stats_label.text = "Select legs, torso, and a weapon to see stats"
		return
	var preview_stats = PlayerStats.new()
	_loadout.apply_to_stats(preview_stats)
	stats_label.text = "HP: %d  |  Speed: %.0f  |  Torso: %s  |  Weapon: %s (DMG: %d)" % [
		preview_stats.max_health,
		preview_stats.speed,
		_loadout.selected_torso.name,
		_loadout.selected_gun.name,
		_loadout.selected_gun.damage
	]

func _on_deploy_pressed() -> void:
	deploy_button.disabled = true
	GameManager.current_loadout = _loadout
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(_go_to_game)

func _go_to_game() -> void:
	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/levels/gameplay.tscn")
