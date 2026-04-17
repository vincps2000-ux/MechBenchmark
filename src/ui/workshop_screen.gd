# workshop_screen.gd — Drag-and-drop Workshop.
# All parts are displayed in a scrollable catalog on the left.
# The right panel shows the mech preview with drop zones at mount points.
# Drag a part from the catalog onto the matching slot to equip it.
# Slot capacity is MODULAR: legs define torso_slots, torsos define weapon_slots.
extends Control

signal deploy_pressed(loadout: MechLoadout)

# ── Node refs (from scene) ────────────────────────────────────────────────────
@onready var _step_label:     Label            = %StepLabel
@onready var _parts_label:    Label            = %PartsLabel
@onready var _parts_scroll:   ScrollContainer  = %PartsScroll
@onready var _parts_box:      VBoxContainer     = %PartsBox
@onready var _slot_hint:      Label            = %SlotHint
@onready var _preview_stack:  Control           = %PreviewStack
@onready var _selection_info: Label            = %SelectionInfo
@onready var _stats_label:    Label            = %StatsLabel
@onready var _deploy_button:  Button           = %DeployButton
@onready var _left_arrow:     Button           = %LeftArrow
@onready var _right_arrow:    Button           = %RightArrow
@onready var _step_indicator: Label            = %StepIndicator

# ── State ─────────────────────────────────────────────────────────────────────
var _loadout := MechLoadout.new()
var _all_legs:   Array[LegData]    = []
var _all_torsos: Array[TorsoData]  = []
var _all_guns:   Array[WeaponData] = []
var _all_light_guns: Array[WeaponData] = []

# ── Preview texture layers ────────────────────────────────────────────────────
var _legs_rect:     TextureRect = null
var _torso_rects:   Array[TextureRect] = []
var _weapon_rects:  Array[TextureRect] = []
var _light_weapon_rects: Array[TextureRect] = []

# ── Drop zones ────────────────────────────────────────────────────────────────
var _legs_zone:     PartDropZone = null
var _torso_zones:   Array[PartDropZone] = []
var _weapon_zones:  Array[PartDropZone] = []
var _light_weapon_zones: Array[PartDropZone] = []

# ── Catalog cards (for selection highlighting) ────────────────────────────────
var _leg_cards:    Array[DragPartCard] = []
var _torso_cards:  Array[DragPartCard] = []
var _weapon_cards: Array[DragPartCard] = []
var _light_weapon_cards: Array[DragPartCard] = []

# ── Modify modal ──────────────────────────────────────────────────────────────
var _modal_overlay: ColorRect = null
var _modal_panel:   PanelContainer = null
var _sub_modal_overlay: ColorRect = null
var _sub_modal_panel:   PanelContainer = null
var _sub_modal_open_frame: int = -1

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_all_legs   = MechCatalog.get_all_legs()
	_all_torsos = MechCatalog.get_all_torsos()
	_all_guns   = MechCatalog.get_all_guns()
	_all_light_guns = MechCatalog.get_all_light_guns()

	# Hide step-navigation elements (no longer needed for drag-and-drop)
	_left_arrow.visible     = false
	_right_arrow.visible    = false
	_step_indicator.visible = false
	_slot_hint.visible      = false
	_parts_scroll.visible   = true

	# Repurpose left arrow as UNDO button; hide other step-nav elements
	_right_arrow.visible = false
	_step_indicator.visible = false
	_left_arrow.visible = false
	_left_arrow.pressed.connect(_on_undo_pressed)

	_step_label.text     = "DRAG PARTS ONTO THE MECH"
	_selection_info.text = "Drag a part from the catalog and drop it on a slot"

	_build_parts_catalog()
	_build_preview_layers()
	_build_drop_zones()

	_deploy_button.pressed.connect(_on_deploy_pressed)
	_deploy_button.disabled = true
	_deploy_button.visible  = true

	_build_modify_modal()
	_build_sub_modal()
	_update_stats_preview()

# ── Parts catalog (left panel) ────────────────────────────────────────────────

