# ammo_shell_pip.gd — Tiny shell icon used as an ammo pip in the weapon HUD.
# Mirrors the AmmoShell drawing style but scaled to fit inline in the HUD row.
# HE: brass casing + red tip
# Solid: brass casing + dark pointed tip
# Canister: brass casing + boxy blue tip
class_name AmmoShellPip
extends Control

const PIP_W        := 5.0
const PIP_H        := 13.0
const CASING_RATIO := 0.55

var ammo_type: WeaponData.AmmoType = WeaponData.AmmoType.HE
var depleted: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(PIP_W, PIP_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_depleted(d: bool) -> void:
	if depleted != d:
		depleted = d
		queue_redraw()

func _draw() -> void:
	var casing_h := PIP_H * CASING_RATIO
	var tip_h    := PIP_H * (1.0 - CASING_RATIO)
	var alpha    := 0.18 if depleted else 0.95

	# Brass casing
	draw_rect(Rect2(0, tip_h, PIP_W, casing_h), Color(0.75, 0.60, 0.25, alpha))
	# Bottom rim
	draw_rect(Rect2(-1, tip_h + casing_h - 3, PIP_W + 2, 3), Color(0.55, 0.42, 0.18, alpha))

	# Tip colour by ammo type
	var tip_color: Color
	match ammo_type:
		WeaponData.AmmoType.SOLID:
			tip_color = Color(0.35, 0.30, 0.22, alpha)
		WeaponData.AmmoType.CANISTER:
			tip_color = Color(0.25, 0.50, 0.88, alpha)
		_:  # HE default
			tip_color = Color(0.88, 0.18, 0.12, alpha)
	draw_rect(Rect2(0, 0, PIP_W, tip_h), tip_color)
