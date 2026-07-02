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

var _continue_button: Button = null
var _download_button: Button = null
var _file_dialog: FileDialog = null
var _file_dialog_mode_import := false

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	start_button.mouse_entered.connect(_on_button_hover)
	start_button.mouse_exited.connect(_on_button_unhover)

	_build_mech_buttons()
	
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


# ── Saved-mech buttons (continue / download / upload) ────────────────────────

func _build_mech_buttons() -> void:
	var vbox := start_button.get_node("../..") as VBoxContainer
	var anchor := start_button.get_node("..") as Control  # ButtonCenter
	if vbox == null or anchor == null:
		return

	var row := VBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	vbox.move_child(row, anchor.get_index() + 1)

	var has_save := MechPersistence.has_save()

	_continue_button = _make_secondary_button("CONTINUE WITH SAVED MECH")
	_continue_button.visible = has_save
	_continue_button.pressed.connect(_on_continue_pressed)
	row.add_child(_continue_button)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	_download_button = _make_secondary_button("DOWNLOAD MECH")
	_download_button.visible = has_save
	_download_button.pressed.connect(_on_download_pressed)
	hbox.add_child(_download_button)

	var upload_button := _make_secondary_button("UPLOAD MECH")
	upload_button.pressed.connect(_on_upload_pressed)
	hbox.add_child(upload_button)


func _make_secondary_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.92, 0.85, 0.72, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.92, 1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.13, 0.18, 0.9)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.55, 0.45, 0.2, 0.8)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.19, 0.12, 0.95)
	hover.border_color = Color(0.95, 0.7, 0.2, 1)
	btn.add_theme_stylebox_override("hover", hover)
	return btn


func _on_continue_pressed() -> void:
	if not MechPersistence.load_into_game_manager():
		return
	start_button.disabled = true
	if _continue_button:
		_continue_button.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/ui/level_select_screen.tscn")
	)


func _on_download_pressed() -> void:
	_open_file_dialog(false)


func _on_upload_pressed() -> void:
	_open_file_dialog(true)


func _open_file_dialog(import_mode: bool) -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = true
		_file_dialog.add_filter("*.json", "Mech Blueprint")
		_file_dialog.file_selected.connect(_on_file_selected)
		add_child(_file_dialog)

	_file_dialog_mode_import = import_mode
	if import_mode:
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.title = "Upload Mech"
	else:
		_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_file_dialog.title = "Download Mech"
		_file_dialog.current_file = "my_mech.json"
	_file_dialog.popup_centered(Vector2i(720, 480))


func _on_file_selected(path: String) -> void:
	if _file_dialog_mode_import:
		var data := MechPersistence.import_from(path)
		if data != null:
			if _continue_button:
				_continue_button.visible = true
			if _download_button:
				_download_button.visible = true
	else:
		MechPersistence.export_to(path)