func _build_parts_catalog() -> void:
	for child in _parts_box.get_children():
		child.queue_free()
	_parts_label.text = "PARTS CATALOG"
	_leg_cards.clear()
	_torso_cards.clear()
	_weapon_cards.clear()
	_light_weapon_cards.clear()

	_add_section_header("── MOVEMENT ──")
	for i in _all_legs.size():
		var card := DragPartCard.new()
		card.setup(_all_legs[i], "legs", i)
		_parts_box.add_child(card)
		_leg_cards.append(card)

	_add_section_header("── TORSO ──")
	for i in _all_torsos.size():
		var card := DragPartCard.new()
		card.setup(_all_torsos[i], "torso", i)
		_parts_box.add_child(card)
		_torso_cards.append(card)

	_add_section_header("── WEAPONS ──")
	for i in _all_guns.size():
		var card := DragPartCard.new()
		card.setup(_all_guns[i], "weapon", i)
		card.modify_pressed.connect(_on_modify_weapon)
		_parts_box.add_child(card)
		_weapon_cards.append(card)

	_add_section_header("── LIGHT WEAPONS ──")
	for i in _all_light_guns.size():
		var card := DragPartCard.new()
		card.setup(_all_light_guns[i], "light_weapon", i)
		card.modify_pressed.connect(_on_modify_weapon)
		_parts_box.add_child(card)
		_light_weapon_cards.append(card)


func _add_section_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.75, 0.65))
	lbl.custom_minimum_size = Vector2(0, 30)
	_parts_box.add_child(lbl)

# ── Preview sprite layers ────────────────────────────────────────────────────

func _build_preview_layers() -> void:
	_legs_rect = _make_preview_rect()
	_preview_stack.add_child(_legs_rect)
	_legs_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_legs_rect.modulate.a = 0.0
	# Torso/weapon rects are created dynamically in _rebuild_torso_zones / _rebuild_weapon_zones


func _make_preview_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _update_preview_layer(rect: TextureRect, path: String) -> void:
	var tex: Texture2D = load(path)
	if tex:
		rect.texture    = tex
		rect.modulate.a = 1.0
	else:
		rect.modulate.a = 0.0

# ── Drop zones on mech preview ───────────────────────────────────────────────

func _build_drop_zones() -> void:
	var pw := _preview_stack.custom_minimum_size.x  # 220
	var ph := _preview_stack.custom_minimum_size.y  # 220

	# Legs zone — always visible at the bottom of the mech
	_legs_zone = PartDropZone.new()
	_legs_zone.setup("legs", "LEGS", Vector2(150, 42))
	_preview_stack.add_child(_legs_zone)
	_legs_zone.position = Vector2((pw - 150) * 0.5, ph - 48)
	_legs_zone.part_equipped.connect(_on_legs_equipped)

	# Torso and weapon zones only appear once their prerequisite part is equipped

# ── Torso zones (driven by LegData.torso_slots) ─────────────────────────────

func _rebuild_torso_zones() -> void:
	for zone in _torso_zones:
		zone.queue_free()
	_torso_zones.clear()
	for rect in _torso_rects:
		rect.queue_free()
	_torso_rects.clear()

	_loadout.selected_torsos.clear()
	_loadout.selected_torso = null

	# Don't show torso zones until legs are equipped
	if _loadout.selected_legs == null:
		_rebuild_weapon_zones()
		return

	var slot_count: int = _loadout.selected_legs.torso_slots
	var pw := _preview_stack.custom_minimum_size.x
	var zone_w := 130 if slot_count > 1 else 150
	var spacing := 10

	for i in slot_count:
		# Preview rect
		var rect := _make_preview_rect()
		_preview_stack.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.modulate.a = 0.0
		_torso_rects.append(rect)

		# Drop zone
		var label := "TORSO %d" % (i + 1) if slot_count > 1 else "TORSO"
		var zone := PartDropZone.new()
		zone.setup("torso", label, Vector2(zone_w, 42), i)
		_preview_stack.add_child(zone)

		if slot_count == 1:
			zone.position = Vector2((pw - zone_w) * 0.5, 6)
		else:
			var total_w: float = slot_count * zone_w + (slot_count - 1) * spacing
			var start_x: float = (pw - total_w) * 0.5
			zone.position = Vector2(start_x + i * (zone_w + spacing), 6)

		zone.part_equipped.connect(_on_torso_equipped.bind(i))
		_torso_zones.append(zone)

	_rebuild_weapon_zones()

# ── Weapon zones (driven by total weapon_slots across all equipped torsos) ───

