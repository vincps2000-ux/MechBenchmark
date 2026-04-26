# workshop_screen.gd — Drag-and-drop Workshop.
# All parts are displayed in a scrollable catalog on the left.
# The right panel shows the mech preview with drop zones at mount points.
# Drag a part from the catalog onto the matching slot to equip it.
# Slot capacity is MODULAR: legs define torso_slots, torsos define weapon_slots.
extends Control

signal deploy_pressed(loadout: MechLoadout)

const _MISSILE_BUILDER_PART_CARD_SCRIPT := preload("res://src/ui/missile_builder_part_card.gd")
const _MISSILE_BUILDER_SLOT_SCRIPT := preload("res://src/ui/missile_builder_slot.gd")
const _THROWER_TANK_SCRIPT := preload("res://src/ui/thrower_tank.gd")

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

# ── Missile builder (Rocket Pod) ────────────────────────────────────────────
const _MISSILE_SLOT_COUNT := 6
const _MISSILE_PART_DEFS := {
	"fuel": {
		"title": "Fuel Part",
		"desc": "+Range (longer rocket lifetime)",
		"cost": 1,
	},
	"explosive": {
		"title": "Explosive Part",
		"desc": "+Damage and +AOE",
		"cost": 1,
	},
	"wire_guided": {
		"title": "Wire Guided",
		"desc": "Guidance module (exclusive)",
		"cost": 1,
	},
	"homing": {
		"title": "Homing",
		"desc": "Guidance module (exclusive, takes 3 slots)",
		"cost": 3,
	},
}

var _missile_builder_weapon: WeaponData = null
var _missile_builder_layout: Array[String] = []
var _missile_slot_zones: Array = []
var _missile_builder_status_label: Label = null
var _missile_builder_stats_label: Label = null

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

	var legs_body := _add_section_header("── MOVEMENT ──")
	for i in _all_legs.size():
		var card := DragPartCard.new()
		card.setup(_all_legs[i], "legs", i)
		legs_body.add_child(card)
		_leg_cards.append(card)

	var torsos_body := _add_section_header("── TORSO ──")
	for i in _all_torsos.size():
		var card := DragPartCard.new()
		card.setup(_all_torsos[i], "torso", i)
		torsos_body.add_child(card)
		_torso_cards.append(card)

	var weapons_body := _add_section_header("── WEAPONS ──")
	for i in _all_guns.size():
		var card := DragPartCard.new()
		card.setup(_all_guns[i], "weapon", i)
		card.modify_pressed.connect(_on_modify_weapon)
		weapons_body.add_child(card)
		_weapon_cards.append(card)

	var light_body := _add_section_header("── LIGHT WEAPONS ──")
	for i in _all_light_guns.size():
		var card := DragPartCard.new()
		card.setup(_all_light_guns[i], "light_weapon", i)
		card.modify_pressed.connect(_on_modify_weapon)
		light_body.add_child(card)
		_light_weapon_cards.append(card)


