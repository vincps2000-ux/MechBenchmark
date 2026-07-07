# drag_part_card.gd — Draggable card for the workshop parts catalog.
# Shows the part's sprite as a thumbnail; the drag ghost is the actual sprite.
# Double-click emits quick_equip for one-click equipping into the next free slot.
class_name DragPartCard
extends PanelContainer

signal modify_pressed(data: Variant)
signal wiki_pressed(data: Variant, part_type: String)
signal quick_equip(data: Variant, part_type: String)

const _DRAG_GHOST_SIZE := 96.0

## The part resource (LegData / TorsoData / WeaponData).
var part_data = null
## Category key used by drop-zone matching: "legs", "torso", or "weapon".
var part_type: String = ""
## Index in the catalog array.
var catalog_index: int = -1

var _selected := false
var _hovered  := false
var _part_texture: Texture2D = null


func setup(data: Variant, type: String, index: int) -> void:
	part_data = data
	part_type = type
	catalog_index = index

	if data.has_method("get_sprite_path"):
		var path: String = data.get_sprite_path()
		if ResourceLoader.exists(path):
			_part_texture = load(path)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	# ── Sprite thumbnail ──────────────────────────────────────────────────
	var thumb_frame := PanelContainer.new()
	thumb_frame.custom_minimum_size = Vector2(56, 56)
	thumb_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_frame.mouse_filter = MOUSE_FILTER_IGNORE
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	ts.set_border_width_all(1)
	ts.border_color = Color(0.3, 0.4, 0.42, 0.5)
	ts.set_corner_radius_all(8)
	ts.set_content_margin_all(4)
	thumb_frame.add_theme_stylebox_override("panel", ts)
	row.add_child(thumb_frame)

	var thumb := TextureRect.new()
	thumb.texture = _part_texture
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	thumb.mouse_filter = MOUSE_FILTER_IGNORE
	thumb_frame.add_child(thumb)

	# ── Name + stats ──────────────────────────────────────────────────────
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(info)

	var title := Label.new()
	title.text = data.name
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.mouse_filter = MOUSE_FILTER_IGNORE
	info.add_child(title)

	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.62, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = MOUSE_FILTER_IGNORE
	desc.text = _stats_text(data, type)
	info.add_child(desc)

	# ── Action buttons ────────────────────────────────────────────────────
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(actions)

	var wiki_btn := _make_action_button("i", "Open wiki for " + data.name)
	wiki_btn.pressed.connect(func(): wiki_pressed.emit(part_data, part_type))
	actions.add_child(wiki_btn)

	if type == "weapon" or type == "light_weapon":
		var modify_btn := _make_action_button("⚙", "Modify " + data.name)
		modify_btn.pressed.connect(func(): modify_pressed.emit(part_data))
		actions.add_child(modify_btn)

	custom_minimum_size = Vector2(0, 68)
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag onto the mech — or double-click to equip"
	mouse_entered.connect(func():
		_hovered = true
		_apply_style()
	)
	mouse_exited.connect(func():
		_hovered = false
		_apply_style()
	)
	_apply_style()


static func _stats_text(data: Variant, type: String) -> String:
	match type:
		"weapon":
			var gun := data as WeaponData
			return "DMG %d  ·  CD %.1fs  ·  Pierce %d" % [
				gun.damage, gun.cooldown, gun.pierce]
		"light_weapon":
			var gun := data as WeaponData
			return "DMG %d  ·  CD %.1fs  ·  Light  ·  Pierce %d" % [
				gun.damage, gun.cooldown, gun.pierce]
		"torso":
			var torso := data as TorsoData
			var slots_desc := "%d wpn slot%s" % [torso.weapon_slots, "s" if torso.weapon_slots > 1 else ""]
			if torso.light_weapon_slots > 0:
				slots_desc += " + %d light" % torso.light_weapon_slots
			return "Structure 30  ·  %s  ·  Speed x%.1f" % [
				slots_desc, torso.speed_modifier]
		"legs":
			var leg := data as LegData
			var slots_info := "  ·  %d torso slots" % leg.torso_slots if leg.torso_slots > 1 else ""
			return "Speed ×%.1f%s" % [leg.speed_modifier, slots_info]
	var txt: String = data.tutorial_text if data.tutorial_text else data.description
	return txt.split("\n")[0] if "\n" in txt else txt


static func _make_action_button(text: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(26, 26)
	btn.tooltip_text = tooltip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.2, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.45, 0.55, 0.6, 0.5)
	sb.set_corner_radius_all(13)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.28, 0.32, 0.4, 0.9)
	sb_hover.border_color = Color(0.7, 0.85, 0.95, 0.9)
	btn.add_theme_stylebox_override("hover", sb_hover)
	return btn


## Highlight or un-highlight this card.
func set_selected(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	_apply_style()


func _apply_style() -> void:
	var s := StyleBoxFlat.new()
	if _selected:
		s.bg_color = Color(0.22, 0.16, 0.08, 0.95)
		s.set_border_width_all(2)
		s.border_color = Color(0.95, 0.7, 0.2, 1.0)
		s.shadow_color = Color(0.95, 0.7, 0.2, 0.25)
		s.shadow_size = 6
	elif _hovered:
		s.bg_color = Color(0.16, 0.19, 0.24, 0.95)
		s.set_border_width_all(1)
		s.border_color = Color(0.4, 0.75, 0.75, 0.9)
		s.shadow_color = Color(0.2, 0.6, 0.6, 0.2)
		s.shadow_size = 5
	else:
		s.bg_color = Color(0.1, 0.11, 0.15, 0.85)
		s.set_border_width_all(1)
		s.border_color = Color(0.32, 0.35, 0.4, 0.45)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(8)
	add_theme_stylebox_override("panel", s)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and event.double_click:
		quick_equip.emit(part_data, part_type)
		accept_event()


# ── Drag support ──────────────────────────────────────────────────────────────

func _get_drag_data(_at_position: Vector2) -> Variant:
	set_drag_preview(_build_drag_ghost())
	return {"type": part_type, "data": part_data, "index": catalog_index}


## Builds a ghost of the part sprite centered on the cursor, with a name tag.
func _build_drag_ghost() -> Control:
	var root := Control.new()
	root.mouse_filter = MOUSE_FILTER_IGNORE

	if _part_texture:
		var sz := Vector2(_DRAG_GHOST_SIZE, _DRAG_GHOST_SIZE)
		var ghost := TextureRect.new()
		ghost.texture = _part_texture
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		ghost.size = sz
		ghost.position = -sz * 0.5
		ghost.modulate = Color(1, 1, 1, 0.8)
		root.add_child(ghost)

	var tag := PanelContainer.new()
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	tag_style.set_border_width_all(1)
	tag_style.border_color = Color(0.95, 0.7, 0.2, 0.9)
	tag_style.set_corner_radius_all(6)
	tag_style.set_content_margin_all(4)
	tag.add_theme_stylebox_override("panel", tag_style)
	var lbl := Label.new()
	lbl.text = " %s " % part_data.name
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	tag.add_child(lbl)
	root.add_child(tag)
	# Position the tag below the sprite (or on the cursor when no sprite).
	var tag_y := _DRAG_GHOST_SIZE * 0.5 + 6 if _part_texture else -14.0
	tag.position = Vector2(0, tag_y)
	tag.reset_size()
	tag.position.x = -tag.size.x * 0.5

	return root