func _rebuild_weapon_zones() -> void:
	for zone in _weapon_zones:
		zone.queue_free()
	_weapon_zones.clear()
	for rect in _weapon_rects:
		rect.queue_free()
	_weapon_rects.clear()

	_loadout.selected_guns.clear()

	# Also clear light weapon zones
	for zone in _light_weapon_zones:
		zone.queue_free()
	_light_weapon_zones.clear()
	for rect in _light_weapon_rects:
		rect.queue_free()
	_light_weapon_rects.clear()
	_loadout.selected_light_guns.clear()

	# Don't show weapon zones until at least one torso is equipped
	var has_torso := false
	for torso in _loadout.selected_torsos:
		if torso:
			has_torso = true
			break
	if not has_torso and _loadout.selected_torso != null:
		has_torso = true
	if not has_torso:
		return

	# Gather weapon mount offsets from all equipped torsos (via MechAssembler)
	var raw_offsets: Array[Vector2] = []
	for torso in _loadout.selected_torsos:
		if torso:
			raw_offsets.append_array(MechAssembler.get_weapon_offsets(torso.torso_type))
	if raw_offsets.is_empty() and _loadout.selected_torso:
		raw_offsets = MechAssembler.get_weapon_offsets(_loadout.selected_torso.torso_type)

	var slot_count: int = raw_offsets.size()
	if slot_count == 0:
		slot_count = 1
		raw_offsets.append(Vector2.ZERO)

	var pw := _preview_stack.custom_minimum_size.x   # 220
	var ph := _preview_stack.custom_minimum_size.y   # 220
	var center := Vector2(pw * 0.5, ph * 0.5)

	# Scale offsets from game pixels (64px torso) to preview pixels (220px)
	var scaled: Array[Vector2] = MechAssembler.scale_offsets(raw_offsets, pw)
	# Proportional weapon rect size (48/64 of container)
	var wpn_sz := MechAssembler.weapon_rect_size(pw)

	for i in slot_count:
		var mount_offset := scaled[i] if i < scaled.size() else Vector2.ZERO
		var mount_center := center + mount_offset

		# Weapon preview TextureRect — sized proportionally, centered on mount
		var rect := _make_preview_rect()
		_preview_stack.add_child(rect)
		var sz := Vector2(wpn_sz, wpn_sz)
		rect.custom_minimum_size = sz
		rect.size = sz
		rect.position = mount_center - sz * 0.5
		rect.pivot_offset = sz * 0.5   # rotate around own center
		rect.modulate.a = 0.0
		_weapon_rects.append(rect)

		# Drop zone — centered on the same mount point
		var label := "WPN %d" % (i + 1) if slot_count > 1 else "WEAPON"
		var zone_w := 90 if slot_count > 1 else 100
		var zone_h := 40
		var zone := PartDropZone.new()
		zone.setup("weapon", label, Vector2(zone_w, zone_h), i)
		_preview_stack.add_child(zone)
		zone.position = mount_center - Vector2(zone_w * 0.5, zone_h * 0.5)
		zone.part_equipped.connect(_on_weapon_equipped.bind(i))
		_weapon_zones.append(zone)

	# ── Light weapon zones ────────────────────────────────────────────────
	var light_offsets: Array[Vector2] = []
	for torso in _loadout.selected_torsos:
		if torso:
			light_offsets.append_array(MechAssembler.get_light_weapon_offsets(torso.torso_type))
	if light_offsets.is_empty() and _loadout.selected_torso:
		light_offsets = MechAssembler.get_light_weapon_offsets(_loadout.selected_torso.torso_type)

	if light_offsets.size() > 0:
		var light_scaled: Array[Vector2] = MechAssembler.scale_offsets(light_offsets, pw)
		var light_sz := MechAssembler.light_weapon_rect_size(pw)

		for i in light_offsets.size():
			var mount_offset := light_scaled[i]
			var mount_center := center + mount_offset

			var rect := _make_preview_rect()
			_preview_stack.add_child(rect)
			var sz := Vector2(light_sz, light_sz)
			rect.custom_minimum_size = sz
			rect.size = sz
			rect.position = mount_center - sz * 0.5
			rect.pivot_offset = sz * 0.5
			rect.modulate.a = 0.0
			_light_weapon_rects.append(rect)

			var label := "S.WPN %d" % (i + 1) if light_offsets.size() > 1 else "S.WPN"
			var zone_w2 := 72
			var zone_h2 := 32
			var zone := PartDropZone.new()
			zone.setup("light_weapon", label, Vector2(zone_w2, zone_h2), i)
			_preview_stack.add_child(zone)
			zone.position = mount_center - Vector2(zone_w2 * 0.5, zone_h2 * 0.5)
			zone.part_equipped.connect(_on_light_weapon_equipped.bind(i))
			_light_weapon_zones.append(zone)