func _add_section_header(text: String) -> VBoxContainer:
	var btn := Button.new()
	btn.text = "▼ " + text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.6, 0.8, 0.75, 0.65))
	btn.custom_minimum_size = Vector2(0, 30)
	_parts_box.add_child(btn)

	var body := VBoxContainer.new()
	_parts_box.add_child(body)

	btn.pressed.connect(func():
		body.visible = !body.visible
		btn.text = ("▼ " if body.visible else "▶ ") + text
	)
	return body

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
	var ph := _preview_stack.custom_minimum_size.y
	var center := Vector2(pw * 0.5, ph * 0.5)
	var zone_w := 130 if slot_count > 1 else 150
	var spacing := 10
	var torso_size := Vector2(pw, ph) if slot_count <= 1 else Vector2(150.0, 150.0)
	var torso_offsets := MechAssembler.scale_offsets(MechAssembler.get_torso_offsets(slot_count), pw)

	for i in slot_count:
		# Preview rect
		var rect := _make_preview_rect()
		_preview_stack.add_child(rect)
		rect.custom_minimum_size = torso_size
		rect.size = torso_size
		var offset := torso_offsets[i] if i < torso_offsets.size() else Vector2.ZERO
		rect.position = center + offset - torso_size * 0.5
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
	var previous_guns := _loadout.selected_guns.duplicate(true)
	var previous_light_guns := _loadout.selected_light_guns.duplicate(true)

	for zone in _weapon_zones:
		zone.queue_free()
	_weapon_zones.clear()
	for rect in _weapon_rects:
		rect.queue_free()
	_weapon_rects.clear()

	# Also clear light weapon zones
	for zone in _light_weapon_zones:
		zone.queue_free()
	_light_weapon_zones.clear()
	for rect in _light_weapon_rects:
		rect.queue_free()
	_light_weapon_rects.clear()

	# Don't show weapon zones until at least one torso is equipped
	var has_torso := false
	for torso in _loadout.selected_torsos:
		if torso:
			has_torso = true
			break
	if not has_torso and _loadout.selected_torso != null:
		has_torso = true
	if not has_torso:
		_loadout.selected_guns.clear()
		_loadout.selected_light_guns.clear()
		return

	# Build a compact torso list and matching torso base offsets.
	var equipped_torsos: Array[TorsoData] = []
	for torso in _loadout.selected_torsos:
		if torso:
			equipped_torsos.append(torso)
	if equipped_torsos.is_empty() and _loadout.selected_torso:
		equipped_torsos.append(_loadout.selected_torso)

	var torso_offsets := MechAssembler.get_torso_offsets(equipped_torsos.size())

	# Gather weapon mount offsets from all equipped torsos (via MechAssembler)
	var raw_offsets: Array[Vector2] = []
	for i in equipped_torsos.size():
		var torso := equipped_torsos[i]
		var torso_base := torso_offsets[i] if i < torso_offsets.size() else Vector2.ZERO
		for mount in MechAssembler.get_weapon_offsets(torso.torso_type):
			raw_offsets.append(torso_base + mount)

	var slot_count: int = raw_offsets.size()
	if slot_count == 0:
		slot_count = 1
		raw_offsets.append(Vector2.ZERO)

	_loadout.selected_guns.clear()
	for i in mini(previous_guns.size(), slot_count):
		_loadout.selected_guns.append(previous_guns[i])
	while _loadout.selected_guns.size() > 0 and _loadout.selected_guns.back() == null:
		_loadout.selected_guns.pop_back()

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
		if i < _loadout.selected_guns.size() and _loadout.selected_guns[i]:
			var gun := _loadout.selected_guns[i]
			_update_preview_layer(rect, gun.get_sprite_path())
			rect.rotation = _weapon_preview_rotation(gun)
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
		if i < _loadout.selected_guns.size() and _loadout.selected_guns[i]:
			zone.visible = false
		_weapon_zones.append(zone)

	# ── Light weapon zones ────────────────────────────────────────────────
	var light_offsets: Array[Vector2] = []
	for i in equipped_torsos.size():
		var torso := equipped_torsos[i]
		var torso_base := torso_offsets[i] if i < torso_offsets.size() else Vector2.ZERO
		for mount in MechAssembler.get_light_weapon_offsets(torso.torso_type):
			light_offsets.append(torso_base + mount)

	_loadout.selected_light_guns.clear()
	for i in mini(previous_light_guns.size(), light_offsets.size()):
		_loadout.selected_light_guns.append(previous_light_guns[i])
	while _loadout.selected_light_guns.size() > 0 and _loadout.selected_light_guns.back() == null:
		_loadout.selected_light_guns.pop_back()

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
			if i < _loadout.selected_light_guns.size() and _loadout.selected_light_guns[i]:
				var gun := _loadout.selected_light_guns[i]
				_update_preview_layer(rect, gun.get_sprite_path())
				rect.rotation = _weapon_preview_rotation(gun)
			_light_weapon_rects.append(rect)

			var label := "S.WPN %d" % (i + 1) if light_offsets.size() > 1 else "S.WPN"
			var zone_w2 := 72
			var zone_h2 := 32
			var zone := PartDropZone.new()
			zone.setup("light_weapon", label, Vector2(zone_w2, zone_h2), i)
			_preview_stack.add_child(zone)
			zone.position = mount_center - Vector2(zone_w2 * 0.5, zone_h2 * 0.5)
			zone.part_equipped.connect(_on_light_weapon_equipped.bind(i))
			if i < _loadout.selected_light_guns.size() and _loadout.selected_light_guns[i]:
				zone.visible = false
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
	# Deep-duplicate so each slot has its own independent WeaponData copy
	_loadout.selected_guns[slot] = (data as WeaponData).duplicate(true)

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
	_loadout.selected_light_guns[slot] = (data as WeaponData).duplicate(true)

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
	WeaponData.WeaponType.FLAMETHROWER,
	WeaponData.WeaponType.RAILGUN,
	WeaponData.WeaponType.LASER,
	WeaponData.WeaponType.MACHINEGUN,
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
		var ammo_label := _weapon_variant_label(gun)
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


