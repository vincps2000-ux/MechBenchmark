# part_drop_zone.gd — Drop target for equipping mech parts in the workshop.
# Visual feedback updates automatically during drag hover.
class_name PartDropZone
extends Panel

## Emitted when a part is dropped onto this zone.
signal part_equipped(data: Variant)

## Category this zone accepts: "legs", "torso", or "weapon".
var accepted_type: String = ""
## Currently equipped part (null when empty).
var equipped_data = null
## Display name for the slot.
var slot_label: String = ""
## Slot index (for multi-weapon torsos).
var slot_index: int = 0

var _label: Label = null
var _is_hover: bool = false


func setup(type: String, label: String, zone_size: Vector2, index: int = 0) -> void:
	accepted_type = type
	slot_label = label
	slot_index = index
	custom_minimum_size = zone_size
	size = zone_size
	mouse_filter = MOUSE_FILTER_STOP

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)
	_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_refresh()


func clear() -> void:
	equipped_data = null
	_is_hover = false
	_refresh()


# ── Drag-and-drop callbacks ──────────────────────────────────────────────────

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		if _is_hover:
			_is_hover = false
			_apply_style()
		return false
	var drag_type: String = data.get("type", "")
	var ok := false
	if drag_type == accepted_type:
		ok = true
	elif accepted_type == "weapon" and drag_type == "light_weapon":
		# Light weapons can also be dropped in medium weapon slots
		ok = true
	if _is_hover != ok:
		_is_hover = ok
		_apply_style()
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	equipped_data = data["data"]
	_is_hover = false
	_refresh()
	part_equipped.emit(equipped_data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _is_hover:
		_is_hover = false
		_apply_style()


# ── Visuals ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _label == null:
		return
	if equipped_data:
		_label.text = equipped_data.name
		_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7, 1.0))
	else:
		_label.text = "+ " + slot_label
		_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 0.85))
	_apply_style()


func _apply_style() -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	if _is_hover:
		s.bg_color = Color(0.3, 0.22, 0.08, 0.8)
		s.set_border_width_all(3)
		s.border_color = Color(1.0, 0.85, 0.3, 1.0)
	elif equipped_data:
		s.bg_color = Color(0.15, 0.12, 0.08, 0.5)
		s.set_border_width_all(2)
		s.border_color = Color(0.95, 0.7, 0.2, 0.7)
	else:
		s.bg_color = Color(0.08, 0.08, 0.1, 0.4)
		s.set_border_width_all(2)
		s.border_color = Color(0.5, 0.45, 0.35, 0.4)
	add_theme_stylebox_override("panel", s)