# ── Equip handlers ────────────────────────────────────────────────────────────

func _on_legs_equipped(data: Variant) -> void:
	_loadout.selected_legs = data as LegData
	_update_preview_layer(_legs_rect, _loadout.selected_legs.get_sprite_path())
	_legs_zone.visible = false
	_rebuild_torso_zones()
	_refresh_ui()


func _on_torso_equipped(data: Variant, slot: int) -> void:
	var torso := data as TorsoData
	while _loadout.selected_torsos.size() <= slot:
		_loadout.selected_torsos.append(null)
	_loadout.selected_torsos[slot] = torso

	# Keep legacy selected_torso in sync (primary = first)
	_loadout.selected_torso = _loadout.selected_torsos[0] if _loadout.selected_torsos.size() > 0 else null

	# Update preview sprite for this slot
	if slot < _torso_rects.size():
		_update_preview_layer(_torso_rects[slot], torso.get_sprite_path())
	if slot < _torso_zones.size():
		_torso_zones[slot].visible = false

	_rebuild_weapon_zones()
	_refresh_ui()


func _on_weapon_equipped(data: Variant, slot: int) -> void:
	while _loadout.selected_guns.size() <= slot:
		_loadout.selected_guns.append(null)
	# Duplicate so each slot has its own independent WeaponData copy
	_loadout.selected_guns[slot] = (data as WeaponData).duplicate()

	# Trim trailing nulls
	while _loadout.selected_guns.size() > 0 and _loadout.selected_guns.back() == null:
		_loadout.selected_guns.pop_back()

	# Update weapon preview sprite
	if slot < _weapon_rects.size():
		var gun := data as WeaponData
		_update_preview_layer(_weapon_rects[slot], gun.get_sprite_path())
		_weapon_rects[slot].rotation = _weapon_preview_rotation(gun)
	if slot < _weapon_zones.size():
		_weapon_zones[slot].visible = false

	_refresh_ui()


func _on_light_weapon_equipped(data: Variant, slot: int) -> void:
	while _loadout.selected_light_guns.size() <= slot:
		_loadout.selected_light_guns.append(null)
	_loadout.selected_light_guns[slot] = (data as WeaponData).duplicate()

	while _loadout.selected_light_guns.size() > 0 and _loadout.selected_light_guns.back() == null:
		_loadout.selected_light_guns.pop_back()

	if slot < _light_weapon_rects.size():
		var gun := data as WeaponData
		_update_preview_layer(_light_weapon_rects[slot], gun.get_sprite_path())
		_light_weapon_rects[slot].rotation = _weapon_preview_rotation(gun)
	if slot < _light_weapon_zones.size():
		_light_weapon_zones[slot].visible = false

	_refresh_ui()


## Returns the rotation correction for a weapon's workshop preview sprite.
## Weapons whose scene sprites are rotated -90° need the same correction here.
static func _weapon_preview_rotation(gun: WeaponData) -> float:
	match gun.weapon_type:
		WeaponData.WeaponType.AUTOCANNON, WeaponData.WeaponType.FLAMETHROWER, \
		WeaponData.WeaponType.ROCKET_POD, WeaponData.WeaponType.MACHINEGUN:
			return deg_to_rad(-90.0)
	return 0.0

# ── UI refresh ────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	_update_card_highlights()
	_deploy_button.disabled = not _loadout.is_valid()
	_update_info_text()
	_update_stats_preview()
	_update_undo_button()