static func _thrower_element_label(element: WeaponData.ThrowerElement) -> String:
	match element:
		WeaponData.ThrowerElement.FUEL: return "Fuel"
		WeaponData.ThrowerElement.ACID: return "Acid"
		WeaponData.ThrowerElement.CRYOGENICS: return "Cryogenics"
	return "Unknown"


static func _weapon_variant_label(gun: WeaponData) -> String:
	if gun.weapon_type == WeaponData.WeaponType.FLAMETHROWER:
		return "Element: %s" % _thrower_element_label(gun.thrower_element)
	return _ammo_type_label(gun.ammo_type)


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
		WeaponData.WeaponType.MACHINEGUN:
			_add_machinegun_options(vbox, gun)
		WeaponData.WeaponType.FLAMETHROWER:
			_add_chemical_thrower_options(vbox, gun)
		WeaponData.WeaponType.ROCKET_POD:
			_add_rocket_pod_options(vbox, gun)

	# Attachments (available for all weapons)
	_add_attachment_options(vbox, gun)

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
	_add_barrel_length_button(vbox, gun)


func _add_machinegun_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	_add_barrel_length_button(vbox, gun)


func _add_chemical_thrower_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	var element_btn := Button.new()
	element_btn.text = "Tank  Thrower Element"
	element_btn.custom_minimum_size = Vector2(280, 44)
	element_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	element_btn.pressed.connect(_show_thrower_element_modal.bind(gun))
	vbox.add_child(element_btn)


func _add_rocket_pod_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	var missile_builder_btn := Button.new()
	missile_builder_btn.text = "🚀  Missile Builder"
	missile_builder_btn.custom_minimum_size = Vector2(280, 44)
	missile_builder_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	missile_builder_btn.pressed.connect(_show_missile_builder_modal.bind(gun))
	vbox.add_child(missile_builder_btn)


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


func _show_thrower_element_modal(gun: WeaponData) -> void:
	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = "THROWER ELEMENT - %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var elements: Array[Dictionary] = [
		{"type": WeaponData.ThrowerElement.FUEL, "label": "FUEL"},
		{"type": WeaponData.ThrowerElement.ACID, "label": "ACID"},
		{"type": WeaponData.ThrowerElement.CRYOGENICS, "label": "CRYOGENICS"},
	]

	for entry in elements:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)

		var tank = _THROWER_TANK_SCRIPT.new()
		tank.setup(entry["type"], gun.thrower_element == entry["type"])
		tank.tank_clicked.connect(_on_thrower_element_selected.bind(gun))
		col.add_child(tank)

		var lbl := Label.new()
		lbl.text = entry["label"]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _on_thrower_element_selected(selected_element: WeaponData.ThrowerElement, gun: WeaponData) -> void:
	gun.thrower_element = selected_element
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


