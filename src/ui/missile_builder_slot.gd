# missile_builder_slot.gd -- Drop target for one missile builder slot.
class_name MissileBuilderSlot
extends Panel

signal part_dropped(part_id: String, slot_index: int)
signal slot_clicked(slot_index: int)
signal drag_target_changed(part_id: String, slot_index: int, valid: bool)

var slot_index: int = 0
var is_locked: bool = false
var is_filled: bool = false

var _is_hover: bool = false
var _is_invalid_hover: bool = false
var _label: Label = null
var _drop_validator: Callable

func setup(index: int, zone_size: Vector2 = Vector2(44, 44)) -> void:
	slot_index = index
	custom_minimum_size = zone_size
	size = zone_size
	mouse_filter = MOUSE_FILTER_STOP

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)
	_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	set_display("%d" % (slot_index + 1), Color(0.66, 0.62, 0.56), false, false)


func set_drop_validator(validator: Callable) -> void:
	_drop_validator = validator


func set_display(text: String, color: Color, filled: bool, locked: bool) -> void:
	if _label:
		_label.text = text
		_label.add_theme_color_override("font_color", color)
	is_filled = filled
	is_locked = locked
	_apply_style()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if is_locked:
		_set_hover(false, true)
		return false
	if not (data is Dictionary):
		_set_hover(false, false)
		return false
	var drag_type := String(data.get("type", ""))
	if drag_type != "missile_builder_part":
		_set_hover(false, false)
		return false
	var part_id := String(data.get("part_id", ""))
	var valid := not _drop_validator.is_valid() or bool(_drop_validator.call(part_id, slot_index))
	_set_hover(valid, not valid)
	drag_target_changed.emit(part_id, slot_index, valid)
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hover(false, false)
	part_dropped.emit(String(data.get("part_id", "")), slot_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(slot_index)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_hover(false, false)


func _set_hover(on: bool, invalid: bool) -> void:
	if _is_hover == on and _is_invalid_hover == invalid:
		return
	_is_hover = on
	_is_invalid_hover = invalid
	_apply_style()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	if _is_invalid_hover:
		style.bg_color = Color(0.35, 0.07, 0.06, 0.9)
		style.set_border_width_all(3)
		style.border_color = Color(1.0, 0.3, 0.22, 1.0)
		style.shadow_color = Color(1.0, 0.12, 0.08, 0.45)
		style.shadow_size = 8
	elif _is_hover and not is_locked:
		style.bg_color = Color(0.31, 0.23, 0.08, 0.85)
		style.set_border_width_all(3)
		style.border_color = Color(1.0, 0.86, 0.31, 1.0)
		style.shadow_color = Color(1.0, 0.72, 0.18, 0.5)
		style.shadow_size = 9
	elif is_locked:
		style.bg_color = Color(0.08, 0.08, 0.1, 0.5)
		style.set_border_width_all(1)
		style.border_color = Color(0.35, 0.35, 0.4, 0.35)
	elif is_filled:
		style.bg_color = Color(0.14, 0.12, 0.08, 0.55)
		style.set_border_width_all(2)
		style.border_color = Color(0.94, 0.72, 0.25, 0.75)
	else:
		style.bg_color = Color(0.08, 0.08, 0.1, 0.4)
		style.set_border_width_all(2)
		style.border_color = Color(0.49, 0.45, 0.37, 0.45)
	style.set_content_margin_all(3)
	add_theme_stylebox_override("panel", style)
