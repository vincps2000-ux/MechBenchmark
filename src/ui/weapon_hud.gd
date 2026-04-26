# weapon_hud.gd — Bottom-right weapon toggle panel for gameplay.
# Shows each mounted weapon with a clickable button to toggle active/inactive.
class_name WeaponHUD
extends Control

var _player: Node = null
var _buttons: Array[Button] = []
var _panel: PanelContainer = null
var _charge_bars: Dictionary = {}

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
		var weapon_name := "Weapon %d" % (i + 1)
		if i < all_gun_data.size() and all_gun_data[i]:
			weapon_name = all_gun_data[i].name
		var weapon_node: Node = weapons[i]
		var row := _make_weapon_row(weapon_name, i, weapon_node)
		vbox.add_child(row)

func _make_weapon_row(weapon_name: String, index: int, weapon_node: Node) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn := _make_weapon_button(weapon_name, index)
	row.add_child(btn)
	_buttons.append(btn)

	if _is_railgun_weapon(weapon_name, weapon_node):
		var bar := _make_charge_bar()
		row.add_child(bar)
		_charge_bars[index] = bar

	return row

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

func _make_weapon_button(weapon_name: String, index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = weapon_name + "  [ON]"
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.15, 0.12, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.3, 0.7, 0.3, 0.5)
	btn_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", btn_style)
	var hover_style: StyleBoxFlat = btn_style.duplicate()
	hover_style.bg_color = Color(0.18, 0.2, 0.17, 0.95)
	hover_style.border_color = Color(0.5, 0.9, 0.4, 0.7)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.pressed.connect(_on_toggle.bind(index))
	return btn

func _process(_delta: float) -> void:
	if _panel and _panel.size.x > 0:
		var parent_size := size if size.x > 0 else get_viewport().get_visible_rect().size
		_panel.position = Vector2(
			parent_size.x - _panel.size.x - 16,
			parent_size.y - _panel.size.y - 16
		)
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

func _on_toggle(index: int) -> void:
	if not _player:
		return
	var is_active: bool = _player.is_weapon_active(index)
	_player.set_weapon_active(index, !is_active)
	_update_button(index)
	_update_charge_bars()

func _update_button(index: int) -> void:
	if index >= _buttons.size() or not _player:
		return
	var active: bool = _player.is_weapon_active(index)
	var loadout: MechLoadout = GameManager.current_loadout
	var weapon_name := "Weapon"
	var all_gun_data: Array[WeaponData] = []
	if loadout:
		all_gun_data.append_array(loadout.selected_guns)
		all_gun_data.append_array(loadout.selected_light_guns)
	if index < all_gun_data.size() and all_gun_data[index]:
		weapon_name = all_gun_data[index].name

	if active:
		_buttons[index].text = weapon_name + "  [ON]"
		_buttons[index].add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0))
		_buttons[index].modulate.a = 1.0
	else:
		_buttons[index].text = weapon_name + "  [OFF]"
		_buttons[index].add_theme_color_override("font_color", Color(0.6, 0.4, 0.3, 0.8))
		_buttons[index].modulate.a = 0.6
