# missile_builder_part_card.gd -- Draggable catalog card for workshop missile builder.
class_name MissileBuilderPartCard
extends PanelContainer

var part_id: String = ""
var part_title: String = ""
var part_description: String = ""
var slot_cost: int = 1

func setup(id: String, title: String, description: String, cost: int) -> void:
	part_id = id
	part_title = title
	part_description = description
	slot_cost = maxi(cost, 1)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var title_label := Label.new()
	title_label.text = part_title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title_row.add_child(title_label)

	var size_badge := Label.new()
	size_badge.text = "x%d" % slot_cost
	size_badge.add_theme_font_size_override("font_size", 11)
	size_badge.add_theme_color_override("font_color", Color(0.95, 0.72, 0.25, 0.9))
	title_row.add_child(size_badge)

	var desc := Label.new()
	desc.text = part_description
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.58, 0.54, 0.48))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	custom_minimum_size = Vector2(0, 70)
	mouse_filter = MOUSE_FILTER_STOP
	_apply_style()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.88)
	style.set_border_width_all(1)
	style.border_color = Color(0.38, 0.33, 0.25, 0.5)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := PanelContainer.new()
	var lbl := Label.new()
	lbl.text = "  %s  " % part_title
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	preview.add_child(lbl)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.16, 0.12, 0.09, 0.95)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.95, 0.72, 0.25, 0.9)
	ps.set_corner_radius_all(6)
	ps.set_content_margin_all(6)
	preview.add_theme_stylebox_override("panel", ps)
	set_drag_preview(preview)

	return {
		"type": "missile_builder_part",
		"part_id": part_id,
		"slot_cost": slot_cost,
	}