func _add_barrel_length_button(vbox: VBoxContainer, gun: WeaponData) -> void:
	gun.barrel_length = WeaponData.clamp_barrel_length(gun.barrel_length)
	var barrel_btn := Button.new()
	barrel_btn.text = "📏  Barrel Length (%s/%d)" % [WeaponData.get_barrel_length_label(gun.barrel_length), WeaponData.BARREL_LENGTH_COUNT]
	barrel_btn.custom_minimum_size = Vector2(280, 44)
	barrel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	barrel_btn.pressed.connect(_show_barrel_length_modal.bind(gun))
	vbox.add_child(barrel_btn)


func _show_barrel_length_modal(gun: WeaponData) -> void:
	gun.barrel_length = WeaponData.clamp_barrel_length(gun.barrel_length)

	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = "📏  BARREL LENGTH — %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(controls)

	var decrease_btn := Button.new()
	decrease_btn.text = "◀"
	decrease_btn.custom_minimum_size = Vector2(44, 44)
	decrease_btn.disabled = gun.barrel_length <= WeaponData.BarrelLength.VERY_SHORT
	decrease_btn.pressed.connect(_on_barrel_length_adjusted.bind(-1, gun))
	controls.add_child(decrease_btn)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(220, 80)
	preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.14, 0.12, 0.1, 0.9)
	preview_style.border_color = Color(0.42, 0.34, 0.22, 0.8)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(8)
	preview_style.set_content_margin_all(10)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	controls.add_child(preview_panel)

	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_box)

	var barrel_row := HBoxContainer.new()
	barrel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	barrel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_box.add_child(barrel_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barrel_row.add_child(spacer)

	var breech := ColorRect.new()
	breech.color = Color(0.56, 0.53, 0.5, 1.0)
	breech.custom_minimum_size = Vector2(24, 22)
	barrel_row.add_child(breech)

	var barrel := ColorRect.new()
	barrel.color = Color(0.82, 0.78, 0.72, 1.0)
	barrel.custom_minimum_size = Vector2(_barrel_preview_width(gun.barrel_length), 10)
	barrel_row.add_child(barrel)

	var muzzle := ColorRect.new()
	muzzle.color = Color(0.95, 0.76, 0.28, 1.0)
	muzzle.custom_minimum_size = Vector2(8, 16)
	barrel_row.add_child(muzzle)

	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barrel_row.add_child(spacer_right)

	var level_label := Label.new()
	level_label.text = "SIZE %s / %d" % [WeaponData.get_barrel_length_label(gun.barrel_length), WeaponData.BARREL_LENGTH_COUNT]
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.73, 0.77, 0.8))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(level_label)

	var increase_btn := Button.new()
	increase_btn.text = "▶"
	increase_btn.custom_minimum_size = Vector2(44, 44)
	increase_btn.disabled = gun.barrel_length >= WeaponData.BarrelLength.VERY_LONG
	increase_btn.pressed.connect(_on_barrel_length_adjusted.bind(1, gun))
	controls.add_child(increase_btn)

	var desc := Label.new()
	desc.text = _barrel_length_description(gun.barrel_length)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.65, 0.61, 0.56))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _on_barrel_length_adjusted(delta: int, gun: WeaponData) -> void:
	gun.barrel_length = WeaponData.clamp_barrel_length(gun.barrel_length + delta)
	call_deferred("_show_barrel_length_modal", gun)


func _barrel_preview_width(length_level: int) -> float:
	return 42.0 + float(WeaponData.clamp_barrel_length(length_level)) * 18.0


