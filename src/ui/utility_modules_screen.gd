# utility_modules_screen.gd — Configure utility modules after Workshop.
extends Control

const MODULE_NAMES := [
	"Backup Battery",
	"Drone",
	"Booster",
]

const _UTILITY_MODULE_DATA_SCRIPT := preload("res://src/player/utility_module_data.gd")
const _DRONE_MODIFICATION_DATA_SCRIPT := preload("res://src/player/drone_modification_data.gd")

var _utility_module_data = _UTILITY_MODULE_DATA_SCRIPT.new()

@onready var _parts_label: Label = %PartsLabel
@onready var _parts_box: VBoxContainer = %PartsBox
@onready var _selection_info: Label = %SelectionInfo
@onready var _slots_title: Label = %SlotsTitle
@onready var _slots_box: VBoxContainer = %SlotsBox
@onready var _slots_summary: Label = %SlotsSummary
@onready var _back_button: Button = %BackButton
@onready var _next_button: Button = %NextButton

var _loadout: MechLoadout = null
var _slot_count: int = 0
var _slot_boxes: Array[ModuleSlotBox] = []
var _slot_modify_buttons: Array[Button] = []
var _booster_modal_overlay: ColorRect = null
var _booster_direction_dial: BoosterDirectionDial = null
var _booster_direction_label: Label = null
var _booster_selected_slot: int = -1
var _drone_modal_overlay: ColorRect = null
var _drone_selected_slot: int = -1
var _drone_selected_component_slot: int = 0
var _drone_component_slot_buttons: Array[Button] = []
var _drone_component_summary: Label = null
var _drone_component_hint: Label = null


class BoosterDirectionDial:
	extends Control

	signal angle_changed(angle: float)

	var angle: float = 0.0:
		set(value):
			angle = wrapf(value, -PI, PI)
			queue_redraw()

	var _dragging: bool = false

	func _ready() -> void:
		custom_minimum_size = Vector2(220, 220)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_update_angle_from_position(event.position)
				accept_event()
		elif event is InputEventMouseMotion and _dragging:
			_update_angle_from_position(event.position)
			accept_event()

	func _update_angle_from_position(position: Vector2) -> void:
		var center := size * 0.5
		var offset := position - center
		if offset.length_squared() < 64.0:
			return
		angle = wrapf(offset.angle() + PI / 2.0, -PI, PI)
		angle_changed.emit(angle)

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.42
		draw_circle(center, radius, Color(0.11, 0.11, 0.14, 0.95))
		draw_circle(center, radius * 0.72, Color(0.06, 0.06, 0.09, 0.95))
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.95, 0.75, 0.2, 0.9), 2.0)
		draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, -radius - 14.0), Color(0.85, 0.95, 1.0, 0.9), 3.0)
		draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), Color(0.45, 0.45, 0.55, 0.35), 1.0)
		draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), Color(0.45, 0.45, 0.55, 0.35), 1.0)

		var marker_direction: Vector2 = Vector2.RIGHT.rotated(angle - PI / 2.0)
		var marker_end: Vector2 = center + marker_direction * radius
		draw_line(center, marker_end, Color(0.95, 0.55, 0.18, 1.0), 6.0)
		draw_circle(marker_end, 10.0, Color(1.0, 0.86, 0.42, 1.0))


class ModuleCard:
	extends PanelContainer

	var module_name: String = ""

	func setup(name: String) -> void:
		module_name = name
		custom_minimum_size = Vector2(0, 56)
		mouse_filter = Control.MOUSE_FILTER_STOP

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.1, 0.15, 0.85)
		style.set_border_width_all(1)
		style.border_color = Color(0.35, 0.3, 0.25, 0.5)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8)
		add_theme_stylebox_override("panel", style)

		var name_label := Label.new()
		name_label.text = module_name
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(name_label)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := PanelContainer.new()
		var lbl := Label.new()
		lbl.text = "  " + module_name + "  "
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		preview.add_child(lbl)

		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.15, 0.12, 0.1, 0.95)
		ps.set_border_width_all(2)
		ps.border_color = Color(0.95, 0.7, 0.2, 0.9)
		ps.set_corner_radius_all(6)
		ps.set_content_margin_all(6)
		preview.add_theme_stylebox_override("panel", ps)

		set_drag_preview(preview)
		return {"type": "utility_module", "name": module_name}


