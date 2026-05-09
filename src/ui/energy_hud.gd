# energy_hud.gd — Bottom-left energy readout for energy-based weapons.
class_name EnergyHUD
extends Control

var _player: Node = null
var _panel: PanelContainer = null
var _energy_bar: ProgressBar = null
var _energy_label: Label = null
var _consumable_icons_row: HBoxContainer = null
var _consumable_icons_box: HBoxContainer = null
var _last_consumable_signature: String = ""

func setup(player: Node) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.34, 0.38, 0.42, 0.95)
	style.set_corner_radius_all(2)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_TOP, 6)
	style.set_content_margin(SIDE_RIGHT, 8)
	style.set_content_margin(SIDE_BOTTOM, 6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(168, 0)
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var tag := ColorRect.new()
	tag.custom_minimum_size = Vector2(10, 10)
	tag.color = Color(0.18, 0.62, 1.0, 0.95)
	header.add_child(tag)

	var title := Label.new()
	title.text = "POWER BUS"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.82, 0.84, 0.8, 0.95))
	header.add_child(title)

	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(168, 10)
	_energy_bar.min_value = 0.0
	_energy_bar.max_value = 100.0
	_energy_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.04, 0.98)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.2, 0.22, 0.24, 1.0)
	bg.set_corner_radius_all(1)
	_energy_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.18, 0.62, 1.0, 0.95)
	fill.set_corner_radius_all(1)
	_energy_bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(_energy_bar)

	_energy_label = Label.new()
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_energy_label.add_theme_font_size_override("font_size", 10)
	_energy_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.86, 0.92))
	vbox.add_child(_energy_label)

	_consumable_icons_row = HBoxContainer.new()
	_consumable_icons_row.add_theme_constant_override("separation", 3)
	_consumable_icons_row.visible = false
	vbox.add_child(_consumable_icons_row)

	_consumable_icons_box = HBoxContainer.new()
	_consumable_icons_box.add_theme_constant_override("separation", 3)
	_consumable_icons_row.add_child(_consumable_icons_box)

	_refresh_energy()

func _process(_delta: float) -> void:
	if _panel and _panel.size.x > 0:
		var parent_size := size if size.x > 0 else get_viewport().get_visible_rect().size
		_panel.position = Vector2(14.0, parent_size.y - _panel.size.y - 14.0)
	if _player != null and _player.has_method("is_drone_view_active") and bool(_player.call("is_drone_view_active")):
		_panel.visible = false
		return
	if _panel:
		_panel.visible = true
	_refresh_energy()

func _refresh_energy() -> void:
	if _energy_bar == null or _energy_label == null:
		return
	var current := 0.0
	var maximum := 100.0
	if _player != null and _player.has_method("get_energy") and _player.has_method("get_max_energy"):
		current = float(_player.call("get_energy"))
		maximum = maxf(1.0, float(_player.call("get_max_energy")))
	_energy_bar.max_value = maximum
	_energy_bar.value = current
	_energy_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
	_refresh_consumable_icons()


func _refresh_consumable_icons() -> void:
	if _consumable_icons_box == null:
		return

	var icon_keys: Array[String] = []
	if _player != null and _player.has_method("get_consumable_utility_icon_keys"):
		var raw_keys: Variant = _player.call("get_consumable_utility_icon_keys")
		if raw_keys is Array:
			for key in raw_keys:
				icon_keys.append(str(key))
	elif _player != null and _player.has_method("get_backup_battery_count"):
		for _i in int(_player.call("get_backup_battery_count")):
			icon_keys.append("backup_battery")

	var signature := "|".join(icon_keys)
	if signature == _last_consumable_signature:
		return

	for child in _consumable_icons_box.get_children():
		child.queue_free()

	for icon_key in icon_keys:
		var icon := _make_consumable_icon(icon_key)
		_consumable_icons_box.add_child(icon)

	_consumable_icons_row.visible = not icon_keys.is_empty()
	_last_consumable_signature = signature


func _make_consumable_icon(icon_key: String) -> Control:
	match icon_key:
		"backup_battery":
			return _make_backup_battery_icon()
		"drone":
			return _make_drone_icon()
		"booster":
			return _make_booster_icon()
		_:
			return _make_fallback_consumable_icon()