func _barrel_length_description(length_level: int) -> String:
	match WeaponData.clamp_barrel_length(length_level):
		WeaponData.BarrelLength.VERY_SHORT:
			return "Very short: fastest cycling, shortest reach, widest shot spread."
		WeaponData.BarrelLength.SHORT:
			return "Short: quick handling with reduced range and loose grouping."
		WeaponData.BarrelLength.STANDARD:
			return "Standard: balanced fire rate, reach, and accuracy."
		WeaponData.BarrelLength.LONG:
			return "Long: slower cycling, stronger reach, and tighter grouping."
		WeaponData.BarrelLength.VERY_LONG:
			return "Very long: slowest cycling, longest reach, and best accuracy."
	return "Standard: balanced fire rate, reach, and accuracy."


func _show_missile_builder_modal(gun: WeaponData) -> void:
	_missile_builder_weapon = gun
	_missile_builder_layout = _normalize_missile_layout(gun.missile_builder_layout)

	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(760, 420)
	root.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(root)

	var title := Label.new()
	title.text = "🚀  MISSILE BUILDER — %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	root.add_child(sep)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var parts_panel := PanelContainer.new()
	parts_panel.custom_minimum_size = Vector2(300, 0)
	body.add_child(parts_panel)

	var parts_style := StyleBoxFlat.new()
	parts_style.bg_color = Color(0.1, 0.09, 0.13, 0.8)
	parts_style.set_border_width_all(1)
	parts_style.border_color = Color(0.35, 0.31, 0.28, 0.55)
	parts_style.set_corner_radius_all(8)
	parts_style.set_content_margin_all(12)
	parts_panel.add_theme_stylebox_override("panel", parts_style)

	var parts_vbox := VBoxContainer.new()
	parts_vbox.add_theme_constant_override("separation", 8)
	parts_panel.add_child(parts_vbox)

	var parts_title := Label.new()
	parts_title.text = "MISSILE PARTS"
	parts_title.add_theme_font_size_override("font_size", 14)
	parts_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3))
	parts_vbox.add_child(parts_title)

	for part_id in ["fuel", "explosive", "wire_guided", "homing"]:
		var def: Dictionary = _MISSILE_PART_DEFS[part_id]
		var card: Control = _MISSILE_BUILDER_PART_CARD_SCRIPT.new()
		card.setup(part_id, def.get("title", "Part"), def.get("desc", ""), int(def.get("cost", 1)))
		parts_vbox.add_child(card)

	var parts_hint := Label.new()
	parts_hint.text = "Drag parts into the 6 missile slots.\nClick a filled slot to remove that module."
	parts_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parts_hint.add_theme_font_size_override("font_size", 11)
	parts_hint.add_theme_color_override("font_color", Color(0.58, 0.54, 0.5))
	parts_vbox.add_child(parts_hint)

	var builder_panel := PanelContainer.new()
	builder_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(builder_panel)

	var builder_style := StyleBoxFlat.new()
	builder_style.bg_color = Color(0.09, 0.1, 0.12, 0.85)
	builder_style.set_border_width_all(1)
	builder_style.border_color = Color(0.35, 0.4, 0.45, 0.55)
	builder_style.set_corner_radius_all(8)
	builder_style.set_content_margin_all(16)
	builder_panel.add_theme_stylebox_override("panel", builder_style)

	var builder_vbox := VBoxContainer.new()
	builder_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	builder_vbox.add_theme_constant_override("separation", 12)
	builder_panel.add_child(builder_vbox)

	var missile_title := Label.new()
	missile_title.text = "MISSILE CORE (6 SLOTS)"
	missile_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	missile_title.add_theme_font_size_override("font_size", 14)
	missile_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	builder_vbox.add_child(missile_title)

	var frame_wrap := CenterContainer.new()
	frame_wrap.custom_minimum_size = Vector2(0, 40)
	builder_vbox.add_child(frame_wrap)

	var frame_bar := HBoxContainer.new()
	frame_bar.custom_minimum_size = Vector2(180, 30)
	frame_bar.add_theme_constant_override("separation", 0)
	frame_wrap.add_child(frame_bar)

	var frame_nose := ColorRect.new()
	frame_nose.custom_minimum_size = Vector2(18, 30)
	frame_nose.color = Color(0.15, 0.2, 0.25, 0.9)
	frame_bar.add_child(frame_nose)

	var frame_body := PanelContainer.new()
	frame_body.custom_minimum_size = Vector2(142, 30)
	frame_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(0.08, 0.1, 0.12, 0.92)
	body_style.set_border_width_all(2)
	body_style.border_color = Color(0.95, 0.76, 0.3, 0.65)
	body_style.set_corner_radius_all(6)
	frame_body.add_theme_stylebox_override("panel", body_style)
	frame_bar.add_child(frame_body)

	var tail := ColorRect.new()
	tail.custom_minimum_size = Vector2(20, 30)
	tail.color = Color(0.2, 0.16, 0.1, 0.9)
	frame_bar.add_child(tail)

	var rocket_visual := HBoxContainer.new()
	rocket_visual.alignment = BoxContainer.ALIGNMENT_CENTER
	rocket_visual.add_theme_constant_override("separation", 6)
	builder_vbox.add_child(rocket_visual)

	var nose := Label.new()
	nose.text = "◀"
	nose.add_theme_font_size_override("font_size", 20)
	nose.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	rocket_visual.add_child(nose)

	_missile_slot_zones.clear()
	for i in _MISSILE_SLOT_COUNT:
		var zone: Control = _MISSILE_BUILDER_SLOT_SCRIPT.new()
		zone.setup(i, Vector2(46, 46))
		zone.part_dropped.connect(_on_missile_part_dropped)
		zone.slot_clicked.connect(_on_missile_slot_clicked)
		rocket_visual.add_child(zone)
		_missile_slot_zones.append(zone)

	var thruster := Label.new()
	thruster.text = "▶"
	thruster.add_theme_font_size_override("font_size", 20)
	thruster.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	rocket_visual.add_child(thruster)

	_missile_builder_status_label = Label.new()
	_missile_builder_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missile_builder_status_label.add_theme_font_size_override("font_size", 12)
	builder_vbox.add_child(_missile_builder_status_label)

	_missile_builder_stats_label = Label.new()
	_missile_builder_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missile_builder_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_missile_builder_stats_label.add_theme_font_size_override("font_size", 12)
	_missile_builder_stats_label.add_theme_color_override("font_color", Color(0.8, 0.76, 0.68))
	builder_vbox.add_child(_missile_builder_stats_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	builder_vbox.add_child(spacer)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	builder_vbox.add_child(controls)

	var clear_btn := Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.custom_minimum_size = Vector2(120, 36)
	clear_btn.pressed.connect(_on_missile_builder_clear)
	controls.add_child(clear_btn)

	var done_btn := Button.new()
	done_btn.text = "DONE"
	done_btn.custom_minimum_size = Vector2(120, 36)
	done_btn.pressed.connect(_hide_sub_modal)
	controls.add_child(done_btn)

	_refresh_missile_builder_view()

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _on_missile_part_dropped(part_id: String, slot_index: int) -> void:
	if _missile_builder_weapon == null:
		return
	if not _MISSILE_PART_DEFS.has(part_id):
		return

	var before_layout: Array[String] = _missile_builder_layout.duplicate()
	var guidance_part := part_id == "wire_guided" or part_id == "homing"
	if guidance_part:
		_clear_guidance_modules()

	if not _can_place_missile_part(part_id, slot_index):
		_missile_builder_layout = before_layout
		_missile_builder_status_label.text = "Cannot place %s there" % _MISSILE_PART_DEFS[part_id].get("title", "part")
		_missile_builder_status_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35))
		_refresh_missile_builder_view()
		return

	_place_missile_part(part_id, slot_index)
	_apply_missile_builder_to_weapon()
	_refresh_missile_builder_view()


