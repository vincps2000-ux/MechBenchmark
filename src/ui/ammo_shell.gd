# ammo_shell.gd — Procedurally drawn ammo shell for the selection modal.
# HE: brass casing + red round tip
# Solid: brass casing + dark pointed tip
# Canister: brass casing + boxy blue tip
class_name AmmoShell
extends Control

signal shell_clicked(ammo_type: WeaponData.AmmoType)

var ammo_type: WeaponData.AmmoType = WeaponData.AmmoType.HE
var is_selected: bool = false
var _hovered: bool = false

const SHELL_WIDTH  := 40.0
const SHELL_HEIGHT := 100.0
const CASING_RATIO := 0.55  # bottom 55% is brass casing

func _init() -> void:
	custom_minimum_size = Vector2(SHELL_WIDTH + 16, SHELL_HEIGHT + 32)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(type: WeaponData.AmmoType, selected: bool) -> void:
	ammo_type = type
	is_selected = selected
	queue_redraw()

func _draw() -> void:
	var cx := size.x * 0.5
	var top := 16.0  # leave room for arrow above
	var casing_h := SHELL_HEIGHT * CASING_RATIO
	var tip_h := SHELL_HEIGHT * (1.0 - CASING_RATIO)

	# Hover highlight — bright yellow outline around entire shell
	if _hovered:
		var outline_rect := Rect2(cx - SHELL_WIDTH * 0.5 - 3, top - 3, SHELL_WIDTH + 6, SHELL_HEIGHT + 6)
		draw_rect(outline_rect, Color(1.0, 0.95, 0.2, 0.9), false, 2.5)

	# Brass casing (bottom part)
	var casing_top := top + tip_h
	var casing_rect := Rect2(cx - SHELL_WIDTH * 0.5, casing_top, SHELL_WIDTH, casing_h)
	draw_rect(casing_rect, Color(0.75, 0.6, 0.25))  # brass

	# Casing rim at very bottom
	var rim_rect := Rect2(cx - SHELL_WIDTH * 0.5 - 2, casing_top + casing_h - 6, SHELL_WIDTH + 4, 6)
	draw_rect(rim_rect, Color(0.65, 0.5, 0.2))

	# Primer circle at bottom center
	draw_circle(Vector2(cx, casing_top + casing_h - 3), 4.0, Color(0.55, 0.42, 0.18))

	# Tip varies by ammo type
	match ammo_type:
		WeaponData.AmmoType.HE:
			_draw_he_tip(cx, top, tip_h)
		WeaponData.AmmoType.SOLID:
			_draw_solid_tip(cx, top, tip_h)
		WeaponData.AmmoType.CANISTER:
			_draw_canister_tip(cx, top, tip_h)

	# Selected arrow — small red downward arrow above shell
	if is_selected:
		var arrow_y := top - 6
		var arrow_pts := PackedVector2Array([
			Vector2(cx, arrow_y),
			Vector2(cx - 7, arrow_y - 10),
			Vector2(cx + 7, arrow_y - 10),
		])
		draw_colored_polygon(arrow_pts, Color(0.95, 0.15, 0.15))


func _draw_he_tip(cx: float, top: float, tip_h: float) -> void:
	# HE: rounded red tip (ogive shape approximated with polygon)
	var hw := SHELL_WIDTH * 0.5
	var base_y := top + tip_h
	var pts := PackedVector2Array()
	# Build an ogive curve from base to tip
	var steps := 12
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := base_y - t * tip_h
		# Ogive profile: wider at base, rounding to top
		var x_scale := cos(t * PI * 0.5)  # round falloff
		pts.append(Vector2(cx + hw * x_scale, y))
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var y := base_y - t * tip_h
		var x_scale := cos(t * PI * 0.5)
		pts.append(Vector2(cx - hw * x_scale, y))
	draw_colored_polygon(pts, Color(0.85, 0.15, 0.1))  # red

	# Highlight stripe
	var stripe_pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := base_y - t * tip_h
		var x_scale := cos(t * PI * 0.5) * 0.25
		stripe_pts.append(Vector2(cx - hw * 0.15 + hw * x_scale, y))
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var y := base_y - t * tip_h
		var x_scale := cos(t * PI * 0.5) * 0.05
		stripe_pts.append(Vector2(cx - hw * 0.15 - hw * x_scale, y))
	draw_colored_polygon(stripe_pts, Color(1.0, 0.35, 0.3, 0.35))


func _draw_solid_tip(cx: float, top: float, tip_h: float) -> void:
	# Solid: pointed triangular tip — dark steel
	var hw := SHELL_WIDTH * 0.5
	var base_y := top + tip_h
	var pts := PackedVector2Array([
		Vector2(cx, top),                   # sharp point
		Vector2(cx + hw, base_y),           # bottom right
		Vector2(cx - hw, base_y),           # bottom left
	])
	draw_colored_polygon(pts, Color(0.35, 0.35, 0.38))  # dark steel

	# Highlight edge
	var hl_pts := PackedVector2Array([
		Vector2(cx, top),
		Vector2(cx - hw * 0.15, base_y),
		Vector2(cx - hw * 0.35, base_y),
	])
	draw_colored_polygon(hl_pts, Color(0.5, 0.5, 0.55, 0.3))


func _draw_canister_tip(cx: float, top: float, tip_h: float) -> void:
	# Canister: boxy blue shell
	var hw := SHELL_WIDTH * 0.5
	var base_y := top + tip_h
	# Main rectangular body
	var body_rect := Rect2(cx - hw, top + 4, SHELL_WIDTH, tip_h - 4)
	draw_rect(body_rect, Color(0.2, 0.35, 0.7))  # blue

	# Flat top cap — slightly wider
	var cap_rect := Rect2(cx - hw - 1, top, SHELL_WIDTH + 2, 6)
	draw_rect(cap_rect, Color(0.25, 0.4, 0.75))

	# Grid pattern to suggest pellets inside
	var grid_color := Color(0.15, 0.25, 0.55, 0.6)
	var rows := 3
	var cols := 3
	var cell_w := (SHELL_WIDTH - 8) / cols
	var cell_h := (tip_h - 14) / rows
	for r in rows:
		for c in cols:
			var dot_x := cx - hw + 4 + c * cell_w + cell_w * 0.5
			var dot_y := top + 8 + r * cell_h + cell_h * 0.5
			draw_circle(Vector2(dot_x, dot_y), 3.0, grid_color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shell_clicked.emit(ammo_type)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		queue_redraw()
