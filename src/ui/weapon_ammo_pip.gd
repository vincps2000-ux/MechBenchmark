# weapon_ammo_pip.gd — Tiny weapon ammo icon renderer for HUD ammo strips.
# Styles:
# - shell: autocannon selector-style shell (HE/Solid/Canister tip)
# - casing: very small machinegun casing
# - rocket: small missile icon
# - thrower: small element vial (fuel/acid/cryo)
class_name WeaponAmmoPip
extends Control

const STYLE_SHELL   := "shell"
const STYLE_CASING  := "casing"
const STYLE_ROCKET  := "rocket"
const STYLE_THROWER := "thrower"

var style: String = STYLE_SHELL
var ammo_type: WeaponData.AmmoType = WeaponData.AmmoType.HE
var thrower_element: WeaponData.ThrowerElement = WeaponData.ThrowerElement.FUEL
var fill_ratio: float = 1.0  # 1 = fully bright, 0 = fully dark

func configure(icon_style: String, atype: WeaponData.AmmoType, telement: WeaponData.ThrowerElement) -> void:
	style = icon_style
	ammo_type = atype
	thrower_element = telement
	match style:
		STYLE_CASING:
			custom_minimum_size = Vector2(2, 6)
		STYLE_ROCKET:
			custom_minimum_size = Vector2(5, 11)
		STYLE_THROWER:
			custom_minimum_size = Vector2(5, 12)
		_:
			custom_minimum_size = Vector2(5, 13)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_fill_ratio(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(fill_ratio, clamped):
		return
	fill_ratio = clamped
	queue_redraw()

func _draw() -> void:
	match style:
		STYLE_CASING:
			_draw_casing()
		STYLE_ROCKET:
			_draw_rocket()
		STYLE_THROWER:
			_draw_thrower()
		_:
			_draw_shell()

func _apply_fill(bright: Color, dark: Color) -> Color:
	return dark.lerp(bright, fill_ratio)

func _shell_tip_color(alpha: float) -> Color:
	match ammo_type:
		WeaponData.AmmoType.SOLID:
			return Color(0.35, 0.30, 0.22, alpha)
		WeaponData.AmmoType.CANISTER:
			return Color(0.25, 0.50, 0.88, alpha)
		_:
			return Color(0.88, 0.18, 0.12, alpha)

func _thrower_color(alpha: float) -> Color:
	match thrower_element:
		WeaponData.ThrowerElement.ACID:
			return Color(0.32, 0.88, 0.28, alpha)
		WeaponData.ThrowerElement.CRYOGENICS:
			return Color(0.30, 0.74, 0.98, alpha)
		_:
			return Color(0.98, 0.58, 0.20, alpha)

func _draw_shell() -> void:
	var w := size.x
	var h := size.y
	var casing_h := h * 0.55
	var tip_h := h - casing_h

	var brass := _apply_fill(Color(0.75, 0.60, 0.25, 0.96), Color(0.18, 0.16, 0.14, 0.92))
	var brass_rim := _apply_fill(Color(0.55, 0.42, 0.18, 0.96), Color(0.14, 0.13, 0.12, 0.92))
	var tip := _apply_fill(_shell_tip_color(0.96), Color(0.12, 0.12, 0.12, 0.92))

	draw_rect(Rect2(0, tip_h, w, casing_h), brass)
	draw_rect(Rect2(-1, tip_h + casing_h - 3, w + 2, 3), brass_rim)
	draw_rect(Rect2(0, 0, w, tip_h), tip)

func _draw_casing() -> void:
	var w := size.x
	var h := size.y
	var body := _apply_fill(Color(0.76, 0.64, 0.30, 0.96), Color(0.14, 0.13, 0.12, 0.92))
	var rim := _apply_fill(Color(0.55, 0.44, 0.20, 0.96), Color(0.10, 0.10, 0.10, 0.92))
	draw_rect(Rect2(0, 0, w, h), body)
	draw_rect(Rect2(-1, h - 2, w + 2, 2), rim)

func _draw_rocket() -> void:
	var w := size.x
	var h := size.y
	var nose_h := 4.0
	var body_h := h - nose_h - 2.0

	var body := _apply_fill(Color(0.72, 0.76, 0.82, 0.96), Color(0.14, 0.14, 0.16, 0.92))
	var nose := _apply_fill(Color(0.92, 0.26, 0.20, 0.96), Color(0.18, 0.14, 0.14, 0.92))
	var fin := _apply_fill(Color(0.48, 0.52, 0.58, 0.96), Color(0.10, 0.10, 0.10, 0.92))

	draw_rect(Rect2(1, nose_h, w - 2, body_h), body)
	draw_polygon(PackedVector2Array([
		Vector2(w * 0.5, 0),
		Vector2(1, nose_h),
		Vector2(w - 1, nose_h),
	]), PackedColorArray([nose]))
	draw_rect(Rect2(0, h - 2, 2, 2), fin)
	draw_rect(Rect2(w - 2, h - 2, 2, 2), fin)

func _draw_thrower() -> void:
	var w := size.x
	var h := size.y
	var cap_h := 3.0
	var body_h := h - cap_h

	var cap := _apply_fill(Color(0.62, 0.62, 0.66, 0.96), Color(0.14, 0.14, 0.14, 0.92))
	var fluid := _apply_fill(_thrower_color(0.96), Color(0.12, 0.12, 0.12, 0.92))

	draw_rect(Rect2(1, 0, w - 2, cap_h), cap)
	draw_rect(Rect2(0, cap_h, w, body_h), fluid)