func _make_drone_icon() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(14, 8)

	var wing_left := ColorRect.new()
	wing_left.color = Color(0.55, 0.75, 0.92, 0.95)
	wing_left.position = Vector2(0, 3)
	wing_left.size = Vector2(4, 2)
	root.add_child(wing_left)

	var body := ColorRect.new()
	body.color = Color(0.72, 0.92, 1.0, 0.95)
	body.position = Vector2(4, 2)
	body.size = Vector2(6, 4)
	root.add_child(body)

	var wing_right := ColorRect.new()
	wing_right.color = Color(0.55, 0.75, 0.92, 0.95)
	wing_right.position = Vector2(10, 3)
	wing_right.size = Vector2(4, 2)
	root.add_child(wing_right)

	var nose := ColorRect.new()
	nose.color = Color(0.2, 0.95, 0.82, 0.95)
	nose.position = Vector2(10, 1)
	nose.size = Vector2(2, 1)
	root.add_child(nose)

	return root


func _make_backup_battery_icon() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(14, 8)

	var body := ColorRect.new()
	body.color = Color(0.95, 0.86, 0.42, 0.95)
	body.position = Vector2(0, 0)
	body.size = Vector2(11, 8)
	root.add_child(body)

	var body_outline := StyleBoxFlat.new()
	body_outline.bg_color = Color(0.95, 0.86, 0.42, 0.95)
	body_outline.set_border_width_all(1)
	body_outline.border_color = Color(0.35, 0.3, 0.12, 1.0)
	body.add_theme_stylebox_override("panel", body_outline)

	var tip := ColorRect.new()
	tip.color = Color(0.85, 0.78, 0.4, 0.95)
	tip.position = Vector2(11, 2)
	tip.size = Vector2(3, 4)
	root.add_child(tip)

	var tip_outline := StyleBoxFlat.new()
	tip_outline.bg_color = Color(0.85, 0.78, 0.4, 0.95)
	tip_outline.set_border_width_all(1)
	tip_outline.border_color = Color(0.35, 0.3, 0.12, 1.0)
	tip.add_theme_stylebox_override("panel", tip_outline)

	return root


func _make_fallback_consumable_icon() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(14, 8)

	var left := ColorRect.new()
	left.color = Color(0.62, 0.72, 0.85, 0.95)
	left.position = Vector2(0, 2)
	left.size = Vector2(4, 4)
	root.add_child(left)

	var center := ColorRect.new()
	center.color = Color(0.65, 0.75, 0.9, 0.95)
	center.position = Vector2(4, 0)
	center.size = Vector2(6, 8)
	root.add_child(center)

	var right := ColorRect.new()
	right.color = Color(0.62, 0.72, 0.85, 0.95)
	right.position = Vector2(10, 2)
	right.size = Vector2(4, 4)
	root.add_child(right)

	var border := ColorRect.new()
	border.color = Color(0.3, 0.4, 0.52, 1.0)
	border.position = Vector2(0, 0)
	border.size = Vector2(14, 1)
	root.add_child(border)

	return root


func _make_booster_icon() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(14, 8)

	var flame_left := ColorRect.new()
	flame_left.color = Color(1.0, 0.55, 0.2, 0.95)
	flame_left.position = Vector2(0, 3)
	flame_left.size = Vector2(3, 2)
	root.add_child(flame_left)

	var flame_core := ColorRect.new()
	flame_core.color = Color(1.0, 0.82, 0.35, 0.95)
	flame_core.position = Vector2(3, 2)
	flame_core.size = Vector2(2, 4)
	root.add_child(flame_core)

	var body := ColorRect.new()
	body.color = Color(0.72, 0.86, 0.98, 0.95)
	body.position = Vector2(5, 1)
	body.size = Vector2(6, 6)
	root.add_child(body)

	var nose := ColorRect.new()
	nose.color = Color(0.55, 0.74, 0.95, 0.95)
	nose.position = Vector2(11, 2)
	nose.size = Vector2(3, 4)
	root.add_child(nose)

	var fin_top := ColorRect.new()
	fin_top.color = Color(0.35, 0.52, 0.74, 0.95)
	fin_top.position = Vector2(7, 0)
	fin_top.size = Vector2(2, 1)
	root.add_child(fin_top)

	var fin_bottom := ColorRect.new()
	fin_bottom.color = Color(0.35, 0.52, 0.74, 0.95)
	fin_bottom.position = Vector2(7, 7)
	fin_bottom.size = Vector2(2, 1)
	root.add_child(fin_bottom)

	return root