class ModuleSlotBox:
	extends Panel

	signal module_dropped(slot_index: int, module_name: String)

	var slot_index: int = 0
	var module_name: String = ""
	var _label: Label = null
	var _is_hover: bool = false

	func setup(index: int, selected_name: String) -> void:
		slot_index = index
		module_name = selected_name
		custom_minimum_size = Vector2(280, 44)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP

		_label = Label.new()
		_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 14)
		add_child(_label)

		_refresh()

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var ok: bool = false
		if data is Dictionary:
			var drop_data: Dictionary = data
			ok = drop_data.get("type", "") == "utility_module"
		if _is_hover != ok:
			_is_hover = ok
			_apply_style()
		return ok

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		module_name = str(data.get("name", ""))
		_is_hover = false
		_refresh()
		module_dropped.emit(slot_index, module_name)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and _is_hover:
			_is_hover = false
			_apply_style()

	func set_module_name(selected_name: String) -> void:
		module_name = selected_name
		_refresh()

	func _refresh() -> void:
		if _label == null:
			return
		if module_name.is_empty():
			_label.text = "  [+] Utility Slot %d" % (slot_index + 1)
			_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 0.85))
		else:
			_label.text = "  %d. %s" % [slot_index + 1, module_name]
			_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7, 1.0))
		_apply_style()

	func _apply_style() -> void:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(6)
		if _is_hover:
			s.bg_color = Color(0.3, 0.22, 0.08, 0.8)
			s.set_border_width_all(3)
			s.border_color = Color(1.0, 0.85, 0.3, 1.0)
		elif module_name.is_empty():
			s.bg_color = Color(0.08, 0.08, 0.1, 0.4)
			s.set_border_width_all(2)
			s.border_color = Color(0.5, 0.45, 0.35, 0.4)
		else:
			s.bg_color = Color(0.15, 0.12, 0.08, 0.5)
			s.set_border_width_all(2)
			s.border_color = Color(0.95, 0.7, 0.2, 0.7)
		add_theme_stylebox_override("panel", s)


func _ready() -> void:
	modulate.a = 0.0

	_loadout = GameManager.current_loadout
	if _loadout == null:
		_loadout = MechLoadout.new()
		GameManager.current_loadout = _loadout

	_slot_count = _loadout.get_total_utility_slots()
	if _slot_count < 1:
		_slot_count = 1

	_trim_or_pad_selected_modules()
	_build_module_catalog()
	_build_slot_list()
	_build_booster_modal()
	_build_drone_modal()
	_refresh_status()

	_back_button.pressed.connect(_on_back_pressed)
	_next_button.pressed.connect(_on_next_pressed)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)


func _trim_or_pad_selected_modules() -> void:
	for i in _loadout.selected_utility_modules.size():
		_loadout.selected_utility_modules[i] = _utility_module_data.ensure_module_data(
			_loadout.selected_utility_modules[i]
		)
	while _loadout.selected_utility_modules.size() > _slot_count:
		_loadout.selected_utility_modules.pop_back()
	while _loadout.selected_utility_modules.size() < _slot_count:
		_loadout.selected_utility_modules.append(null)


func _build_module_catalog() -> void:
	for child in _parts_box.get_children():
		child.queue_free()
	_parts_label.text = "UTILITY MODULES"

	for module_name in MODULE_NAMES:
		var card := ModuleCard.new()
		card.setup(module_name)
		_parts_box.add_child(card)


func _build_slot_list() -> void:
	for child in _slots_box.get_children():
		child.queue_free()
	_slot_boxes.clear()
	_slot_modify_buttons.clear()

	_slots_title.text = "UTILITY SLOT LIST"
	_selection_info.text = "Drag utility modules from the left into any available slot"

	for i in _slot_count:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_slots_box.add_child(row)

		var box := ModuleSlotBox.new()
		box.setup(i, "")
		box.module_dropped.connect(_on_module_dropped)
		row.add_child(box)
		_slot_boxes.append(box)

		var modify_btn := Button.new()
		modify_btn.text = "MODIFY"
		modify_btn.custom_minimum_size = Vector2(96, 44)
		modify_btn.pressed.connect(_on_modify_slot_pressed.bind(i))
		row.add_child(modify_btn)
		_slot_modify_buttons.append(modify_btn)

		var clear_btn := Button.new()
		clear_btn.text = "CLEAR"
		clear_btn.custom_minimum_size = Vector2(84, 44)
		clear_btn.pressed.connect(_on_clear_slot_pressed.bind(i))
		row.add_child(clear_btn)

		_refresh_slot_row(i)


