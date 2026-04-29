# weapon_hud.gd — Bottom-right weapon status panel for gameplay.
# Shows each mounted weapon with a read-only ammo/status display.
class_name WeaponHUD
extends Control

const WEAPON_AMMO_PIP_SCRIPT := preload("res://src/ui/weapon_ammo_pip.gd")

var _player: Node = null
var _panel: PanelContainer = null
var _charge_bars: Dictionary = {}
var _weapon_name_labels: Dictionary = {}
var _ammo_labels: Dictionary = {}
var _ammo_markers: Dictionary = {}
var _ammo_pip_lists: Dictionary = {}  # index -> {"pips": Array, "unit_ammo": float}

func setup(player: Node) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.45, 0.3, 0.6)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "WEAPONS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if not _player:
		return

	var weapons: Array = _player.get_weapons()
	var loadout: MechLoadout = GameManager.current_loadout
	var all_gun_data: Array[WeaponData] = []
	if loadout:
		all_gun_data.append_array(loadout.selected_guns)
		all_gun_data.append_array(loadout.selected_light_guns)

	for i in weapons.size():
		var weapon_data: WeaponData = all_gun_data[i] if i < all_gun_data.size() else null
		var weapon_name := "Weapon %d" % (i + 1)
		if weapon_data:
			weapon_name = weapon_data.name
		var weapon_node: Node = weapons[i]
		var row := _make_weapon_row(weapon_name, i, weapon_node, weapon_data)
		vbox.add_child(row)

func _make_weapon_row(weapon_name: String, index: int, weapon_node: Node, weapon_data: WeaponData = null) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := _make_weapon_header(weapon_name, index)
	row.add_child(header)

	# Ammo pip strip for low-capacity weapons (Enter the Gungeon style).
	if weapon_node and weapon_node.has_method("get_ammo_capacity"):
		var cap: int = int(weapon_node.call("get_ammo_capacity"))
		if cap > 0:
			var strip_spec := _get_ammo_strip_spec(weapon_node, weapon_data, cap)
			if not strip_spec.is_empty():
				var strip := _make_ammo_pip_strip(
					int(strip_spec["pip_count"]),
					String(strip_spec["style"]),
					float(strip_spec["unit_ammo"]),
					weapon_data,
					index
				)
				row.add_child(strip)
				# Replace the "X / Y" text with icon strip for supported weapons.
				if _ammo_labels.has(index):
					(_ammo_labels[index] as Label).visible = false

	if _is_railgun_weapon(weapon_name, weapon_node):
		var bar := _make_charge_bar()
		row.add_child(bar)
		_charge_bars[index] = bar

	return row

func _get_ammo_strip_spec(weapon_node: Node, _weapon_data: WeaponData, capacity: int) -> Dictionary:
	var script = weapon_node.get_script()
	var script_path := ""
	if script is Script:
		script_path = String((script as Script).resource_path)

	if script_path.ends_with("autocannon.gd"):
		return {
			"style": "shell",
			"pip_count": capacity,
			"unit_ammo": 1.0,
		}
	if script_path.ends_with("machinegun.gd"):
		return {
			"style": "casing",
			"pip_count": ceili(float(capacity) / 10.0),
			"unit_ammo": 10.0,
		}
	if script_path.ends_with("rocket_pod.gd"):
		return {
			"style": "rocket",
			"pip_count": capacity,
			"unit_ammo": 1.0,
		}
	if script_path.ends_with("flamethrower.gd"):
		return {
			"style": "thrower",
			"pip_count": 20,
			"unit_ammo": float(capacity) / 20.0,
		}
	return {}

func _make_ammo_pip_strip(pip_count: int, style: String, unit_ammo: float, weapon_data: WeaponData, index: int) -> Control:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 3)

	var atype: WeaponData.AmmoType = WeaponData.AmmoType.HE
	var telement: WeaponData.ThrowerElement = WeaponData.ThrowerElement.FUEL
	if weapon_data:
		atype = weapon_data.ammo_type
		telement = weapon_data.thrower_element

	var pips: Array = []
	for _i in pip_count:
		var pip: Control = WEAPON_AMMO_PIP_SCRIPT.new()
		if pip.has_method("configure"):
			pip.configure(style, atype, telement)
		flow.add_child(pip)
		pips.append(pip)
	_ammo_pip_lists[index] = {
		"pips": pips,
		"unit_ammo": unit_ammo,
	}
	return flow

