class_name MissileBuilderPreview
extends Control

signal part_dropped(part_id: String, slot_index: int)
signal slot_clicked(slot_index: int)
signal drag_target_changed(part_id: String, slot_index: int, valid: bool)

const SLOT_COUNT := 6
const SLOT_GAP := 8.0

var slot_zones: Array[MissileBuilderSlot] = []
var layout: Array[String] = []
var active_part_id := ""
var active_part_cost := 1


func setup(drop_validator: Callable) -> void:
	custom_minimum_size = Vector2(420, 230)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_slots)

	for i in SLOT_COUNT:
		var slot := MissileBuilderSlot.new()
		slot.setup(i, Vector2(46, 46))
		slot.set_drop_validator(drop_validator)
		slot.part_dropped.connect(func(part_id: String, slot_index: int):
			part_dropped.emit(part_id, slot_index)
		)
		slot.slot_clicked.connect(func(slot_index: int):
			slot_clicked.emit(slot_index)
		)
		slot.drag_target_changed.connect(func(part_id: String, slot_index: int, valid: bool):
			drag_target_changed.emit(part_id, slot_index, valid)
		)
		add_child(slot)
		slot_zones.append(slot)

	_layout_slots()
	queue_redraw()


func set_layout(value: Array[String]) -> void:
	layout = value.duplicate()
	queue_redraw()


func set_dragged_part(part_id: String, cost: int) -> void:
	active_part_id = part_id
	active_part_cost = maxi(cost, 1)
	queue_redraw()


func clear_dragged_part() -> void:
	active_part_id = ""
	active_part_cost = 1
	queue_redraw()


func _layout_slots() -> void:
	if slot_zones.is_empty():
		return
	var slot_size := clampf((size.x - 180.0 - SLOT_GAP * 5.0) / 6.0, 38.0, 54.0)
	var total_width := slot_size * 6.0 + SLOT_GAP * 5.0
	var start_x := (size.x - total_width) * 0.5
	var slot_y := size.y * 0.5 - slot_size * 0.5
	for i in slot_zones.size():
		var slot := slot_zones[i]
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.size = Vector2(slot_size, slot_size)
		slot.position = Vector2(start_x + float(i) * (slot_size + SLOT_GAP), slot_y)
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.035, 0.045, 0.052), true)

	for x in range(0, int(size.x), 24):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.15, 0.29, 0.32, 0.18), 1.0)
	for y in range(0, int(size.y), 24):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.15, 0.29, 0.32, 0.18), 1.0)

	draw_rect(Rect2(0, size.y - 34, size.x, 34), Color(0.09, 0.065, 0.04), true)
	draw_line(Vector2(0, size.y - 34), Vector2(size.x, size.y - 34), Color(0.86, 0.55, 0.14, 0.72), 2.0)

	var font := get_theme_default_font()
	draw_string(font, Vector2(14, 21), "ORDNANCE CUTAWAY / LIVE TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.42, 0.78, 0.82))
	draw_string(font, Vector2(size.x - 132, 21), "BAY 06", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.93, 0.62, 0.2))

	if slot_zones.is_empty():
		return

	var first: Control = slot_zones.front()
	var last: Control = slot_zones.back()
	var body_left: float = first.position.x - 25.0
	var body_right: float = last.position.x + last.size.x + 25.0
	var center_y := size.y * 0.5
	var body_height := maxf(82.0, first.size.y + 28.0)
	var body_rect := Rect2(body_left, center_y - body_height * 0.5, body_right - body_left, body_height)

	draw_rect(body_rect.grow(5.0), Color(0, 0, 0, 0.42), true)
	draw_rect(body_rect, Color(0.16, 0.19, 0.19), true)
	draw_rect(Rect2(body_rect.position + Vector2(5, 5), body_rect.size - Vector2(10, 10)), Color(0.25, 0.28, 0.26), true)
	draw_line(body_rect.position + Vector2(8, 10), Vector2(body_rect.end.x - 8, body_rect.position.y + 10), Color(0.62, 0.65, 0.55, 0.4), 2.0)

	var nose := PackedVector2Array([
		Vector2(body_left, body_rect.position.y),
		Vector2(body_left - 58, center_y - 12),
		Vector2(body_left - 76, center_y),
		Vector2(body_left - 58, center_y + 12),
		Vector2(body_left, body_rect.end.y),
	])
	draw_colored_polygon(nose, Color(0.22, 0.25, 0.24))
	draw_polyline(nose, Color(0.68, 0.61, 0.4, 0.75), 2.0)
	draw_circle(Vector2(body_left - 50, center_y), 5.0, Color(0.95, 0.7, 0.22, 0.8))

	var tail_x: float = body_right
	draw_rect(Rect2(tail_x, center_y - 31, 38, 62), Color(0.12, 0.14, 0.14), true)
	draw_rect(Rect2(tail_x + 31, center_y - 22, 23, 44), Color(0.25, 0.16, 0.07), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(tail_x + 4, center_y - 25),
		Vector2(tail_x + 37, center_y - 57),
		Vector2(tail_x + 25, center_y - 19),
	]), Color(0.3, 0.32, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(tail_x + 4, center_y + 25),
		Vector2(tail_x + 37, center_y + 57),
		Vector2(tail_x + 25, center_y + 19),
	]), Color(0.3, 0.32, 0.28))

	for i in 9:
		var rivet_x: float = body_left + 12.0 + float(i) * (body_rect.size.x - 24.0) / 8.0
		draw_circle(Vector2(rivet_x, body_rect.position.y + 7), 2.1, Color(0.72, 0.68, 0.49))
		draw_circle(Vector2(rivet_x, body_rect.end.y - 7), 2.1, Color(0.72, 0.68, 0.49))

	for i in slot_zones.size() - 1:
		var from := slot_zones[i].position + Vector2(slot_zones[i].size.x, slot_zones[i].size.y * 0.5)
		var to := slot_zones[i + 1].position + Vector2(0, slot_zones[i + 1].size.y * 0.5)
		draw_line(from, to, Color(0.9, 0.59, 0.18, 0.7), 3.0)
		draw_line(from + Vector2(0, 4), to + Vector2(0, 4), Color(0.24, 0.7, 0.72, 0.45), 1.0)

	if not active_part_id.is_empty():
		var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.008) * 0.2
		draw_rect(body_rect.grow(9.0), Color(0.25, 0.83, 0.77, pulse), false, 2.0)
		draw_string(font, Vector2(body_left, body_rect.position.y - 13), "ROUTING %s / %d BAY%s" % [
			active_part_id.to_upper().replace("_", " "),
			active_part_cost,
			"S" if active_part_cost > 1 else "",
		], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.95, 0.88))
		queue_redraw()

	for mark_x in range(18, int(size.x) - 18, 16):
		var mark_height := 8.0 if mark_x % 64 == 18 else 4.0
		draw_line(Vector2(mark_x, size.y - 32), Vector2(mark_x, size.y - 32 + mark_height), Color(0.8, 0.56, 0.18, 0.7), 1.0)
	draw_string(font, Vector2(14, size.y - 9), "ARMOURY CALIPER / SLOT TOLERANCE 0.02", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.51, 0.2))
