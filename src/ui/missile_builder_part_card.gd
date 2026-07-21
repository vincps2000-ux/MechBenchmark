# missile_builder_part_card.gd -- Draggable catalog card for workshop missile builder.
class_name MissileBuilderPartCard
extends PanelContainer

signal drag_started(part_id: String, slot_cost: int)
signal drag_finished(part_id: String, successful: bool)

var part_id: String = ""
var part_title: String = ""
var part_description: String = ""
var slot_cost: int = 1
var _hovered := false
var _dragging := false
var _accent := Color(0.95, 0.72, 0.25)

func setup(id: String, title: String, description: String, cost: int) -> void:
	part_id = id
	part_title = title
	part_description = description
	slot_cost = maxi(cost, 1)
	_accent = _get_part_color(part_id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	add_child(row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(48, 48)
	icon_panel.mouse_filter = MOUSE_FILTER_IGNORE
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(_accent, 0.13)
	icon_style.set_border_width_all(1)
	icon_style.border_color = Color(_accent, 0.7)
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_panel)

	var icon := Label.new()
	icon.text = _get_part_icon(part_id)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", _accent)
	icon_panel.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	row.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var title_label := Label.new()
	title_label.text = part_title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.76))
	title_row.add_child(title_label)

	var size_badge := Label.new()
	size_badge.text = "x%d" % slot_cost
	size_badge.add_theme_font_size_override("font_size", 11)
	size_badge.add_theme_color_override("font_color", _accent)
	title_row.add_child(size_badge)

	var desc := Label.new()
	desc.text = part_description
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.58, 0.54, 0.48))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	custom_minimum_size = Vector2(0, 70)
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_entered.connect(func():
		_hovered = true
		_apply_style()
	)
	mouse_exited.connect(func():
		_hovered = false
		_apply_style()
	)
	_apply_style()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.1, 0.07, 0.98) if _dragging else Color(0.12, 0.14, 0.15, 0.96) if _hovered else Color(0.075, 0.085, 0.095, 0.9)
	style.set_border_width_all(2 if _hovered or _dragging else 1)
	style.border_color = Color(_accent, 1.0 if _dragging else 0.78 if _hovered else 0.34)
	style.shadow_color = Color(_accent, 0.32 if _hovered or _dragging else 0.0)
	style.shadow_size = 7 if _hovered or _dragging else 0
	style.set_corner_radius_all(7)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	_dragging = true
	_apply_style()
	drag_started.emit(part_id, slot_cost)

	var preview := PanelContainer.new()
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)
	preview.add_child(preview_row)
	var icon := Label.new()
	icon.text = _get_part_icon(part_id)
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", _accent)
	preview_row.add_child(icon)
	var lbl := Label.new()
	lbl.text = "%s  [x%d]" % [part_title, slot_cost]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.91, 0.75))
	preview_row.add_child(lbl)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.16, 0.12, 0.09, 0.95)
	ps.set_border_width_all(2)
	ps.border_color = _accent
	ps.shadow_color = Color(_accent, 0.45)
	ps.shadow_size = 10
	ps.set_corner_radius_all(6)
	ps.set_content_margin_all(6)
	preview.add_theme_stylebox_override("panel", ps)
	set_drag_preview(preview)

	return {
		"type": "missile_builder_part",
		"part_id": part_id,
		"slot_cost": slot_cost,
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		_apply_style()
		drag_finished.emit(part_id, is_drag_successful())


static func _get_part_color(id: String) -> Color:
	match id:
		"fuel": return Color(0.95, 0.74, 0.2)
		"explosive": return Color(1.0, 0.34, 0.16)
		"wire_guided": return Color(0.24, 0.78, 0.96)
		"homing": return Color(0.3, 0.95, 0.58)
		"cluster": return Color(0.84, 0.42, 1.0)
		"proximity_trigger": return Color(0.35, 0.95, 0.88)
		_: return Color(0.95, 0.72, 0.25)


static func _get_part_icon(id: String) -> String:
	match id:
		"fuel": return "F"
		"explosive": return "X"
		"wire_guided": return "W"
		"homing": return "H"
		"cluster": return "C"
		"proximity_trigger": return "P"
		_: return "?"