func _update_card_highlights() -> void:
	for card in _leg_cards:
		card.set_selected(card.part_data == _loadout.selected_legs)
	for card in _torso_cards:
		var equipped := false
		for torso in _loadout.selected_torsos:
			if torso == card.part_data:
				equipped = true
				break
		if not equipped and card.part_data == _loadout.selected_torso:
			equipped = true
		card.set_selected(equipped)
	for card in _weapon_cards:
		var equipped := false
		for gun in _loadout.selected_guns:
			if gun and gun.name == card.part_data.name:
				equipped = true
				break
		card.set_selected(equipped)
	for card in _light_weapon_cards:
		var equipped := false
		for gun in _loadout.selected_light_guns:
			if gun and gun.name == card.part_data.name:
				equipped = true
				break
		card.set_selected(equipped)


func _update_info_text() -> void:
	var parts: Array[String] = []
	if _loadout.selected_legs:
		parts.append(_loadout.selected_legs.name)
	for torso in _loadout.selected_torsos:
		if torso:
			parts.append(torso.name)
	if parts.size() == 1 and _loadout.selected_torso and _loadout.selected_torsos.is_empty():
		parts.append(_loadout.selected_torso.name)
	for gun in _loadout.selected_guns:
		if gun:
			parts.append(gun.name)
	for gun in _loadout.selected_light_guns:
		if gun:
			parts.append(gun.name)
	if parts.is_empty():
		_selection_info.text = "Drag a part from the catalog and drop it on a slot"
	else:
		_selection_info.text = " + ".join(parts)


func _update_stats_preview() -> void:
	if not _stats_label:
		return
	if not _loadout.is_valid():
		var missing: Array[String] = []
		if _loadout.selected_legs  == null: missing.append("Legs")
		var has_torso: bool = _loadout.selected_torso != null or _loadout.selected_torsos.size() > 0
		if not has_torso: missing.append("Torso")
		if _loadout.selected_guns.size() == 0: missing.append("Weapon")
		_stats_label.text = "Still needed: " + "  ·  ".join(missing)
		return
	var preview_stats := PlayerStats.new()
	_loadout.apply_to_stats(preview_stats)
	var integrity_str := "◆".repeat(preview_stats.max_integrity)
	var weapon_names := ""
	var total_dmg := 0
	for gun in _loadout.selected_guns:
		if gun:
			if weapon_names.length() > 0:
				weapon_names += " + "
			weapon_names += gun.name
			total_dmg += gun.damage
	for gun in _loadout.selected_light_guns:
		if gun:
			if weapon_names.length() > 0:
				weapon_names += " + "
			weapon_names += gun.name
			total_dmg += gun.damage
	var torso_name := ""
	if _loadout.selected_torsos.size() > 0:
		var names: Array[String] = []
		for t in _loadout.selected_torsos:
			if t:
				names.append(t.name)
		torso_name = " + ".join(names)
	elif _loadout.selected_torso:
		torso_name = _loadout.selected_torso.name
	_stats_label.text = "%s  |  Speed: %.0f  |  %s  +  %s  +  %s  (DMG: %d)" % [
		integrity_str,
		preview_stats.speed,
		_loadout.selected_legs.name,
		torso_name,
		weapon_names,
		total_dmg,
	]

# ── Undo ──────────────────────────────────────────────────────────────────────

func _on_undo_pressed() -> void:
	if _loadout.selected_light_guns.size() > 0 or _loadout.selected_guns.size() > 0:
		_rebuild_weapon_zones()
	elif _has_any_torso():
		_rebuild_torso_zones()
	elif _loadout.selected_legs != null:
		_loadout.selected_legs = null
		_legs_rect.modulate.a = 0.0
		_legs_zone.clear()
		_legs_zone.visible = true
		_rebuild_torso_zones()
	_refresh_ui()


func _has_any_torso() -> bool:
	for t in _loadout.selected_torsos:
		if t:
			return true
	return _loadout.selected_torso != null


func _update_undo_button() -> void:
	_left_arrow.visible = _loadout.selected_legs != null

# ── Deploy ────────────────────────────────────────────────────────────────────

func _on_deploy_pressed() -> void:
	_deploy_button.disabled = true
	GameManager.current_loadout = _loadout
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(_go_to_game)


func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/software_screen.tscn")

# ── Modify modal ──────────────────────────────────────────────────────────────