func _make_weapon_header(weapon_name: String, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.12, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.7, 0.3, 0.5)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var weapon_label := Label.new()
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.9, 1.0))
	weapon_label.text = weapon_name
	_weapon_name_labels[index] = weapon_label

	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(8, 8)
	marker.color = Color(0.95, 0.22, 0.18, 0.95)
	marker.visible = false
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ammo_markers[index] = marker
	row.add_child(marker)
	row.add_child(weapon_label)

	var ammo_label := Label.new()
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 13)
	ammo_label.add_theme_color_override("font_color", Color(0.76, 0.88, 0.6, 0.95))
	ammo_label.text = ""
	_ammo_labels[index] = ammo_label
	row.add_child(ammo_label)
	_refresh_weapon_status(index)

	return panel

func _is_railgun_weapon(weapon_name: String, weapon_node: Node) -> bool:
	if weapon_node and weapon_node.has_method("get_charge_ratio"):
		return true
	return weapon_name.to_lower().contains("railgun")

func _make_charge_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.step = 0.001
	bar.show_percentage = false

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.11, 0.14, 0.95)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.85, 1.0, 0.95)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

	return bar

func _get_weapon_node(index: int) -> Node:
	if not _player:
		return null
	var weapons: Array = _player.get_weapons()
	if index < 0 or index >= weapons.size():
		return null
	return weapons[index]

func _get_weapon_status_text(index: int) -> String:
	var weapon := _get_weapon_node(index)
	if weapon == null:
		return ""
	if not weapon.has_method("get_ammo_count") or not weapon.has_method("get_ammo_capacity"):
		return ""
	return "%d / %d" % [weapon.call("get_ammo_count"), weapon.call("get_ammo_capacity")]

func _refresh_weapon_status(index: int) -> void:
	var weapon := _get_weapon_node(index)
	# Update pip strip if this weapon uses one; otherwise update the text label.
	if _ammo_pip_lists.has(index):
		var strip_data: Dictionary = _ammo_pip_lists[index]
		var pips: Array = strip_data.get("pips", [])
		var unit_ammo: float = maxf(0.001, float(strip_data.get("unit_ammo", 1.0)))
		var current := 0
		if weapon and weapon.has_method("get_ammo_count"):
			current = int(weapon.call("get_ammo_count"))
		for i in pips.size():
			var pip := pips[i] as Control
			if pip and pip.has_method("set_fill_ratio"):
				var start_ammo := float(i) * unit_ammo
				var fill := clampf((float(current) - start_ammo) / unit_ammo, 0.0, 1.0)
				pip.set_fill_ratio(fill)
	elif _ammo_labels.has(index):
		var ammo_label := _ammo_labels[index] as Label
		if ammo_label:
			ammo_label.text = _get_weapon_status_text(index)
	if _ammo_markers.has(index):
		var marker := _ammo_markers[index] as ColorRect
		if marker:
			marker.visible = weapon != null and weapon.has_method("is_out_of_ammo") and bool(weapon.call("is_out_of_ammo"))
	if _weapon_name_labels.has(index):
		var weapon_label := _weapon_name_labels[index] as Label
		if weapon_label:
			var out_of_ammo := weapon != null and weapon.has_method("is_out_of_ammo") and bool(weapon.call("is_out_of_ammo"))
			weapon_label.modulate = Color(1.0, 1.0, 1.0, 0.6) if out_of_ammo else Color(1.0, 1.0, 1.0, 1.0)

func _process(_delta: float) -> void:
	if _panel and _panel.size.x > 0:
		var parent_size := size if size.x > 0 else get_viewport().get_visible_rect().size
		_panel.position = Vector2(
			parent_size.x - _panel.size.x - 16,
			parent_size.y - _panel.size.y - 16
		)
	for index in _ammo_labels.keys():
		_refresh_weapon_status(index)
	_update_charge_bars()

func _update_charge_bars() -> void:
	if _charge_bars.is_empty() or not _player:
		return
	var weapons: Array = _player.get_weapons()
	for index in _charge_bars.keys():
		var bar := _charge_bars[index] as ProgressBar
		if not bar:
			continue
		if index < 0 or index >= weapons.size():
			bar.value = 0.0
			continue
		var weapon: Node = weapons[index]
		if weapon and weapon.has_method("get_charge_ratio"):
			bar.value = clampf(float(weapon.call("get_charge_ratio")), 0.0, 1.0)
		else:
			bar.value = 0.0