func _build_booster_modal() -> void:
	_booster_modal_overlay = ColorRect.new()
	_booster_modal_overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	_booster_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_booster_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_booster_modal_overlay.visible = false
	_booster_modal_overlay.gui_input.connect(_on_booster_modal_overlay_input)
	add_child(_booster_modal_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_booster_modal_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.95, 0.7, 0.2, 0.95)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "BOOSTER VECTOR"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var help := Label.new()
	help.text = "Drag the angle marker around the circle. Top is forward relative to the mech."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66, 0.92))
	vbox.add_child(help)

	_booster_direction_dial = BoosterDirectionDial.new()
	_booster_direction_dial.angle_changed.connect(_on_booster_direction_changed)
	vbox.add_child(_booster_direction_dial)

	_booster_direction_label = Label.new()
	_booster_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_booster_direction_label.add_theme_font_size_override("font_size", 15)
	_booster_direction_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	vbox.add_child(_booster_direction_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	var reset_btn := Button.new()
	reset_btn.text = "RESET FORWARD"
	reset_btn.custom_minimum_size = Vector2(148, 38)
	reset_btn.pressed.connect(_on_reset_booster_pressed)
	button_row.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "DONE"
	close_btn.custom_minimum_size = Vector2(92, 38)
	close_btn.pressed.connect(_hide_booster_modal)
	button_row.add_child(close_btn)


func _build_drone_modal() -> void:
	_drone_modal_overlay = ColorRect.new()
	_drone_modal_overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	_drone_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drone_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_drone_modal_overlay.visible = false
	_drone_modal_overlay.gui_input.connect(_on_drone_modal_overlay_input)
	add_child(_drone_modal_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drone_modal_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.62, 0.8, 0.95, 0.95)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "DRONE BUILDER"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var help := Label.new()
	help.text = "3 slots. Components: Battery (1), Fire Control (2), Explosive Charge (1)."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95, 0.95))
	vbox.add_child(help)

	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 8)
	vbox.add_child(slots_row)

	_drone_component_slot_buttons.clear()
	for i in _DRONE_MODIFICATION_DATA_SCRIPT.DRONE_MODIFICATION_SLOT_COUNT:
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(72, 40)
		slot_btn.text = "S%d" % [i + 1]
		slot_btn.pressed.connect(_on_drone_component_slot_selected.bind(i))
		slots_row.add_child(slot_btn)
		_drone_component_slot_buttons.append(slot_btn)

	var parts_row := HBoxContainer.new()
	parts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parts_row.add_theme_constant_override("separation", 8)
	vbox.add_child(parts_row)

	var battery_btn := Button.new()
	battery_btn.text = "Battery"
	battery_btn.custom_minimum_size = Vector2(120, 38)
	battery_btn.pressed.connect(_on_drone_component_place.bind(_DRONE_MODIFICATION_DATA_SCRIPT.ComponentType.BATTERY))
	parts_row.add_child(battery_btn)

	var fire_control_btn := Button.new()
	fire_control_btn.text = "Fire Control"
	fire_control_btn.custom_minimum_size = Vector2(120, 38)
	fire_control_btn.pressed.connect(_on_drone_component_place.bind(_DRONE_MODIFICATION_DATA_SCRIPT.ComponentType.FIRE_CONTROL))
	parts_row.add_child(fire_control_btn)

	var explosive_btn := Button.new()
	explosive_btn.text = "Explosive Charge"
	explosive_btn.custom_minimum_size = Vector2(140, 38)
	explosive_btn.pressed.connect(_on_drone_component_place.bind(_DRONE_MODIFICATION_DATA_SCRIPT.ComponentType.EXPLOSIVE_CHARGE))
	parts_row.add_child(explosive_btn)

	var tools_row := HBoxContainer.new()
	tools_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tools_row.add_theme_constant_override("separation", 8)
	vbox.add_child(tools_row)

	var clear_slot_btn := Button.new()
	clear_slot_btn.text = "CLEAR SELECTED SLOT"
	clear_slot_btn.custom_minimum_size = Vector2(190, 38)
	clear_slot_btn.pressed.connect(_on_drone_clear_selected_slot_pressed)
	tools_row.add_child(clear_slot_btn)

	var clear_all_btn := Button.new()
	clear_all_btn.text = "CLEAR ALL"
	clear_all_btn.custom_minimum_size = Vector2(110, 38)
	clear_all_btn.pressed.connect(_on_drone_clear_all_pressed)
	tools_row.add_child(clear_all_btn)

	_drone_component_summary = Label.new()
	_drone_component_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drone_component_summary.add_theme_font_size_override("font_size", 14)
	_drone_component_summary.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62, 1.0))
	vbox.add_child(_drone_component_summary)

	_drone_component_hint = Label.new()
	_drone_component_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drone_component_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drone_component_hint.add_theme_color_override("font_color", Color(0.9, 0.58, 0.4, 0.95))
	vbox.add_child(_drone_component_hint)

	var close_btn := Button.new()
	close_btn.text = "DONE"
	close_btn.custom_minimum_size = Vector2(120, 38)
	close_btn.pressed.connect(_hide_drone_modal)
	vbox.add_child(close_btn)