func _build_modify_modal() -> void:
	# Dimmed overlay behind the panel
	_modal_overlay = ColorRect.new()
	_modal_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_overlay.visible = false
	_modal_overlay.gui_input.connect(_on_modal_overlay_input)
	add_child(_modal_overlay)

	# Center wrapper
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_overlay.add_child(center)

	# Panel
	_modal_panel = PanelContainer.new()
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_panel.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.97)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.95, 0.7, 0.2, 0.9)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(24)
	_modal_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_modal_panel)


## Weapon types that support the Modify button.
const _MODIFIABLE_TYPES := [
	WeaponData.WeaponType.AUTOCANNON,
	WeaponData.WeaponType.ROCKET_POD,
]

## Show the modification modal for the first equipped copy of this weapon.
func _on_modify_weapon(data: Variant) -> void:
	var catalog_gun := data as WeaponData
	if catalog_gun == null or catalog_gun.weapon_type not in _MODIFIABLE_TYPES:
		return
	# Find all equipped copies of this weapon type in the loadout
	var equipped_copies: Array[WeaponData] = []
	for gun in _loadout.selected_guns:
		if gun and gun.name == catalog_gun.name:
			equipped_copies.append(gun)
	for gun in _loadout.selected_light_guns:
		if gun and gun.name == catalog_gun.name:
			equipped_copies.append(gun)
	if equipped_copies.is_empty():
		return
	if equipped_copies.size() == 1:
		_show_modify_modal(equipped_copies[0])
	else:
		_show_slot_picker(equipped_copies)


func _show_slot_picker(guns: Array[WeaponData]) -> void:
	for child in _modal_panel.get_children():
		_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Which slot to modify?"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for i in guns.size():
		var gun := guns[i]
		var slot_idx := _loadout.selected_guns.find(gun)
		var ammo_label := _ammo_type_label(gun.ammo_type)
		var btn := Button.new()
		btn.text = "Slot %d  —  %s  (%s)" % [slot_idx + 1, gun.name, ammo_label]
		btn.custom_minimum_size = Vector2(300, 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(call_deferred.bind("_show_modify_modal", gun))
		vbox.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "CANCEL"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_hide_modify_modal)
	vbox.add_child(close_btn)

	_modal_overlay.visible = true


static func _ammo_type_label(ammo: WeaponData.AmmoType) -> String:
	match ammo:
		WeaponData.AmmoType.HE: return "HE"
		WeaponData.AmmoType.SOLID: return "Solid"
		WeaponData.AmmoType.CANISTER: return "Canister"
	return "Unknown"


func _show_modify_modal(gun: WeaponData) -> void:
	# Clear previous content immediately to avoid stale signal connections
	for child in _modal_panel.get_children():
		_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_modal_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⚙  MODIFY — %s" % gun.name
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.4, 0.35, 0.25, 0.5))
	vbox.add_child(sep)

	# Weapon-specific options
	match gun.weapon_type:
		WeaponData.WeaponType.AUTOCANNON:
			_add_autocannon_options(vbox, gun)
		WeaponData.WeaponType.ROCKET_POD:
			_add_rocket_pod_options(vbox, gun)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_hide_modify_modal)
	vbox.add_child(close_btn)

	_modal_overlay.visible = true


func _add_autocannon_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	var ammo_btn := Button.new()
	ammo_btn.text = "🔫  Ammo Type"
	ammo_btn.custom_minimum_size = Vector2(280, 44)
	ammo_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ammo_btn.pressed.connect(_show_ammo_type_modal.bind(gun))
	vbox.add_child(ammo_btn)

	var barrel_btn := Button.new()
	barrel_btn.text = "📏  Barrel Length"
	barrel_btn.custom_minimum_size = Vector2(280, 44)
	barrel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	barrel_btn.pressed.connect(_show_barrel_length_modal.bind(gun))
	vbox.add_child(barrel_btn)


func _add_rocket_pod_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	var targeting_btn := Button.new()
	targeting_btn.text = "🎯  Targeting"
	targeting_btn.custom_minimum_size = Vector2(280, 44)
	targeting_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	targeting_btn.pressed.connect(_show_targeting_type_modal.bind(gun))
	vbox.add_child(targeting_btn)


func _hide_modify_modal() -> void:
	_sub_modal_overlay.visible = false
	_modal_overlay.visible = false