func _on_missile_slot_clicked(slot_index: int) -> void:
	if _missile_builder_weapon == null:
		return
	if slot_index < 0 or slot_index >= _missile_builder_layout.size():
		return
	if _missile_builder_layout[slot_index] == "":
		return

	_remove_missile_module_at(slot_index)
	_apply_missile_builder_to_weapon()
	_refresh_missile_builder_view()


func _on_missile_builder_clear() -> void:
	if _missile_builder_weapon == null:
		return
	_missile_builder_layout = _normalize_missile_layout([])
	_apply_missile_builder_to_weapon()
	_refresh_missile_builder_view()


func _refresh_missile_builder_view() -> void:
	_missile_builder_layout = _normalize_missile_layout(_missile_builder_layout)
	if _missile_slot_zones.is_empty():
		return

	for i in mini(_missile_slot_zones.size(), _MISSILE_SLOT_COUNT):
		var value := _missile_builder_layout[i]
		var zone: Control = _missile_slot_zones[i]
		if value == "":
			zone.set_display("%d" % (i + 1), Color(0.66, 0.62, 0.56), false, false)
			continue

		match value:
			"fuel":
				zone.set_display("F", Color(0.94, 0.86, 0.5), true, false)
			"explosive":
				zone.set_display("E", Color(0.97, 0.56, 0.34), true, false)
			"wire_guided":
				zone.set_display("W", Color(0.54, 0.83, 0.94), true, false)
			"homing":
				zone.set_display("H", Color(0.65, 0.95, 0.7), true, false)
			"homing_tail":
				zone.set_display("·", Color(0.58, 0.82, 0.6), true, true)
			_:
				zone.set_display("?", Color(0.85, 0.5, 0.45), true, false)

	if _missile_builder_weapon:
		var summary := _get_missile_layout_summary(_missile_builder_layout)
		_missile_builder_status_label.text = "Slots used: %d / %d  |  %s" % [
			summary.get("used", 0),
			_MISSILE_SLOT_COUNT,
			summary.get("guidance_label", "Unguided"),
		]
		_missile_builder_status_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.95))
		var speed := _missile_builder_weapon.projectile_speed
		var range_px := speed * _missile_builder_weapon.projectile_lifetime
		var explosive_text := "LIVE WARHEAD" if _missile_builder_weapon.missile_has_explosive else "INERT (NO DAMAGE/NO EXPLOSION)"
		_missile_builder_stats_label.text = "Speed %.0f  |  Range %.0f px  |  Damage %d  |  AOE %.2f\n%s" % [
			speed,
			range_px,
			_missile_builder_weapon.damage,
			_missile_builder_weapon.area,
			explosive_text,
		]