func _on_drone_modal_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_drone_modal()


func _ensure_drone_modification_data(module: Variant) -> Variant:
	if module == null:
		return null
	var modifications = module.get("drone_modifications")
	if modifications == null:
		modifications = _DRONE_MODIFICATION_DATA_SCRIPT.new()
		module.drone_modifications = modifications
	return modifications


func _on_drone_component_slot_selected(component_slot_index: int) -> void:
	_drone_selected_component_slot = component_slot_index
	_refresh_drone_modal()


func _on_drone_component_place(component_type: int) -> void:
	if _drone_selected_slot < 0 or _drone_selected_slot >= _loadout.selected_utility_modules.size():
		return
	var module = _get_module(_drone_selected_slot)
	var modifications = _ensure_drone_modification_data(module)
	if modifications == null:
		return
	var placed: bool = modifications.try_place_component(_drone_selected_component_slot, component_type)
	if not placed:
		_drone_component_hint.text = "Cannot place component in selected slot."
	else:
		_drone_component_hint.text = ""
	_refresh_drone_modal()
	_refresh_slot_row(_drone_selected_slot)
	_refresh_status()


func _on_drone_clear_selected_slot_pressed() -> void:
	if _drone_selected_slot < 0 or _drone_selected_slot >= _loadout.selected_utility_modules.size():
		return
	var module = _get_module(_drone_selected_slot)
	var modifications = _ensure_drone_modification_data(module)
	if modifications == null:
		return
	modifications.clear_slot(_drone_selected_component_slot)
	_drone_component_hint.text = ""
	_refresh_drone_modal()
	_refresh_slot_row(_drone_selected_slot)
	_refresh_status()


func _on_drone_clear_all_pressed() -> void:
	if _drone_selected_slot < 0 or _drone_selected_slot >= _loadout.selected_utility_modules.size():
		return
	var module = _get_module(_drone_selected_slot)
	var modifications = _ensure_drone_modification_data(module)
	if modifications == null:
		return
	modifications.clear_all()
	_drone_component_hint.text = ""
	_refresh_drone_modal()
	_refresh_slot_row(_drone_selected_slot)
	_refresh_status()


func _refresh_drone_modal() -> void:
	if _drone_selected_slot < 0 or _drone_selected_slot >= _loadout.selected_utility_modules.size():
		return
	var module = _get_module(_drone_selected_slot)
	var modifications = _ensure_drone_modification_data(module)
	if modifications == null:
		return

	for i in _drone_component_slot_buttons.size():
		var slot_button = _drone_component_slot_buttons[i]
		var component_type: int = int(modifications.modification_layout[i])
		var component_name: String = _DRONE_MODIFICATION_DATA_SCRIPT.get_component_name(component_type)
		slot_button.text = "S%d\n%s" % [i + 1, component_name]
		slot_button.modulate = Color(1.0, 0.94, 0.72, 1.0) if i == _drone_selected_component_slot else Color(0.85, 0.9, 1.0, 1.0)

	var battery_bonus := int(modifications.get_battery_bonus())
	var has_fire_control: bool = bool(modifications.has_fire_control_module())
	var explosive_count := int(modifications.get_explosive_charge_count())
	var explosion_damage := int(modifications.get_explosion_damage())
	var explosion_radius := int(round(modifications.get_explosion_radius()))

	_drone_component_summary.text = "Battery +%d  |  Fire Control: %s  |  Charges: %d (DMG %d / AOE %d)" % [
		battery_bonus,
		"ON" if has_fire_control else "OFF",
		explosive_count,
		explosion_damage,
		explosion_radius,
	]


func _hide_drone_modal() -> void:
	_drone_modal_overlay.visible = false
	_drone_selected_slot = -1
	_drone_selected_component_slot = 0


