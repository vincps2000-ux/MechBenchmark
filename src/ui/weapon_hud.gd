# weapon_hud.gd — Bottom-right weapon toggle panel for gameplay.
# Shows each mounted weapon with a clickable button to toggle active/inactive.
class_name WeaponHUD
extends Control

var _player: Node = null
var _buttons: Array[Button] = []
var _panel: PanelContainer = null

func setup(player: Node) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.45, 0.3, 0.6)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
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

	for i in weapons.size():
		var gun_data: WeaponData = null
		if loadout and i < loadout.selected_guns.size():
			gun_data = loadout.selected_guns[i]
		var weapon_name := gun_data.name if gun_data else "Weapon %d" % (i + 1)
		var btn := _make_weapon_button(weapon_name, i)
		vbox.add_child(btn)
		_buttons.append(btn)

func _make_weapon_button(weapon_name: String, index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 32)
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

func _on_toggle(index: int) -> void:
	if not _player:
		return
	var is_active: bool = _player.is_weapon_active(index)
	_player.set_weapon_active(index, !is_active)
	_update_button(index)

func _update_button(index: int) -> void:
	if index >= _buttons.size() or not _player:
		return
	var active: bool = _player.is_weapon_active(index)
	var loadout: MechLoadout = GameManager.current_loadout
	var weapon_name := "Weapon"
	if loadout and index < loadout.selected_guns.size() and loadout.selected_guns[index]:
		weapon_name = loadout.selected_guns[index].name

	if active:
		_buttons[index].text = weapon_name + "  [ON]"
		_buttons[index].add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0))
		_buttons[index].modulate.a = 1.0
	else:
		_buttons[index].text = weapon_name + "  [OFF]"
		_buttons[index].add_theme_color_override("font_color", Color(0.6, 0.4, 0.3, 0.8))
		_buttons[index].modulate.a = 0.6