func _on_modal_overlay_input(event: InputEvent) -> void:
	if _sub_modal_overlay.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		_hide_modify_modal()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _sub_modal_overlay.visible:
			_hide_sub_modal()
			get_viewport().set_input_as_handled()
		elif _modal_overlay.visible:
			_hide_modify_modal()
			get_viewport().set_input_as_handled()


# ── Sub-modal infrastructure ──────────────────────────────────────────────────

func _build_sub_modal() -> void:
	_sub_modal_overlay = ColorRect.new()
	_sub_modal_overlay.color = Color(0.0, 0.0, 0.0, 0.4)
	_sub_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_sub_modal_overlay.visible = false
	_sub_modal_overlay.gui_input.connect(_on_sub_modal_overlay_input)
	add_child(_sub_modal_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_modal_overlay.add_child(center)

	_sub_modal_panel = PanelContainer.new()
	_sub_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sub_modal_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sub_modal_panel.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.14, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.7, 0.85, 0.95, 0.9)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(24)
	_sub_modal_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_sub_modal_panel)


func _show_sub_modal(title_text: String, body_text: String) -> void:
	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	var body := Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(120, 36)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(_hide_sub_modal)
	vbox.add_child(back_btn)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _hide_sub_modal() -> void:
	_sub_modal_overlay.visible = false


func _on_sub_modal_overlay_input(event: InputEvent) -> void:
	if not _sub_modal_overlay.visible:
		return
	if Engine.get_process_frames() == _sub_modal_open_frame:
		return
	if event is InputEventMouseButton and event.pressed:
		_hide_sub_modal()
		get_viewport().set_input_as_handled()


func _show_ammo_type_modal(gun: WeaponData) -> void:
	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "🔫  AMMO TYPE — %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	# Shell row
	var shell_row := HBoxContainer.new()
	shell_row.add_theme_constant_override("separation", 24)
	shell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(shell_row)

	var types: Array[Dictionary] = [
		{"type": WeaponData.AmmoType.HE,       "label": "HE"},
		{"type": WeaponData.AmmoType.SOLID,     "label": "SOLID"},
		{"type": WeaponData.AmmoType.CANISTER,  "label": "CANISTER"},
	]

	for entry in types:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		shell_row.add_child(col)

		var shell := AmmoShell.new()
		shell.setup(entry["type"], gun.ammo_type == entry["type"])
		shell.shell_clicked.connect(_on_ammo_selected.bind(gun))
		col.add_child(shell)

		var lbl := Label.new()
		lbl.text = entry["label"]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _on_ammo_selected(selected_type: WeaponData.AmmoType, gun: WeaponData) -> void:
	gun.ammo_type = selected_type
	_hide_sub_modal()


func _show_targeting_type_modal(gun: WeaponData) -> void:
	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = "🎯  TARGETING — %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var types: Array[Dictionary] = [
		{"type": WeaponData.TargetingType.UNGUIDED,     "label": "UNGUIDED",\
			"desc": "Rockets fly straight"},
		{"type": WeaponData.TargetingType.SEEKING,      "label": "SEEKING",\
			"desc": "Rockets track enemies"},
		{"type": WeaponData.TargetingType.WIRE_GUIDED,  "label": "WIRE GUIDED",\
			"desc": "Rockets track cursor"},
	]

	for entry in types:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_child(col)

		var btn := Button.new()
		btn.text = entry["label"]
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_on_targeting_selected.bind(entry["type"], gun))
		col.add_child(btn)

		var desc := Label.new()
		desc.text = entry["desc"]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(desc)

		# Highlight currently selected
		if gun.targeting_type == entry["type"]:
			var indicator := Label.new()
			indicator.text = "▼ EQUIPPED"
			indicator.add_theme_font_size_override("font_size", 10)
			indicator.add_theme_color_override("font_color", Color(0.95, 0.15, 0.15))
			indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(indicator)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _on_targeting_selected(selected_type: WeaponData.TargetingType, gun: WeaponData) -> void:
	gun.targeting_type = selected_type
	_hide_sub_modal()


func _show_barrel_length_modal(gun: WeaponData) -> void:
	_show_sub_modal(
		"📏  BARREL LENGTH — %s" % gun.name,
		"Barrel length tuning coming soon.\n\nAdjust barrel length to trade between\naccuracy, range, and fire rate."
	)
