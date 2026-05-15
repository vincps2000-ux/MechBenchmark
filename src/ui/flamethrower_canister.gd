# flamethrower_canister.gd — Single canister ammo display with horizontal fill bar for flamethrower.
# Shows a visual canister with a horizontal bar that fills as ammo is consumed.
class_name FlamethrowerCanister
extends Control

const CANISTER_WIDTH := 86.0
const CANISTER_HEIGHT := 28.0
const BAR_HEIGHT := 8.0
const BAR_MARGIN := 6.0

var thrower_element: WeaponData.ThrowerElement = WeaponData.ThrowerElement.FUEL
var fill_ratio: float = 1.0  # 1 = full, 0 = empty

func _init() -> void:
	custom_minimum_size = Vector2(CANISTER_WIDTH + 14.0, CANISTER_HEIGHT + 10.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(telement: WeaponData.ThrowerElement) -> void:
	thrower_element = telement
	queue_redraw()


func set_fill_ratio(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(fill_ratio, clamped):
		return
	fill_ratio = clamped
	queue_redraw()


func _draw() -> void:
	var left := (size.x - CANISTER_WIDTH) * 0.5
	var top := (size.y - CANISTER_HEIGHT) * 0.5

	# Horizontal canister silhouette.
	var body_rect := Rect2(left, top, CANISTER_WIDTH - 10.0, CANISTER_HEIGHT)
	var cap_rect := Rect2(body_rect.end.x - 1.0, top + 7.0, 8.0, CANISTER_HEIGHT - 14.0)
	var nozzle_rect := Rect2(cap_rect.end.x - 1.0, top + 10.0, 7.0, CANISTER_HEIGHT - 20.0)
	var left_rim_rect := Rect2(left - 4.0, top + 6.0, 4.0, CANISTER_HEIGHT - 12.0)

	# Draw body and side hardware.
	draw_rect(body_rect, Color(0.20, 0.22, 0.26, 1.0))
	draw_rect(body_rect.grow(-2.0), Color(0.30, 0.33, 0.38, 1.0), false, 2.0)
	draw_rect(left_rim_rect, Color(0.24, 0.27, 0.31, 1.0))
	draw_rect(cap_rect, Color(0.34, 0.37, 0.42, 1.0))
	draw_rect(nozzle_rect, Color(0.42, 0.45, 0.50, 1.0))

	# Draw horizontal fill bar inside the sideways body.
	var bar_y := body_rect.position.y + body_rect.size.y * 0.5 - BAR_HEIGHT * 0.5
	var bar_bg_rect := Rect2(
		body_rect.position.x + BAR_MARGIN,
		bar_y,
		body_rect.size.x - BAR_MARGIN * 2.0 - 3.0,
		BAR_HEIGHT
	)
	
	# Background (empty bar)
	draw_rect(bar_bg_rect, Color(0.12, 0.12, 0.14, 0.9))
	draw_rect(bar_bg_rect.grow(-1.0), Color(0.18, 0.18, 0.20, 0.8), false, 1.0)
	
	# Filled portion
	var fill_width := bar_bg_rect.size.x * fill_ratio
	if fill_width > 0.01:
		var fill_rect := Rect2(
			bar_bg_rect.position.x,
			bar_bg_rect.position.y,
			fill_width,
			bar_bg_rect.size.y
		)
		var fill_color := _fluid_color()
		draw_rect(fill_rect, fill_color)

func _fluid_color() -> Color:
	match thrower_element:
		WeaponData.ThrowerElement.ACID:
			return Color(0.23, 0.74, 0.27, 0.95)
		WeaponData.ThrowerElement.CRYOGENICS:
			return Color(0.30, 0.70, 0.98, 0.95)
		_:
			return Color(0.95, 0.52, 0.16, 0.95)