func _on_module_dropped(slot_index: int, module_name: String) -> void:
	if slot_index < 0 or slot_index >= _loadout.selected_utility_modules.size():
		return
	_loadout.selected_utility_modules[slot_index] = _utility_module_data.from_module_name(module_name)
	if module_name == "Drone":
		var module = _get_module(slot_index)
		_ensure_drone_modification_data(module)
	_refresh_slot_row(slot_index)
	_refresh_status()


func _on_clear_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _loadout.selected_utility_modules.size():
		return
	_loadout.selected_utility_modules[slot_index] = null
	_refresh_slot_row(slot_index)
	_refresh_status()


func _on_modify_slot_pressed(slot_index: int) -> void:
	var module = _get_module(slot_index)
	var module_name := _utility_module_data.get_module_name(module)
	if module_name == "Booster":
		_booster_selected_slot = slot_index
		_booster_direction_dial.angle = float(module.get("direction_angle") if module != null else 0.0)
		_refresh_booster_direction_label(_booster_direction_dial.angle)
		_booster_modal_overlay.visible = true
		return
	if module_name == "Drone":
		_drone_selected_slot = slot_index
		_drone_selected_component_slot = 0
		_ensure_drone_modification_data(module)
		_drone_component_hint.text = ""
		_refresh_drone_modal()
		_drone_modal_overlay.visible = true


func _on_booster_modal_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_booster_modal()


func _on_booster_direction_changed(angle: float) -> void:
	if _booster_selected_slot < 0 or _booster_selected_slot >= _loadout.selected_utility_modules.size():
		return
	var module = _get_module(_booster_selected_slot)
	if module == null:
		return
	module.direction_angle = angle
	_refresh_booster_direction_label(angle)
	_refresh_slot_row(_booster_selected_slot)
	_refresh_status()


func _on_reset_booster_pressed() -> void:
	_booster_direction_dial.angle = 0.0
	_on_booster_direction_changed(0.0)


func _hide_booster_modal() -> void:
	_booster_modal_overlay.visible = false
	_booster_selected_slot = -1


func _refresh_booster_direction_label(angle: float) -> void:
	var angle_degrees := int(round(rad_to_deg(wrapf(angle, -PI, PI))))
	_booster_direction_label.text = "%s  ·  %d°" % [
		_utility_module_data.get_booster_direction_label(angle),
		angle_degrees,
	]


func _get_module(slot_index: int) -> Variant:
	if slot_index < 0 or slot_index >= _loadout.selected_utility_modules.size():
		return null
	var module = _utility_module_data.ensure_module_data(_loadout.selected_utility_modules[slot_index])
	_loadout.selected_utility_modules[slot_index] = module
	return module


func _refresh_slot_row(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_boxes.size():
		return
	var module = _get_module(slot_index)
	var label := _utility_module_data.get_module_name(module)
	if label == "Booster" and module != null:
		label = "%s [%s]" % [
			label,
			_utility_module_data.get_booster_direction_label(float(module.get("direction_angle"))),
		]
	elif label == "Drone" and module != null:
		var modifications = _ensure_drone_modification_data(module)
		if modifications != null:
			var battery_bonus := int(modifications.get_battery_bonus())
			var fire_control: bool = bool(modifications.has_fire_control_module())
			var explosive_count := int(modifications.get_explosive_charge_count())
			label = "Drone [B+%d FC:%s X:%d]" % [
				battery_bonus,
				"ON" if fire_control else "OFF",
				explosive_count,
			]
	_slot_boxes[slot_index].set_module_name(label)
	if slot_index < _slot_modify_buttons.size() and _slot_modify_buttons[slot_index]:
		var modify_button := _slot_modify_buttons[slot_index]
		modify_button.visible = not label.is_empty()
		var module_name := _utility_module_data.get_module_name(module)
		modify_button.disabled = module_name != "Booster" and module_name != "Drone"


func _refresh_status() -> void:
	var equipped := 0
	for selected in _loadout.selected_utility_modules:
		if not _utility_module_data.is_module_empty(selected):
			equipped += 1

	_slots_summary.text = "Equipped utility modules: %d / %d" % [equipped, _slot_count]
	_slots_summary.add_theme_color_override(
		"font_color",
		Color(0.95, 0.8, 0.35, 1.0) if equipped > 0 else Color(0.7, 0.65, 0.55, 0.85)
	)


func _on_back_pressed() -> void:
	_back_button.disabled = true
	_next_button.disabled = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/ui/workshop_screen.tscn")
	)


func _on_next_pressed() -> void:
	_back_button.disabled = true
	_next_button.disabled = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/ui/software_screen.tscn")
	)
