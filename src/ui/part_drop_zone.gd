# part_drop_zone.gd — Drop target for equipping mech parts in the workshop.
# While a compatible part is being dragged anywhere on screen, the zone lights
# up and pulses so the player immediately sees where the part can go.
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
var _is_candidate: bool = false   # A compatible part is being dragged somewhere
var _pulse_tween: Tween = null


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


## True when this zone accepts parts of the given drag category.
func _accepts(drag_type: String) -> bool:
	if drag_type == accepted_type:
		return true
	# Light weapons can also be dropped in medium weapon slots
	return accepted_type == "weapon" and drag_type == "light_weapon"


# ── Drag-and-drop callbacks ──────────────────────────────────────────────────

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		if _is_hover:
			_is_hover = false
			_apply_style()
		return false
	var ok := _accepts(data.get("type", ""))
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
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var data: Variant = get_viewport().gui_get_drag_data()
			if data is Dictionary and _accepts(data.get("type", "")):
				_is_candidate = true
				_start_pulse()
				_apply_style()
		NOTIFICATION_DRAG_END:
			_is_candidate = false
			_is_hover = false
			_stop_pulse()
			_apply_style()


# ── Pulse animation while a compatible drag is active ────────────────────────

func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "self_modulate:a", 0.55, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "self_modulate:a", 1.0, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	self_modulate.a = 1.0


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
	s.set_corner_radius_all(8)
	if _is_hover:
		s.bg_color = Color(0.32, 0.24, 0.08, 0.9)
		s.set_border_width_all(3)
		s.border_color = Color(1.0, 0.85, 0.3, 1.0)
		s.shadow_color = Color(1.0, 0.85, 0.3, 0.45)
		s.shadow_size = 10
	elif _is_candidate:
		s.bg_color = Color(0.1, 0.2, 0.18, 0.75)
		s.set_border_width_all(2)
		s.border_color = Color(0.35, 0.9, 0.8, 0.95)
		s.shadow_color = Color(0.3, 0.85, 0.75, 0.3)
		s.shadow_size = 8
	elif equipped_data:
		s.bg_color = Color(0.15, 0.12, 0.08, 0.5)
		s.set_border_width_all(2)
		s.border_color = Color(0.95, 0.7, 0.2, 0.7)
	else:
		s.bg_color = Color(0.08, 0.08, 0.1, 0.4)
		s.set_border_width_all(2)
		s.border_color = Color(0.5, 0.45, 0.35, 0.4)
	add_theme_stylebox_override("panel", s)
