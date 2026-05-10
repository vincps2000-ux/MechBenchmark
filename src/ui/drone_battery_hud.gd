class_name DroneBatteryHUD
extends Control

var _player: Node = null
var _panel: PanelContainer = null
var _battery_bar: ProgressBar = null
var _battery_label: Label = null
var _firecontrol_toggle: CheckButton = null
var _explode_button: Button = null
var _exit_button: Button = null

func setup(player: Node) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.08, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.32, 0.78, 0.78, 0.92)
	style.set_corner_radius_all(4)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_TOP, 6)
	style.set_content_margin(SIDE_RIGHT, 8)
	style.set_content_margin(SIDE_BOTTOM, 6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(190, 0)
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "RECON DRONE"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.76, 0.95, 0.94, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_battery_bar = ProgressBar.new()
	_battery_bar.custom_minimum_size = Vector2(190, 10)
	_battery_bar.min_value = 0.0
	_battery_bar.max_value = 100.0
	_battery_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.04, 0.98)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.14, 0.2, 0.2, 1.0)
	bg.set_corner_radius_all(2)
	_battery_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.22, 0.9, 0.68, 0.95)
	fill.set_corner_radius_all(2)
	_battery_bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(_battery_bar)

	_battery_label = Label.new()
	_battery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_battery_label.add_theme_font_size_override("font_size", 10)
	_battery_label.add_theme_color_override("font_color", Color(0.7, 0.86, 0.82, 0.95))
	vbox.add_child(_battery_label)

	_firecontrol_toggle = CheckButton.new()
	_firecontrol_toggle.text = "Firecontrol: ACTIVE"
	_firecontrol_toggle.button_pressed = false
	_firecontrol_toggle.add_theme_font_size_override("font_size", 10)
	_firecontrol_toggle.toggled.connect(_on_firecontrol_toggled)
	vbox.add_child(_firecontrol_toggle)

	_explode_button = Button.new()
	_explode_button.text = "EXPLODE"
	_explode_button.custom_minimum_size = Vector2(0, 24)
	_explode_button.add_theme_font_size_override("font_size", 10)
	_explode_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 0.95))
	_explode_button.pressed.connect(_on_explode_pressed)
	_explode_button.visible = false
	vbox.add_child(_explode_button)

	_exit_button = Button.new()
	_exit_button.text = "EXIT DRONE"
	_exit_button.custom_minimum_size = Vector2(0, 24)
	_exit_button.add_theme_font_size_override("font_size", 10)
	_exit_button.pressed.connect(_on_exit_pressed)
	vbox.add_child(_exit_button)

	_panel.visible = false

func _process(_delta: float) -> void:
	if _panel and _panel.size.x > 0:
		var parent_size := size if size.x > 0 else get_viewport().get_visible_rect().size
		_panel.position = Vector2(
			parent_size.x - _panel.size.x - 16.0,
			parent_size.y - _panel.size.y - 16.0
		)
	_refresh()

func _refresh() -> void:
	if _panel == null:
		return

	var active := false
	if _player != null and _player.has_method("is_drone_view_active"):
		active = bool(_player.call("is_drone_view_active"))
	_panel.visible = active
	if not active:
		return

	var current := 0.0
	var maximum := 100.0
	if _player != null and _player.has_method("get_drone_battery"):
		current = float(_player.call("get_drone_battery"))
	if _player != null and _player.has_method("get_drone_max_battery"):
		maximum = maxf(1.0, float(_player.call("get_drone_max_battery")))
	if _firecontrol_toggle != null and _player != null and _player.has_method("is_drone_firecontrol_active"):
		var firecontrol_active := bool(_player.call("is_drone_firecontrol_active"))
		if _firecontrol_toggle.button_pressed != firecontrol_active:
			_firecontrol_toggle.set_pressed_no_signal(firecontrol_active)
	if _firecontrol_toggle != null and _player != null and _player.has_method("can_drone_firecontrol"):
		_firecontrol_toggle.visible = bool(_player.call("can_drone_firecontrol"))
	
	# Show/hide explode button based on whether drone can explode
	if _explode_button != null and _player != null and _player.has_method("can_drone_explode"):
		_explode_button.visible = bool(_player.call("can_drone_explode"))
	
	_battery_bar.max_value = maximum
	_battery_bar.value = current
	_battery_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_firecontrol_toggled(active: bool) -> void:
	if _player != null and _player.has_method("set_drone_firecontrol_active"):
		_player.call("set_drone_firecontrol_active", active)


func _on_explode_pressed() -> void:
	if _player != null and _player.has_method("trigger_drone_explode"):
		_player.call("trigger_drone_explode")


func _on_exit_pressed() -> void:
	if _player != null and _player.has_method("exit_active_drone"):
		_player.call("exit_active_drone")
