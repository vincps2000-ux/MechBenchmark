# thrower_tank.gd - Procedural tank widget for Chemical thrower element selection.
class_name ThrowerTank
extends Control

signal tank_clicked(element: WeaponData.ThrowerElement)

var element: WeaponData.ThrowerElement = WeaponData.ThrowerElement.FUEL
var is_selected: bool = false
var _hovered: bool = false

const TANK_WIDTH := 70.0
const TANK_HEIGHT := 88.0

func _init() -> void:
	custom_minimum_size = Vector2(TANK_WIDTH + 20.0, TANK_HEIGHT + 34.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(next_element: WeaponData.ThrowerElement, selected: bool) -> void:
	element = next_element
	is_selected = selected
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var top := 16.0
	var body_rect := Rect2(cx - TANK_WIDTH * 0.5, top + 8.0, TANK_WIDTH, TANK_HEIGHT - 14.0)
	var cap_rect := Rect2(cx - TANK_WIDTH * 0.3, top, TANK_WIDTH * 0.6, 14.0)
	var fluid_rect := body_rect.grow(-8.0)
	fluid_rect.position.y += 10.0
	fluid_rect.size.y -= 12.0

	if _hovered:
		var hover_rect := Rect2(cx - TANK_WIDTH * 0.5 - 4.0, top - 4.0, TANK_WIDTH + 8.0, TANK_HEIGHT + 8.0)
		draw_rect(hover_rect, Color(1.0, 0.95, 0.2, 0.9), false, 2.5)

	draw_rect(body_rect, Color(0.20, 0.22, 0.26, 1.0))
	draw_rect(body_rect.grow(-2.0), Color(0.28, 0.30, 0.34, 1.0), false, 2.0)
	draw_rect(cap_rect, Color(0.22, 0.24, 0.28, 1.0))
	draw_rect(cap_rect.grow(-1.0), Color(0.32, 0.34, 0.38, 1.0), false, 2.0)

	var fluid_color := _fluid_color()
	draw_rect(fluid_rect, fluid_color)
	draw_rect(fluid_rect.grow(-2.0), Color(fluid_color.r + 0.1, fluid_color.g + 0.1, fluid_color.b + 0.1, 0.45), false, 2.0)

	for i in 3:
		var y := fluid_rect.position.y + (float(i) + 1.0) * fluid_rect.size.y / 4.0
		draw_line(
			Vector2(fluid_rect.position.x + 5.0, y),
			Vector2(fluid_rect.position.x + fluid_rect.size.x - 5.0, y),
			Color(1.0, 1.0, 1.0, 0.16),
			1.5
		)

	if is_selected:
		var arrow_y := top - 6.0
		var pts := PackedVector2Array([
			Vector2(cx, arrow_y),
			Vector2(cx - 7.0, arrow_y - 10.0),
			Vector2(cx + 7.0, arrow_y - 10.0),
		])
		draw_colored_polygon(pts, Color(0.95, 0.15, 0.15))


func _fluid_color() -> Color:
	match element:
		WeaponData.ThrowerElement.ACID:
			return Color(0.23, 0.74, 0.27, 0.90)
		WeaponData.ThrowerElement.CRYOGENICS:
			return Color(0.30, 0.70, 0.98, 0.90)
		_:
			return Color(0.95, 0.52, 0.16, 0.90)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tank_clicked.emit(element)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		queue_redraw()