func _apply_missile_builder_to_weapon() -> void:
	if _missile_builder_weapon == null:
		return
	_missile_builder_layout = _normalize_missile_layout(_missile_builder_layout)
	_missile_builder_weapon.apply_missile_builder(_missile_builder_layout)
	_refresh_ui()


func _can_place_missile_part(part_id: String, slot_index: int) -> bool:
	if slot_index < 0:
		return false
	if slot_index >= _MISSILE_SLOT_COUNT:
		return false
	if not _MISSILE_PART_DEFS.has(part_id):
		return false

	var cost := int((_MISSILE_PART_DEFS[part_id] as Dictionary).get("cost", 1))
	if slot_index + cost > _MISSILE_SLOT_COUNT:
		return false

	for i in cost:
		if _missile_builder_layout[slot_index + i] != "":
			return false

	if part_id == "wire_guided" or part_id == "homing":
		for token in _missile_builder_layout:
			if token == "wire_guided" or token == "homing" or token == "homing_tail":
				return false

	return true


func _place_missile_part(part_id: String, slot_index: int) -> void:
	var cost := int((_MISSILE_PART_DEFS[part_id] as Dictionary).get("cost", 1))
	if cost == 1:
		_missile_builder_layout[slot_index] = part_id
		return

	_missile_builder_layout[slot_index] = part_id
	for i in range(1, cost):
		_missile_builder_layout[slot_index + i] = "%s_tail" % part_id


