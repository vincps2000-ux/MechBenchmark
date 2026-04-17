# drag_part_card.gd — Draggable card for the workshop parts catalog.
# Displays a mech part's name and stats; supports Godot's built-in drag-and-drop.
class_name DragPartCard
extends PanelContainer

signal modify_pressed(data: Variant)

## The part resource (LegData / TorsoData / WeaponData).
var part_data = null
## Category key used by drop-zone matching: "legs", "torso", or "weapon".
var part_type: String = ""
## Index in the catalog array.
var catalog_index: int = -1


func setup(data: Variant, type: String, index: int) -> void:
	part_data = data
	part_type = type
	catalog_index = index

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = data.name
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	if type == "weapon" or type == "light_weapon":
		var modify_btn := Button.new()
		modify_btn.text = "⚙"
		modify_btn.add_theme_font_size_override("font_size", 14)
		modify_btn.custom_minimum_size = Vector2(28, 28)
		modify_btn.tooltip_text = "Modify " + data.name
		var gun := data as WeaponData
		if gun.weapon_type not in [WeaponData.WeaponType.AUTOCANNON, WeaponData.WeaponType.ROCKET_POD]:
			modify_btn.disabled = true
			modify_btn.tooltip_text = "No modifications available"
		modify_btn.pressed.connect(func(): modify_pressed.emit(part_data))
		title_row.add_child(modify_btn)

	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match type:
		"weapon":
			var gun := data as WeaponData
			desc.text = "DMG %d  ·  CD %.1fs  ·  Pierce %d" % [
				gun.damage, gun.cooldown, gun.pierce]
		"light_weapon":
			var gun := data as WeaponData
			desc.text = "DMG %d  ·  CD %.1fs  ·  Light  ·  Pierce %d" % [
				gun.damage, gun.cooldown, gun.pierce]
		"torso":
			var torso := data as TorsoData
			var slots_desc := "%d wpn slot%s" % [torso.weapon_slots, "s" if torso.weapon_slots > 1 else ""]
			if torso.light_weapon_slots > 0:
				slots_desc += " + %d light" % torso.light_weapon_slots
			desc.text = "HP %d  ·  %s  ·  Speed ×%.1f" % [
				torso.integrity, slots_desc, torso.speed_modifier]
		"legs":
			var leg := data as LegData
			var slots_info := "  ·  %d torso slots" % leg.torso_slots if leg.torso_slots > 1 else ""
			desc.text = "Speed ×%.1f%s" % [leg.speed_modifier, slots_info]
		_:
			var txt: String = data.tutorial_text if data.tutorial_text else data.description
			desc.text = txt.split("\n")[0] if "\n" in txt else txt
	vbox.add_child(desc)

	custom_minimum_size = Vector2(0, 52)
	mouse_filter = MOUSE_FILTER_STOP
	set_selected(false)


## Highlight or un-highlight this card.
func set_selected(on: bool) -> void:
	var s := StyleBoxFlat.new()
	if on:
		s.bg_color = Color(0.22, 0.16, 0.08, 0.95)
		s.set_border_width_all(2)
		s.border_color = Color(0.95, 0.7, 0.2, 1.0)
		s.shadow_color = Color(0.95, 0.7, 0.2, 0.25)
		s.shadow_size = 4
	else:
		s.bg_color = Color(0.12, 0.1, 0.15, 0.85)
		s.set_border_width_all(1)
		s.border_color = Color(0.35, 0.3, 0.25, 0.5)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	add_theme_stylebox_override("panel", s)


# ── Drag support ──────────────────────────────────────────────────────────────

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := PanelContainer.new()
	var lbl := Label.new()
	lbl.text = "  " + part_data.name + "  "
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	preview.add_child(lbl)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.12, 0.1, 0.95)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.95, 0.7, 0.2, 0.9)
	ps.set_corner_radius_all(6)
	ps.set_content_margin_all(6)
	preview.add_theme_stylebox_override("panel", ps)
	set_drag_preview(preview)
	return {"type": part_type, "data": part_data, "index": catalog_index}
