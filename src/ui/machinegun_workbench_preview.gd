class_name MachinegunWorkbenchPreview
extends Control

var barrel_count := WeaponData.MIN_BARREL_COUNT
var barrel_length := WeaponData.DEFAULT_BARREL_LENGTH
var ammo_type := WeaponData.AmmoType.NORMAL


func configure(gun: WeaponData) -> void:
	barrel_count = WeaponData.clamp_barrel_count(gun.barrel_count)
	barrel_length = WeaponData.clamp_barrel_length(gun.barrel_length)
	ammo_type = gun.ammo_type
	custom_minimum_size = Vector2(700, 230)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.055, 0.045, 0.035), true)

	for x in range(0, int(size.x), 24):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.18, 0.13, 0.08, 0.28), 1.0)
	for y in range(0, int(size.y), 24):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.18, 0.13, 0.08, 0.28), 1.0)

	draw_rect(Rect2(0, size.y - 34, size.x, 34), Color(0.12, 0.085, 0.05), true)
	draw_line(Vector2(0, size.y - 34), Vector2(size.x, size.y - 34), Color(0.65, 0.4, 0.12, 0.75), 2.0)

	_draw_service_tools()
	_draw_machinegun()
	_draw_service_marks()


func _draw_machinegun() -> void:
	var receiver_x := 210.0
	var center_y := 108.0
	var barrel_px := 112.0 + float(barrel_length) * 25.0

	draw_rect(Rect2(receiver_x - 4, center_y - 39, 170, 83), Color(0, 0, 0, 0.45), true)
	draw_rect(Rect2(receiver_x, center_y - 43, 164, 76), Color(0.16, 0.18, 0.18), true)
	draw_rect(Rect2(receiver_x + 8, center_y - 35, 148, 58), Color(0.27, 0.29, 0.28), true)
	draw_rect(Rect2(receiver_x + 17, center_y - 27, 73, 37), Color(0.095, 0.105, 0.10), true)
	draw_rect(Rect2(receiver_x + 25, center_y - 20, 56, 22), Color(0.035, 0.04, 0.038), true)

	var top_cover := PackedVector2Array([
		Vector2(receiver_x + 15, center_y - 35),
		Vector2(receiver_x + 36, center_y - 53),
		Vector2(receiver_x + 136, center_y - 53),
		Vector2(receiver_x + 154, center_y - 35),
	])
	draw_colored_polygon(top_cover, Color(0.22, 0.235, 0.225))
	draw_polyline(top_cover, Color(0.52, 0.48, 0.36), 1.5)

	for bolt_x in [receiver_x + 18, receiver_x + 145]:
		for bolt_y in [center_y - 30, center_y + 18]:
			draw_circle(Vector2(bolt_x, bolt_y), 4.0, Color(0.62, 0.57, 0.42))
			draw_line(Vector2(bolt_x - 2, bolt_y), Vector2(bolt_x + 2, bolt_y), Color(0.15, 0.14, 0.11), 1.0)

	var grip := PackedVector2Array([
		Vector2(receiver_x + 50, center_y + 30),
		Vector2(receiver_x + 90, center_y + 30),
		Vector2(receiver_x + 81, center_y + 79),
		Vector2(receiver_x + 56, center_y + 79),
	])
	draw_colored_polygon(grip, Color(0.18, 0.14, 0.09))
	for y in range(int(center_y + 42), int(center_y + 74), 7):
		draw_line(Vector2(receiver_x + 57, y), Vector2(receiver_x + 82, y), Color(0.45, 0.31, 0.14), 2.0)

	draw_rect(Rect2(receiver_x + 96, center_y + 26, 55, 15), Color(0.1, 0.11, 0.105), true)
	draw_arc(Vector2(receiver_x + 122, center_y + 43), 22, PI, TAU, 18, Color(0.44, 0.41, 0.32), 3.0)

	var barrel_start := receiver_x + 150.0
	var spacing := 13.0
	for i in barrel_count:
		var offset := (float(i) - float(barrel_count - 1) * 0.5) * spacing
		var barrel_y := center_y + offset
		draw_rect(Rect2(barrel_start, barrel_y - 4, barrel_px, 9), Color(0.38, 0.405, 0.39), true)
		draw_line(Vector2(barrel_start + 5, barrel_y - 2), Vector2(barrel_start + barrel_px - 4, barrel_y - 2), Color(0.7, 0.67, 0.53, 0.55), 1.0)
		draw_rect(Rect2(barrel_start + 24, barrel_y - 7, barrel_px - 42, 3), Color(0.08, 0.09, 0.085), true)
		draw_rect(Rect2(barrel_start + barrel_px - 8, barrel_y - 7, 15, 15), Color(0.13, 0.14, 0.135), true)
		draw_circle(Vector2(barrel_start + barrel_px + 7, barrel_y), 6.5, Color(0.04, 0.045, 0.04))
		draw_arc(Vector2(barrel_start + barrel_px + 7, barrel_y), 6.5, 0, TAU, 20, Color(0.55, 0.5, 0.36), 1.0)

	draw_rect(Rect2(barrel_start - 2, center_y - 36, 28, 72), Color(0.12, 0.135, 0.13), true)
	for y in range(int(center_y - 28), int(center_y + 29), 10):
		draw_rect(Rect2(barrel_start + 5, y, 15, 4), Color(0.34, 0.36, 0.34), true)

	var ammo_color := _ammo_color()
	draw_rect(Rect2(receiver_x - 35, center_y + 17, 50, 54), Color(0.12, 0.14, 0.13), true)
	draw_rect(Rect2(receiver_x - 29, center_y + 23, 38, 42), Color(0.25, 0.27, 0.24), true)
	for i in 7:
		var round_x := receiver_x - 12.0 + float(i) * 11.0
		var round_y := center_y + 13.0 + sin(float(i) * 0.8) * 7.0
		draw_rect(Rect2(round_x, round_y, 7, 18), Color(0.68, 0.48, 0.16), true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(round_x, round_y),
			Vector2(round_x + 3.5, round_y - 7),
			Vector2(round_x + 7, round_y),
		]), ammo_color)