func _remove_missile_module_at(slot_index: int) -> void:
	var token := _missile_builder_layout[slot_index]
	if token == "":
		return

	if token == "homing_tail":
		var head := slot_index
		while head > 0 and _missile_builder_layout[head] == "homing_tail":
			head -= 1
		if _missile_builder_layout[head] == "homing":
			for i in 3:
				if head + i < _MISSILE_SLOT_COUNT and _missile_builder_layout[head + i].begins_with("homing"):
					_missile_builder_layout[head + i] = ""
		return

	if token == "homing":
		for i in 3:
			if slot_index + i < _MISSILE_SLOT_COUNT and _missile_builder_layout[slot_index + i].begins_with("homing"):
				_missile_builder_layout[slot_index + i] = ""
		return

	_missile_builder_layout[slot_index] = ""


func _clear_guidance_modules() -> void:
	for i in _MISSILE_SLOT_COUNT:
		var token := _missile_builder_layout[i]
		if token == "wire_guided" or token == "homing" or token == "homing_tail":
			_missile_builder_layout[i] = ""


func _get_missile_layout_summary(layout: Array[String]) -> Dictionary:
	var used := 0
	var guidance_label := "Unguided"
	for token in layout:
		if token != "":
			used += 1
		if token == "wire_guided":
			guidance_label = "Wire Guided"
		elif token == "homing":
			guidance_label = "Homing"
	return {
		"used": used,
		"guidance_label": guidance_label,
	}


func _normalize_missile_layout(layout: Array[String]) -> Array[String]:
	var out: Array[String] = []
	out.resize(_MISSILE_SLOT_COUNT)
	for i in _MISSILE_SLOT_COUNT:
		out[i] = ""
	for i in mini(layout.size(), _MISSILE_SLOT_COUNT):
		out[i] = layout[i]
	return out


func _add_attachment_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	var attach_btn := Button.new()
	attach_btn.text = "🔦  Attachments"
	attach_btn.custom_minimum_size = Vector2(280, 44)
	attach_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	attach_btn.pressed.connect(_show_attachment_modal.bind(gun))
	vbox.add_child(attach_btn)


func _show_attachment_modal(gun: WeaponData) -> void:
	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = "🔦  ATTACHMENTS — %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	# Laser Pointer toggle
	var has_laser := _has_attachment(gun, AttachmentData.AttachmentType.LASER_POINTER)

	var laser_row := HBoxContainer.new()
	laser_row.add_theme_constant_override("separation", 12)
	laser_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(laser_row)

	var laser_label := Label.new()
	laser_label.text = "Laser Pointer"
	laser_label.add_theme_font_size_override("font_size", 14)
	laser_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	laser_row.add_child(laser_label)

	var laser_btn := Button.new()
	laser_btn.text = "REMOVE" if has_laser else "EQUIP"
	laser_btn.custom_minimum_size = Vector2(100, 36)
	laser_btn.pressed.connect(_on_toggle_laser_pointer.bind(gun))
	laser_row.add_child(laser_btn)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _has_attachment(gun: WeaponData, type: AttachmentData.AttachmentType) -> bool:
	for att in gun.attachments:
		if att != null and att.attachment_type == type:
			return true
	return false


func _on_toggle_laser_pointer(gun: WeaponData) -> void:
	var idx := -1
	for i in gun.attachments.size():
		if gun.attachments[i] != null and gun.attachments[i].attachment_type == AttachmentData.AttachmentType.LASER_POINTER:
			idx = i
			break
	if idx >= 0:
		gun.attachments.remove_at(idx)
	else:
		var att := AttachmentData.new()
		att.attachment_type = AttachmentData.AttachmentType.LASER_POINTER
		gun.attachments.append(att)
	call_deferred("_show_attachment_modal", gun)