func _draw_service_tools() -> void:
	draw_line(Vector2(26, 36), Vector2(153, 163), Color(0, 0, 0, 0.45), 15.0)
	draw_line(Vector2(26, 33), Vector2(153, 160), Color(0.32, 0.34, 0.32), 11.0)
	draw_arc(Vector2(30, 36), 22, -0.9, 2.3, 24, Color(0.48, 0.5, 0.46), 8.0)
	draw_circle(Vector2(154, 161), 12, Color(0.38, 0.39, 0.36))
	draw_circle(Vector2(154, 161), 5, Color(0.075, 0.06, 0.045))

	draw_line(Vector2(size.x - 72, 43), Vector2(size.x - 145, 155), Color(0.6, 0.22, 0.08), 13.0)
	draw_line(Vector2(size.x - 145, 155), Vector2(size.x - 177, 192), Color(0.48, 0.5, 0.47), 7.0)
	draw_circle(Vector2(size.x - 72, 43), 9, Color(0.16, 0.12, 0.08))

	draw_rect(Rect2(30, size.y - 26, 112, 14), Color(0.72, 0.57, 0.18, 0.85), true)
	for mark_x in range(38, 136, 10):
		draw_line(Vector2(mark_x, size.y - 25), Vector2(mark_x, size.y - 18), Color(0.18, 0.13, 0.05), 1.0)


func _draw_service_marks() -> void:
	var font := get_theme_default_font()
	draw_string(font, Vector2(18, size.y - 9), "BENCH 04 / ARMOURY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.76, 0.54, 0.18))
	draw_string(font, Vector2(size.x - 175, size.y - 9), "TORQUE: VERIFIED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.42, 0.72, 0.55))
	draw_line(Vector2(262, 73), Vector2(310, 65), Color(0.72, 0.64, 0.48, 0.42), 1.0)
	draw_line(Vector2(278, 78), Vector2(326, 70), Color(0.72, 0.64, 0.48, 0.3), 1.0)


func _ammo_color() -> Color:
	match ammo_type:
		WeaponData.AmmoType.RIOT:
			return Color(0.2, 0.55, 1.0)
		WeaponData.AmmoType.SMART:
			return Color(0.3, 1.0, 0.48)
		_:
			return Color(0.95, 0.72, 0.2)
