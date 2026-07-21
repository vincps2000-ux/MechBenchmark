# workshop_screen.gd — Drag-and-drop Workshop.
# All parts are displayed in a scrollable catalog on the left.
# The right panel shows the mech preview with drop zones at mount points.
# Drag a part from the catalog onto the matching slot to equip it.
# Slot capacity is MODULAR: legs define torso_slots, torsos define weapon_slots.
extends Control

signal deploy_pressed(loadout: MechLoadout)

const _MISSILE_BUILDER_PART_CARD_SCRIPT := preload("res://src/ui/missile_builder_part_card.gd")
const _MISSILE_BUILDER_SLOT_SCRIPT := preload("res://src/ui/missile_builder_slot.gd")
const _MISSILE_BUILDER_PREVIEW_SCRIPT := preload("res://src/ui/missile_builder_preview.gd")
const _THROWER_TANK_SCRIPT := preload("res://src/ui/thrower_tank.gd")
const _MACHINEGUN_WORKBENCH_PREVIEW_SCRIPT := preload("res://src/ui/machinegun_workbench_preview.gd")
const _NOZZLE_LONG_ICON_PATH := "res://assets/sprites/thrower_nozzle_long.svg"
const _NOZZLE_STANDARD_ICON_PATH := "res://assets/sprites/thrower_nozzle_standard.svg"
const _NOZZLE_WIDE_ICON_PATH := "res://assets/sprites/thrower_nozzle_wide.svg"
const _WIKI_ROOT := "res://assets/wiki"
const _WIKI_DEFAULT_PAGE := "res://assets/wiki/default.html"
const _WIKI_HF_IMAGES_ROOT := "res://assets/wiki/images/hf"

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

# ── Undo history (blueprint snapshots — every build step can be undone) ──────
var _history: Array[Dictionary] = []
var _last_state: Dictionary = {}
var _restoring := false

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

# ── Catalog category tabs ─────────────────────────────────────────────────────
const _CATALOG_CATEGORIES := [
	{"id": "legs",         "label": "LEGS"},
	{"id": "torso",        "label": "TORSO"},
	{"id": "weapon",       "label": "WEAPONS"},
	{"id": "light_weapon", "label": "LIGHT"},
]
var _catalog_tab_bar: HBoxContainer = null
var _catalog_tab_buttons: Dictionary = {}   # id -> Button
var _catalog_pages: Dictionary = {}         # id -> VBoxContainer

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
		"title": "Fuel Cell",
		"desc": "Adds thrust and extends powered flight",
		"cost": 1,
	},
	"explosive": {
		"title": "Warhead Charge",
		"desc": "Boosts blast damage and radius",
		"cost": 1,
	},
	"wire_guided": {
		"title": "Wire Guidance",
		"desc": "Cursor steering package (exclusive)",
		"cost": 1,
	},
	"homing": {
		"title": "Homing Array",
		"desc": "Autonomous tracking array (3 bays, exclusive)",
		"cost": 3,
	},
	"cluster": {
		"title": "Cluster Block",
		"desc": "Splits the blast into five scaled submunitions",
		"cost": 1,
	},
	"proximity_trigger": {
		"title": "Proximity Trigger",
		"desc": "Airbursts when an enemy enters the trigger radius",
		"cost": 1,
	},
}

var _missile_builder_weapon: WeaponData = null
var _missile_builder_layout: Array[String] = []
var _missile_slot_zones: Array = []
var _missile_builder_status_label: Label = null
var _missile_builder_stats_label: Label = null
var _missile_builder_preview: Control = null
var _missile_fire_mode_buttons: Dictionary = {}

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

	_step_label.text     = "DRAG PARTS ONTO THE MECH — OR DOUBLE-CLICK TO EQUIP"
	_selection_info.text = "Drag a part onto a glowing slot, or double-click it in the catalog"

	_build_parts_catalog()
	_build_preview_layers()
	_build_drop_zones()

	_deploy_button.pressed.connect(_on_deploy_pressed)
	_deploy_button.disabled = true
	_deploy_button.visible  = true

	_build_modify_modal()
	_build_sub_modal()
	_update_stats_preview()
	_last_state = _capture_state()
	_update_undo_button()

# ── Parts catalog (left panel) ────────────────────────────────────────────────

func _build_parts_catalog() -> void:
	for child in _parts_box.get_children():
		child.queue_free()
	if _catalog_tab_bar:
		_catalog_tab_bar.queue_free()
	_catalog_tab_buttons.clear()
	_catalog_pages.clear()
	_parts_label.text = "PARTS CATALOG  ·  drag or double-click to equip"
	_leg_cards.clear()
	_torso_cards.clear()
	_weapon_cards.clear()
	_light_weapon_cards.clear()

	# ── Category tab bar (above the scroll area) ──────────────────────────
	var parts_panel := _parts_scroll.get_parent()
	_catalog_tab_bar = HBoxContainer.new()
	_catalog_tab_bar.add_theme_constant_override("separation", 6)
	parts_panel.add_child(_catalog_tab_bar)
	parts_panel.move_child(_catalog_tab_bar, _parts_scroll.get_index())

	var group := ButtonGroup.new()
	for cat in _CATALOG_CATEGORIES:
		var id: String = cat["id"]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.text = cat["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_tab_button(btn)
		btn.toggled.connect(func(on: bool):
			if on:
				_show_catalog_page(id)
		)
		_catalog_tab_bar.add_child(btn)
		_catalog_tab_buttons[id] = btn

		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		page.visible = false
		_parts_box.add_child(page)
		_catalog_pages[id] = page

	# ── Cards ──────────────────────────────────────────────────────────────
	for i in _all_legs.size():
		_leg_cards.append(_add_part_card(_all_legs[i], "legs", i))
	for i in _all_torsos.size():
		_torso_cards.append(_add_part_card(_all_torsos[i], "torso", i))
	for i in _all_guns.size():
		_weapon_cards.append(_add_part_card(_all_guns[i], "weapon", i))
	for i in _all_light_guns.size():
		_light_weapon_cards.append(_add_part_card(_all_light_guns[i], "light_weapon", i))

	_select_catalog_tab("legs")
	_update_catalog_tab_badges()


func _add_part_card(data: Variant, type: String, index: int) -> DragPartCard:
	var card := DragPartCard.new()
	card.setup(data, type, index)
	card.wiki_pressed.connect(_on_part_wiki_requested)
	card.quick_equip.connect(_on_quick_equip)
	if type == "weapon" or type == "light_weapon":
		card.modify_pressed.connect(_on_modify_weapon)
	(_catalog_pages[type] as VBoxContainer).add_child(card)
	return card


static func _style_tab_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.11, 0.15, 0.7)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.32, 0.35, 0.4, 0.5)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.19, 0.24, 0.9)
	hover.border_color = Color(0.4, 0.75, 0.75, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.26, 0.2, 0.08, 0.95)
	pressed.border_color = Color(0.95, 0.7, 0.2, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.7, 0.72, 0.7))
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.85, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.9, 0.9))
	btn.add_theme_color_override("font_hover_pressed_color", Color(0.95, 0.85, 0.6))
	btn.add_theme_font_size_override("font_size", 13)


func _select_catalog_tab(id: String) -> void:
	var btn: Button = _catalog_tab_buttons.get(id)
	if btn == null:
		return
	btn.button_pressed = true
	_show_catalog_page(id)


func _show_catalog_page(id: String) -> void:
	for page_id in _catalog_pages:
		(_catalog_pages[page_id] as VBoxContainer).visible = page_id == id
	_parts_scroll.scroll_vertical = 0


## Updates each tab with an equipped/total badge, e.g. "WEAPONS 1/2".
func _update_catalog_tab_badges() -> void:
	if _catalog_tab_buttons.is_empty():
		return
	var counts := {
		"legs":         [1 if _loadout.selected_legs else 0, 1],
		"torso":        [0, 0],
		"weapon":       [0, _weapon_zones.size()],
		"light_weapon": [0, _light_weapon_zones.size()],
	}
	if _loadout.selected_legs:
		counts["torso"][1] = _loadout.selected_legs.torso_slots
	for torso in _loadout.selected_torsos:
		if torso:
			counts["torso"][0] += 1
	for gun in _loadout.selected_guns:
		if gun:
			counts["weapon"][0] += 1
	for gun in _loadout.selected_light_guns:
		if gun:
			counts["light_weapon"][0] += 1
	for cat in _CATALOG_CATEGORIES:
		var id: String = cat["id"]
		var btn := _catalog_tab_buttons[id] as Button
		var filled: int = counts[id][0]
		var total: int = counts[id][1]
		if total <= 0:
			btn.text = cat["label"]
		elif filled >= total:
			btn.text = "%s ✓" % cat["label"]
		else:
			btn.text = "%s %d/%d" % [cat["label"], filled, total]


# ── Quick equip (double-click a catalog card) ─────────────────────────────────

## Equips the part into the first free matching slot, mirroring a drag-drop.
func _on_quick_equip(data: Variant, type: String) -> void:
	match type:
		"legs":
			if _loadout.selected_legs == null:
				_on_legs_equipped(data)
		"torso":
			if _loadout.selected_legs == null:
				return
			for i in _loadout.selected_legs.torso_slots:
				var occupied: bool = i < _loadout.selected_torsos.size() \
						and _loadout.selected_torsos[i] != null
				if not occupied:
					_on_torso_equipped(data, i)
					return
		"weapon":
			_quick_equip_weapon(data)
		"light_weapon":
			if not _quick_equip_light_weapon(data):
				_quick_equip_weapon(data)


func _quick_equip_weapon(data: Variant) -> bool:
	for i in _weapon_zones.size():
		var occupied: bool = i < _loadout.selected_guns.size() \
				and _loadout.selected_guns[i] != null
		if not occupied:
			_on_weapon_equipped(data, i)
			return true
	return false


func _quick_equip_light_weapon(data: Variant) -> bool:
	for i in _light_weapon_zones.size():
		var occupied: bool = i < _loadout.selected_light_guns.size() \
				and _loadout.selected_light_guns[i] != null
		if not occupied:
			_on_light_weapon_equipped(data, i)
			return true
	return false

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
	if not _restoring:
		_select_catalog_tab("torso")
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
	if not _restoring and _all_torso_slots_filled():
		_select_catalog_tab("weapon")
	_refresh_ui()


func _all_torso_slots_filled() -> bool:
	if _loadout.selected_legs == null:
		return false
	for i in _loadout.selected_legs.torso_slots:
		if i >= _loadout.selected_torsos.size() or _loadout.selected_torsos[i] == null:
			return false
	return true


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
		WeaponData.WeaponType.PLASMA_GUN, \
		WeaponData.WeaponType.ROCKET_POD, WeaponData.WeaponType.MACHINEGUN, \
		WeaponData.WeaponType.ARTILLERY, \
		WeaponData.WeaponType.POM_POM, WeaponData.WeaponType.C4:
			return deg_to_rad(-90.0)
	return 0.0

# ── UI refresh ────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	_record_step()
	_update_card_highlights()
	_update_catalog_tab_badges()
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
		_selection_info.text = "Drag a part onto a glowing slot, or double-click it in the catalog"
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
	var structure_str := "Structure: %d/%d" % [preview_stats.health, preview_stats.max_health]
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
		structure_str,
		preview_stats.speed,
		_loadout.selected_legs.name,
		torso_name,
		weapon_names,
		total_dmg,
	]

# ── Undo ──────────────────────────────────────────────────────────────────────

func _on_undo_pressed() -> void:
	if _history.is_empty():
		return
	var state: Dictionary = _history.pop_back()
	_restore_state(state)
	_refresh_ui()


## Captures the current mech design as a JSON-like blueprint dictionary.
func _capture_state() -> Dictionary:
	return MechFactory.blueprint_from_loadout(_loadout).data


## Pushes the previous state onto the history if the mech actually changed.
## Called for every mutation (equips, weapon customizations, missile builder …)
## so every build step can be undone.
func _record_step() -> void:
	if _restoring:
		return
	var state := _capture_state()
	if JSON.stringify(state, "", true) == JSON.stringify(_last_state, "", true):
		return
	_history.append(_last_state.duplicate(true))
	_last_state = state
	_update_undo_button()


## Regenerates the gameplay loadout from a blueprint snapshot and replays the
## equip steps to rebuild the preview, drop zones and highlights.
func _restore_state(state: Dictionary) -> void:
	_restoring = true

	var restored := MechFactory.build_loadout_from_dict(state)

	# Reset to an empty mech.
	_loadout = MechLoadout.new()
	_legs_rect.modulate.a = 0.0
	_legs_zone.clear()
	_legs_zone.visible = true
	_rebuild_torso_zones()

	# Replay the equips through the normal handlers.
	if restored.selected_legs:
		_on_legs_equipped(restored.selected_legs)
		for slot in restored.selected_torsos.size():
			if restored.selected_torsos[slot]:
				_on_torso_equipped(restored.selected_torsos[slot], slot)
		for slot in restored.selected_guns.size():
			if restored.selected_guns[slot]:
				_on_weapon_equipped(restored.selected_guns[slot], slot)
		for slot in restored.selected_light_guns.size():
			if restored.selected_light_guns[slot]:
				_on_light_weapon_equipped(restored.selected_light_guns[slot], slot)

	_loadout.selected_utility_modules = restored.selected_utility_modules
	_loadout.module_grids = restored.module_grids

	_restoring = false
	_last_state = state


func _has_any_torso() -> bool:
	for t in _loadout.selected_torsos:
		if t:
			return true
	return _loadout.selected_torso != null


func _update_undo_button() -> void:
	_left_arrow.visible = _history.size() > 0

# ── Deploy ────────────────────────────────────────────────────────────────────

func _on_deploy_pressed() -> void:
	_deploy_button.disabled = true
	GameManager.current_loadout = _loadout
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _go_to_engineering_screen())


func _go_to_engineering_screen() -> void:
	# Use a normal scene transition so Workshop visuals are fully unloaded.
	get_tree().change_scene_to_file("res://scenes/ui/engineering_screen.tscn")


func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/utility_modules_screen.tscn")

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
	WeaponData.WeaponType.PLASMA_GUN,
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
		WeaponData.AmmoType.NORMAL: return "Normal Ammo"
		WeaponData.AmmoType.RIOT: return "Riot Rounds"
		WeaponData.AmmoType.SMART: return "Smart Rounds"
	return "Unknown"


static func _thrower_element_label(element: WeaponData.ThrowerElement) -> String:
	match element:
		WeaponData.ThrowerElement.FUEL: return "Fuel"
		WeaponData.ThrowerElement.ACID: return "Acid"
		WeaponData.ThrowerElement.CRYOGENICS: return "Cryogenics"
	return "Unknown"


static func _thrower_nozzle_label(nozzle: WeaponData.ThrowerNozzle) -> String:
	match nozzle:
		WeaponData.ThrowerNozzle.LONG_NOZZLE: return "Long Nozzle"
		WeaponData.ThrowerNozzle.WIDE_NOZZLE: return "Wide Nozzle"
		_: return "Nozzle"


static func _weapon_variant_label(gun: WeaponData) -> String:
	if gun.weapon_type == WeaponData.WeaponType.FLAMETHROWER:
		return "Element: %s | %s" % [_thrower_element_label(gun.thrower_element), _thrower_nozzle_label(gun.thrower_nozzle)]
	if gun.weapon_type == WeaponData.WeaponType.PLASMA_GUN:
		return "Core: Plasma"
	if gun.weapon_type == WeaponData.WeaponType.MACHINEGUN:
		return "%s | %d barrel%s" % [
			_ammo_type_label(gun.ammo_type),
			WeaponData.clamp_barrel_count(gun.barrel_count),
			"" if gun.barrel_count == 1 else "s",
		]
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
		WeaponData.WeaponType.LASER:
			_add_laser_options(vbox, gun)

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
	gun.barrel_count = WeaponData.clamp_barrel_count(gun.barrel_count)
	var bench_btn := Button.new()
	bench_btn.text = "ARMOURER'S BENCH  |  %s  |  %d BARREL%s" % [
		_ammo_type_label(gun.ammo_type).to_upper(),
		gun.barrel_count,
		"" if gun.barrel_count == 1 else "S",
	]
	bench_btn.custom_minimum_size = Vector2(380, 54)
	bench_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bench_btn.tooltip_text = "Field-strip, service, and rebuild this machinegun"
	bench_btn.pressed.connect(_show_machinegun_workbench.bind(gun))
	vbox.add_child(bench_btn)

	var service_note := Label.new()
	service_note.text = "Service card: bore clean | feed timed | headspace checked"
	service_note.add_theme_font_size_override("font_size", 11)
	service_note.add_theme_color_override("font_color", Color(0.53, 0.68, 0.57))
	service_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(service_note)


func _show_machinegun_workbench(gun: WeaponData) -> void:
	gun.barrel_count = WeaponData.clamp_barrel_count(gun.barrel_count)
	gun.barrel_length = WeaponData.clamp_barrel_length(gun.barrel_length)

	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(760, 610)
	root.add_theme_constant_override("separation", 9)
	_sub_modal_panel.add_child(root)

	var title := Label.new()
	title.text = "ARMOURER'S BENCH // %s" % gun.name.to_upper()
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.95, 0.73, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var shift_log := Label.new()
	shift_log.text = "SHIFT LOG  18:40  |  RECEIVER OPENED  |  FEED PAWL CLEANED  |  BUILD READY"
	shift_log.add_theme_font_size_override("font_size", 10)
	shift_log.add_theme_color_override("font_color", Color(0.48, 0.67, 0.59))
	shift_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(shift_log)

	var preview_frame := PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.055, 0.045, 0.035)
	preview_style.set_border_width_all(2)
	preview_style.border_color = Color(0.48, 0.3, 0.1)
	preview_style.set_corner_radius_all(5)
	preview_style.set_content_margin_all(0)
	preview_frame.add_theme_stylebox_override("panel", preview_style)
	root.add_child(preview_frame)

	var preview = _MACHINEGUN_WORKBENCH_PREVIEW_SCRIPT.new()
	preview.configure(gun)
	preview_frame.add_child(preview)

	var service_status := Label.new()
	service_status.text = "MAINTENANCE RECORD  /  FIELD STRIP COMPLETE  /  BORE CLEAN  /  HEADSPACE VERIFIED"
	service_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	service_status.add_theme_font_size_override("font_size", 10)
	service_status.add_theme_color_override("font_color", Color(0.48, 0.67, 0.59))
	root.add_child(service_status)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	root.add_child(controls)

	var ammo_column := VBoxContainer.new()
	ammo_column.custom_minimum_size = Vector2(330, 0)
	ammo_column.add_theme_constant_override("separation", 5)
	controls.add_child(ammo_column)

	var ammo_title := Label.new()
	ammo_title.text = "AMMUNITION BELT"
	ammo_title.add_theme_font_size_override("font_size", 13)
	ammo_title.add_theme_color_override("font_color", Color(0.83, 0.68, 0.39))
	ammo_column.add_child(ammo_title)

	for entry in _machinegun_ammo_entries():
		var ammo_btn := Button.new()
		ammo_btn.text = "%s\n%s" % [entry["label"], entry["factors"]]
		ammo_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ammo_btn.custom_minimum_size = Vector2(330, 45)
		ammo_btn.toggle_mode = true
		ammo_btn.button_pressed = gun.ammo_type == entry["type"]
		ammo_btn.tooltip_text = entry["description"]
		ammo_btn.pressed.connect(_on_machinegun_ammo_selected.bind(entry["type"], gun))
		ammo_column.add_child(ammo_btn)

	var build_column := VBoxContainer.new()
	build_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_column.add_theme_constant_override("separation", 8)
	controls.add_child(build_column)

	var count_title := Label.new()
	count_title.text = "BARREL CLUSTER"
	count_title.add_theme_font_size_override("font_size", 13)
	count_title.add_theme_color_override("font_color", Color(0.83, 0.68, 0.39))
	build_column.add_child(count_title)

	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 8)
	build_column.add_child(count_row)
	var count_down := Button.new()
	count_down.text = "-"
	count_down.custom_minimum_size = Vector2(42, 38)
	count_down.disabled = gun.barrel_count <= WeaponData.MIN_BARREL_COUNT
	count_down.pressed.connect(_on_machinegun_barrel_count_adjusted.bind(-1, gun))
	count_row.add_child(count_down)
	var count_value := Label.new()
	count_value.text = "%d BARREL%s" % [gun.barrel_count, "" if gun.barrel_count == 1 else "S"]
	count_value.custom_minimum_size = Vector2(118, 38)
	count_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_value.add_theme_font_size_override("font_size", 15)
	count_value.add_theme_color_override("font_color", Color(0.9, 0.82, 0.66))
	count_row.add_child(count_value)
	var count_up := Button.new()
	count_up.text = "+"
	count_up.custom_minimum_size = Vector2(42, 38)
	count_up.disabled = gun.barrel_count >= WeaponData.MAX_BARREL_COUNT
	count_up.pressed.connect(_on_machinegun_barrel_count_adjusted.bind(1, gun))
	count_row.add_child(count_up)

	var count_factors := Label.new()
	count_factors.text = _machinegun_barrel_factor_text(gun.barrel_count)
	count_factors.add_theme_font_size_override("font_size", 11)
	count_factors.add_theme_color_override("font_color", Color(0.66, 0.63, 0.56))
	count_factors.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_column.add_child(count_factors)

	var length_title := Label.new()
	length_title.text = "BARREL LENGTH / GAS TIMING"
	length_title.add_theme_font_size_override("font_size", 13)
	length_title.add_theme_color_override("font_color", Color(0.83, 0.68, 0.39))
	build_column.add_child(length_title)

	var length_row := HBoxContainer.new()
	length_row.alignment = BoxContainer.ALIGNMENT_CENTER
	length_row.add_theme_constant_override("separation", 8)
	build_column.add_child(length_row)
	var length_down := Button.new()
	length_down.text = "-"
	length_down.custom_minimum_size = Vector2(42, 38)
	length_down.disabled = gun.barrel_length <= WeaponData.BarrelLength.VERY_SHORT
	length_down.pressed.connect(_on_machinegun_barrel_length_adjusted.bind(-1, gun))
	length_row.add_child(length_down)
	var length_value := Label.new()
	length_value.text = "SIZE %s / %d" % [
		WeaponData.get_barrel_length_label(gun.barrel_length),
		WeaponData.BARREL_LENGTH_COUNT,
	]
	length_value.custom_minimum_size = Vector2(118, 38)
	length_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	length_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	length_value.add_theme_font_size_override("font_size", 15)
	length_value.add_theme_color_override("font_color", Color(0.9, 0.82, 0.66))
	length_row.add_child(length_value)
	var length_up := Button.new()
	length_up.text = "+"
	length_up.custom_minimum_size = Vector2(42, 38)
	length_up.disabled = gun.barrel_length >= WeaponData.BarrelLength.VERY_LONG
	length_up.pressed.connect(_on_machinegun_barrel_length_adjusted.bind(1, gun))
	length_row.add_child(length_up)

	var length_factors := Label.new()
	length_factors.text = _barrel_length_description(gun.barrel_length)
	length_factors.add_theme_font_size_override("font_size", 10)
	length_factors.add_theme_color_override("font_color", Color(0.66, 0.63, 0.56))
	length_factors.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	length_factors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_column.add_child(length_factors)

	var stats_panel := PanelContainer.new()
	var stats_style := StyleBoxFlat.new()
	stats_style.bg_color = Color(0.07, 0.095, 0.085, 0.95)
	stats_style.set_border_width_all(1)
	stats_style.border_color = Color(0.27, 0.58, 0.43)
	stats_style.set_corner_radius_all(4)
	stats_style.set_content_margin_all(7)
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	root.add_child(stats_panel)
	var stats := Label.new()
	stats.text = _machinegun_live_stats(gun)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.68, 0.86, 0.73))
	stats_panel.add_child(stats)

	var close_btn := Button.new()
	close_btn.text = "SIGN SERVICE CARD & RETURN"
	close_btn.custom_minimum_size = Vector2(250, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_hide_sub_modal)
	root.add_child(close_btn)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _machinegun_ammo_entries() -> Array[Dictionary]:
	return [
		{
			"type": WeaponData.AmmoType.NORMAL,
			"label": "NORMAL AMMO",
			"factors": "Standard automatic fire  |  Deals normal damage",
			"description": "Reliable general-purpose belt. Fires whenever the trigger is held.",
		},
		{
			"type": WeaponData.AmmoType.RIOT,
			"label": "RIOT ROUNDS",
			"factors": "No damage  |  Pushes enemies away",
			"description": "Non-lethal impact belt for controlling space and breaking enemy advances.",
		},
		{
			"type": WeaponData.AmmoType.SMART,
			"label": "SMART ROUNDS",
			"factors": "Only fires with enemy under cursor  |  HUD lock indicator",
			"description": "Trigger interlock prevents wasted fire until the cursor acquires an enemy.",
		},
	]


func _on_machinegun_ammo_selected(selected_type: WeaponData.AmmoType, gun: WeaponData) -> void:
	gun.ammo_type = selected_type
	_record_step()
	call_deferred("_show_machinegun_workbench", gun)


func _on_machinegun_barrel_count_adjusted(delta: int, gun: WeaponData) -> void:
	gun.barrel_count = WeaponData.clamp_barrel_count(gun.barrel_count + delta)
	_record_step()
	call_deferred("_show_machinegun_workbench", gun)


func _on_machinegun_barrel_length_adjusted(delta: int, gun: WeaponData) -> void:
	gun.barrel_length = WeaponData.clamp_barrel_length(gun.barrel_length + delta)
	_record_step()
	call_deferred("_show_machinegun_workbench", gun)


func _machinegun_barrel_factor_text(count: int) -> String:
	var profile: Dictionary = Machinegun.BARREL_COUNT_PROFILES[WeaponData.clamp_barrel_count(count) - 1]
	var cycle_percent := roundi(100.0 / float(profile["interval_factor"]))
	var spread_percent := roundi(100.0 * float(profile["spread_factor"]))
	return "Volley x%d  |  Cycle %d%%  |  Grouping %d%%" % [
		WeaponData.clamp_barrel_count(count), cycle_percent, spread_percent]


func _machinegun_live_stats(gun: WeaponData) -> String:
	var count_profile: Dictionary = Machinegun.BARREL_COUNT_PROFILES[
		WeaponData.clamp_barrel_count(gun.barrel_count) - 1]
	var length_profile: Dictionary = Machinegun.BARREL_PROFILES[
		WeaponData.clamp_barrel_length(gun.barrel_length)]
	var damage := 0 if gun.ammo_type == WeaponData.AmmoType.RIOT else gun.damage
	var interval := float(length_profile["fire_interval"]) * float(count_profile["interval_factor"])
	var spread := float(length_profile["spread_deg"]) * float(count_profile["spread_factor"])
	var mode := "PUSH / NO DAMAGE" if gun.ammo_type == WeaponData.AmmoType.RIOT \
			else ("CURSOR INTERLOCK" if gun.ammo_type == WeaponData.AmmoType.SMART else "FREE FIRE")
	return "%d RPM  |  %d ROUND VOLLEY  |  DMG %d  |  PEN %d  |  SPREAD %.1f DEG  |  %s" % [
		roundi(60.0 / interval), gun.barrel_count, damage, gun.penetration, spread, mode]


func _add_chemical_thrower_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	var element_btn := Button.new()
	element_btn.text = "Tank  Thrower Element"
	element_btn.custom_minimum_size = Vector2(280, 44)
	element_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	element_btn.pressed.connect(_show_thrower_element_modal.bind(gun))
	vbox.add_child(element_btn)

	var nozzle_btn := Button.new()
	nozzle_btn.text = "Nozzle  Spray Shape"
	nozzle_btn.custom_minimum_size = Vector2(280, 44)
	nozzle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nozzle_btn.pressed.connect(_show_thrower_nozzle_modal.bind(gun))
	vbox.add_child(nozzle_btn)


func _add_rocket_pod_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	var missile_builder_btn := Button.new()
	missile_builder_btn.text = "🚀  Missile Builder"
	missile_builder_btn.custom_minimum_size = Vector2(280, 44)
	missile_builder_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	missile_builder_btn.pressed.connect(_show_missile_builder_modal.bind(gun))
	vbox.add_child(missile_builder_btn)


func _add_laser_options(vbox: VBoxContainer, gun: WeaponData) -> void:
	gun.laser_intensity = clampi(gun.laser_intensity, 0, 4)
	var intensity_btn := Button.new()
	intensity_btn.text = "⚡  Energy Intensity (%s/%d)" % [_laser_intensity_name(gun.laser_intensity), 5]
	intensity_btn.custom_minimum_size = Vector2(280, 44)
	intensity_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	intensity_btn.pressed.connect(_show_laser_intensity_modal.bind(gun))
	vbox.add_child(intensity_btn)


static func _laser_intensity_name(level: int) -> String:
	match clampi(level, 0, 4):
		0: return "Flicker"
		1: return "Low"
		2: return "Standard"
		3: return "High"
		4: return "Overload"
	return "Standard"


static func _laser_intensity_description(level: int) -> String:
	match clampi(level, 0, 4):
		0: return "Flicker: 2 energy/s — hairline beam, only effective against unarmoured infantry."
		1: return "Low: 8 energy/s — reduced draw with light anti-infantry punch."
		2: return "Standard: 20 energy/s — balanced cutting power and energy economy."
		3: return "High: 35 energy/s — heavy burn, punches through light armour."
		4: return "Overload: 50 energy/s — maximum output; devastating damage and penetration."
	return "Standard: 20 energy/s — balanced cutting power and energy economy."


## Per-intensity stats mirroring Laser._INTENSITY_STATS: [energy/s, damage, penetration]
static func _laser_stats_for_intensity(level: int) -> Array:
	var table := [
		[2.0,  2,  1],
		[8.0,  5,  2],
		[20.0, 12, 3],
		[35.0, 22, 5],
		[50.0, 35, 8],
	]
	return table[clampi(level, 0, 4)]


func _show_laser_intensity_modal(gun: WeaponData) -> void:
	gun.laser_intensity = clampi(gun.laser_intensity, 0, 4)

	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚡  ENERGY INTENSITY — %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	# ── Left / Preview / Right ────────────────────────────────────────────────
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(controls)

	var decrease_btn := Button.new()
	decrease_btn.text = "◀"
	decrease_btn.custom_minimum_size = Vector2(44, 44)
	decrease_btn.disabled = gun.laser_intensity <= 0
	decrease_btn.pressed.connect(_on_laser_intensity_adjusted.bind(-1, gun))
	controls.add_child(decrease_btn)

	# Preview panel
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(220, 80)
	preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.05, 0.04, 0.10, 0.9)
	preview_style.border_color = Color(0.3, 0.35, 0.55, 0.8)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(8)
	preview_style.set_content_margin_all(10)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	controls.add_child(preview_panel)

	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_box)

	# Beam visualisation: a coloured horizontal bar whose thickness and colour
	# scale with intensity.
	var beam_row := HBoxContainer.new()
	beam_row.alignment = BoxContainer.ALIGNMENT_CENTER
	beam_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_box.add_child(beam_row)

	var lpad := Control.new()
	lpad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beam_row.add_child(lpad)

	var beam_h := int(2 + gun.laser_intensity * 3)  # 2 … 14 px
	var t := float(gun.laser_intensity) / 4.0
	var beam_color := Color(0.3 + t * 0.5, 0.3 - t * 0.2, 1.0 - t * 0.6, 1.0)
	var beam_bar := ColorRect.new()
	beam_bar.color = beam_color
	beam_bar.custom_minimum_size = Vector2(160, beam_h)
	beam_row.add_child(beam_bar)

	var rpad := Control.new()
	rpad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beam_row.add_child(rpad)

	# Stats line: energy / damage / pen
	var stats := _laser_stats_for_intensity(gun.laser_intensity)
	var stats_label := Label.new()
	stats_label.text = "%s  |  %.0f/s  ·  %d dmg  ·  %d pen" % [
		_laser_intensity_name(gun.laser_intensity),
		stats[0], stats[1], stats[2],
	]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.73, 0.77, 0.8))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(stats_label)

	var increase_btn := Button.new()
	increase_btn.text = "▶"
	increase_btn.custom_minimum_size = Vector2(44, 44)
	increase_btn.disabled = gun.laser_intensity >= 4
	increase_btn.pressed.connect(_on_laser_intensity_adjusted.bind(1, gun))
	controls.add_child(increase_btn)

	# Description
	var desc := Label.new()
	desc.text = _laser_intensity_description(gun.laser_intensity)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.65, 0.61, 0.56))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(320, 0)
	vbox.add_child(desc)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _on_laser_intensity_adjusted(delta: int, gun: WeaponData) -> void:
	gun.laser_intensity = clampi(gun.laser_intensity + delta, 0, 4)
	_record_step()
	call_deferred("_show_laser_intensity_modal", gun)


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


func _on_part_wiki_requested(data: Variant, part_type: String) -> void:
	var part_obj := data as Object
	if part_obj == null:
		return
	var part_name := str(part_obj.get("name"))
	if part_name.is_empty():
		part_name = "Unknown Part"
	var sprite_path := ""
	if part_obj.has_method("get_sprite_path"):
		sprite_path = part_obj.get_sprite_path()
	_show_wiki_modal(part_name, part_type, _resolve_wiki_page_path(part_name, part_type), sprite_path)


func _resolve_wiki_page_path(part_name: String, part_type: String) -> String:
	var slug := _part_name_to_slug(part_name)
	if slug.is_empty():
		return _WIKI_DEFAULT_PAGE

	var typed_page := "%s/%s/%s.html" % [_WIKI_ROOT, part_type, slug]
	if FileAccess.file_exists(typed_page):
		return typed_page

	var root_page := "%s/%s.html" % [_WIKI_ROOT, slug]
	if FileAccess.file_exists(root_page):
		return root_page

	if FileAccess.file_exists(_WIKI_DEFAULT_PAGE):
		return _WIKI_DEFAULT_PAGE
	return ""


func _part_name_to_slug(part_name: String) -> String:
	var slug := part_name.to_lower()
	var separator_regex := RegEx.new()
	separator_regex.compile("[^a-z0-9]+")
	slug = separator_regex.sub(slug, "_", true)
	while slug.begins_with("_"):
		slug = slug.substr(1)
	while slug.ends_with("_"):
		slug = slug.substr(0, slug.length() - 1)
	return slug


func _show_wiki_modal(part_name: String, part_type: String, page_path: String, sprite_path: String = "") -> void:
	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(780, 560)
	root.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(root)

	var title := Label.new()
	title.text = "WIKI — %s" % part_name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	root.add_child(sep)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(760, 390)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var info_tab := VBoxContainer.new()
	info_tab.name = "Information"
	info_tab.add_theme_constant_override("separation", 10)
	tabs.add_child(info_tab)

	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var sprite_row := CenterContainer.new()
		sprite_row.custom_minimum_size = Vector2(0, 128)
		info_tab.add_child(sprite_row)
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(sprite_path)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(128, 128)
		sprite_row.add_child(tex_rect)

	if part_type == "weapon" or part_type == "light_weapon":
		var gallery_entries := _get_wiki_gallery_entries(part_name, part_type)
		if not gallery_entries.is_empty():
			var gallery_title := Label.new()
			gallery_title.text = "Archive Images"
			gallery_title.add_theme_font_size_override("font_size", 14)
			gallery_title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
			gallery_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			info_tab.add_child(gallery_title)

			var gallery_scroll := ScrollContainer.new()
			gallery_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			gallery_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			gallery_scroll.custom_minimum_size = Vector2(0, 136)
			info_tab.add_child(gallery_scroll)

			var gallery_row := HBoxContainer.new()
			gallery_row.add_theme_constant_override("separation", 12)
			gallery_scroll.add_child(gallery_row)

			for entry in gallery_entries:
				var frame := PanelContainer.new()
				var frame_style := StyleBoxFlat.new()
				frame_style.bg_color = Color(0.14, 0.13, 0.12, 0.92)
				frame_style.set_border_width_all(1)
				frame_style.border_color = Color(0.6, 0.57, 0.5, 0.7)
				frame_style.set_corner_radius_all(6)
				frame_style.set_content_margin_all(6)
				frame.add_theme_stylebox_override("panel", frame_style)
				gallery_row.add_child(frame)

				var frame_box := VBoxContainer.new()
				frame_box.add_theme_constant_override("separation", 4)
				frame.add_child(frame_box)

				var plate := _build_wiki_archive_plate(entry)
				frame_box.add_child(plate)

				var title_lbl := Label.new()
				title_lbl.text = str(entry["title"])
				title_lbl.add_theme_font_size_override("font_size", 11)
				title_lbl.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
				title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				frame_box.add_child(title_lbl)

				var caption_lbl := Label.new()
				caption_lbl.text = str(entry["caption"])
				caption_lbl.add_theme_font_size_override("font_size", 10)
				caption_lbl.add_theme_color_override("font_color", Color(0.66, 0.62, 0.56))
				caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				frame_box.add_child(caption_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 390)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_tab.add_child(scroll)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(740, 420)
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", Color(0.84, 0.8, 0.74))
	body.clear()
	body.append_text(_wiki_html_to_bbcode(_load_wiki_html(page_path, part_name)))
	scroll.add_child(body)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	root.add_child(controls)

	if not page_path.is_empty() and FileAccess.file_exists(page_path):
		var open_external := Button.new()
		open_external.text = "OPEN HTML"
		open_external.custom_minimum_size = Vector2(130, 36)
		open_external.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path(page_path)))
		controls.add_child(open_external)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(130, 36)
	close_btn.pressed.connect(_hide_sub_modal)
	controls.add_child(close_btn)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _get_wiki_gallery_entries(part_name: String, part_type: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if part_type != "weapon" and part_type != "light_weapon":
		return entries

	var slug := _part_name_to_slug(part_name)
	if slug.is_empty():
		return entries

	var table := {
		"autocannon": [
			{"title": "Autocannon Mk.II", "caption": "Adopted from shipyard anti-drone turrets (2066)."},
			{"title": "Feed System Retrofit", "caption": "Borrowed mining belt feed because jam recovery was too slow."},
		],
		"chemical_thrower": [
			{"title": "C-Series Thrower", "caption": "Adopted from refinery purge lances for stable pressure delivery."},
			{"title": "Nozzle Archive", "caption": "Element/nozzle variants documented by safety board teams."},
		],
		"laser": [
			{"title": "Laser Projector Line", "caption": "Adapted from orbital cutter modules for instant travel time."},
			{"title": "Cooling Ring Retrofit", "caption": "Industrial chill loop adoption reduced lens failures."},
		],
		"plasma_gun": [
			{"title": "Plasma Gun P-4", "caption": "Derived from induction injectors when shell logistics collapsed."},
			{"title": "Arc Stabilizer Board", "caption": "Rail-substation control logic repurposed for arc stability."},
		],
		"railgun": [
			{"title": "Railgun Proof Range", "caption": "Freight launch rail lineage selected for anti-armor duty."},
			{"title": "Capacitor Block Stack", "caption": "Subway recovery banks adopted for repeatable surge output."},
		],
		"machinegun": [
			{"title": "L-Pattern Machinegun", "caption": "Convoy pintle design adapted for mech side mounts."},
			{"title": "Receiver Service Chart", "caption": "Cast receiver simplification enabled one-tool field repair."},
		],
		"rocket_pod": [
			{"title": "Rocket Pod Conversion", "caption": "Aircraft hardpoint pod adapted for mech burst salvos."},
			{"title": "Module Matrix", "caption": "Slot standardization enabled rapid mission reconfiguration."},
		],
	}

	var raw_entries: Array = table.get(slug, [])
	for i in raw_entries.size():
		var item := raw_entries[i] as Dictionary
		entries.append({
			"title": str(item.get("title", "Archive Plate")),
			"caption": str(item.get("caption", "Industrial wiki record.")),
			"seed": "%s_%s_%d" % [part_type, slug, i + 1],
			"image_path": "%s/%s/%s_%d.png" % [_WIKI_HF_IMAGES_ROOT, part_type, slug, i + 1],
			"variant": i,
		})

	return entries


func _build_wiki_archive_plate(entry: Dictionary) -> Control:
	var seed := str(entry.get("seed", "archive"))
	var variant := int(entry.get("variant", 0))
	var image_path := str(entry.get("image_path", ""))
	var image_texture := _load_wiki_archive_texture(image_path)

	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(164, 92)
	plate.clip_contents = true
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = _archive_color_from_seed(seed, 0.03, 0.2)
	plate_style.set_corner_radius_all(4)
	plate_style.set_border_width_all(1)
	plate_style.border_color = _archive_color_from_seed(seed, 0.25, 0.5)
	plate_style.set_content_margin_all(0)
	plate.add_theme_stylebox_override("panel", plate_style)

	var bg := ColorRect.new()
	bg.color = _archive_color_from_seed(seed, 0.10, 0.3)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.add_child(bg)

	var strip := ColorRect.new()
	strip.color = _archive_color_from_seed(seed, 0.18, 0.55)
	strip.position = Vector2(-20, 16 + 10 * (variant % 2))
	strip.size = Vector2(210, 18)
	strip.rotation = -0.08 if variant % 2 == 0 else 0.06
	plate.add_child(strip)

	var sprite_layer := Control.new()
	sprite_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_layer.clip_contents = true
	plate.add_child(sprite_layer)

	if image_texture != null:
		var wiki_image := TextureRect.new()
		wiki_image.texture = image_texture
		wiki_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wiki_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wiki_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		wiki_image.custom_minimum_size = Vector2(164, 92)
		sprite_layer.add_child(wiki_image)
	else:
		var missing := Label.new()
		missing.text = "MISSING HF IMAGE"
		missing.add_theme_font_size_override("font_size", 11)
		missing.add_theme_color_override("font_color", Color(0.95, 0.8, 0.62, 0.9))
		missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sprite_layer.add_child(missing)

	var footer := ColorRect.new()
	footer.color = Color(0.05, 0.05, 0.05, 0.45)
	footer.position = Vector2(0, 70)
	footer.size = Vector2(164, 22)
	plate.add_child(footer)

	return plate


func _load_wiki_archive_texture(image_path: String) -> Texture2D:
	if image_path.is_empty():
		return null

	if not FileAccess.file_exists(image_path):
		return null

	var file := FileAccess.open(image_path, FileAccess.READ)
	if file == null:
		return null
	var header := file.get_buffer(12)
	file.close()

	if not _is_supported_wiki_image(header):
		return null

	var bytes := FileAccess.get_file_as_bytes(image_path)
	if bytes.is_empty():
		return null

	var img := Image.new()
	var err := ERR_FILE_CORRUPT

	if _is_png_signature(header):
		err = img.load_png_from_buffer(bytes)
	elif _is_jpeg_signature(header):
		err = img.load_jpg_from_buffer(bytes)
	elif _is_webp_signature(header):
		err = img.load_webp_from_buffer(bytes)
	if err != OK:
		return null

	return ImageTexture.create_from_image(img)


func _is_supported_wiki_image(header: PackedByteArray) -> bool:
	return _is_png_signature(header) or _is_jpeg_signature(header) or _is_webp_signature(header)


func _is_png_signature(header: PackedByteArray) -> bool:
	if header.size() < 8:
		return false
	var png_sig := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	for i in png_sig.size():
		if header[i] != png_sig[i]:
			return false
	return true


func _is_jpeg_signature(header: PackedByteArray) -> bool:
	if header.size() < 3:
		return false
	return header[0] == 255 and header[1] == 216 and header[2] == 255


func _is_webp_signature(header: PackedByteArray) -> bool:
	if header.size() < 12:
		return false
	var riff := header[0] == 82 and header[1] == 73 and header[2] == 70 and header[3] == 70
	var webp := header[8] == 87 and header[9] == 69 and header[10] == 66 and header[11] == 80
	return riff and webp


func _archive_color_from_seed(seed: String, hue_shift: float, value: float) -> Color:
	var h := fposmod(float(abs(hash(seed))) * 0.00000019 + hue_shift, 1.0)
	return Color.from_hsv(h, 0.45, value, 1.0)


func _load_wiki_html(page_path: String, part_name: String) -> String:
	if page_path.is_empty() or not FileAccess.file_exists(page_path):
		return "<h1>%s</h1><p>No wiki page found yet.</p><p>Create a page at <b>assets/wiki/</b> to document this part.</p>" % part_name

	var file := FileAccess.open(page_path, FileAccess.READ)
	if file == null:
		return "<h1>%s</h1><p>Wiki page exists but could not be loaded.</p>" % part_name
	return file.get_as_text()


func _wiki_html_to_bbcode(html: String) -> String:
	var text := html.replace("\r", "")

	text = text.replace("<br>", "\n")
	text = text.replace("<br/>", "\n")
	text = text.replace("<br />", "\n")

	text = text.replace("<h1>", "[b]")
	text = text.replace("</h1>", "[/b]\n")
	text = text.replace("<h2>", "[b]")
	text = text.replace("</h2>", "[/b]\n")
	text = text.replace("<h3>", "[b]")
	text = text.replace("</h3>", "[/b]\n")

	text = text.replace("<p>", "")
	text = text.replace("</p>", "\n\n")
	text = text.replace("<ul>", "")
	text = text.replace("</ul>", "\n")
	text = text.replace("<ol>", "")
	text = text.replace("</ol>", "\n")
	text = text.replace("<li>", "• ")
	text = text.replace("</li>", "\n")

	text = text.replace("<strong>", "[b]")
	text = text.replace("</strong>", "[/b]")
	text = text.replace("<b>", "[b]")
	text = text.replace("</b>", "[/b]")
	text = text.replace("<em>", "[i]")
	text = text.replace("</em>", "[/i]")
	text = text.replace("<i>", "[i]")
	text = text.replace("</i>", "[/i]")
	text = text.replace("<u>", "[u]")
	text = text.replace("</u>", "[/u]")

	var strip_tags_regex := RegEx.new()
	strip_tags_regex.compile("<[^>]+>")
	text = strip_tags_regex.sub(text, "", true)

	text = text.replace("&nbsp;", " ")
	text = text.replace("&amp;", "&")
	text = text.replace("&lt;", "<")
	text = text.replace("&gt;", ">")
	text = text.replace("&quot;", '"')
	text = text.replace("&#39;", "'")

	var excess_newlines := RegEx.new()
	excess_newlines.compile("\n{3,}")
	text = excess_newlines.sub(text, "\n\n", true)

	return text.strip_edges()


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
	_record_step()
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
	_record_step()
	_hide_sub_modal()


func _show_thrower_nozzle_modal(gun: WeaponData) -> void:
	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(vbox)

	var title := Label.new()
	title.text = "NOZZLE SHAPE - %s" % gun.name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	vbox.add_child(sep)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var nozzles: Array[Dictionary] = [
		{"type": WeaponData.ThrowerNozzle.LONG_NOZZLE, "label": "LONG NOZZLE", "desc": "Focused stream, longer range", "icon_path": _NOZZLE_LONG_ICON_PATH},
		{"type": WeaponData.ThrowerNozzle.NOZZLE, "label": "NOZZLE", "desc": "Balanced spread", "icon_path": _NOZZLE_STANDARD_ICON_PATH},
		{"type": WeaponData.ThrowerNozzle.WIDE_NOZZLE, "label": "WIDE NOZZLE", "desc": "Huge spread, short range", "icon_path": _NOZZLE_WIDE_ICON_PATH},
	]

	for entry in nozzles:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)

		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(120, 92)
		btn.pressed.connect(_on_thrower_nozzle_selected.bind(entry["type"], gun))
		col.add_child(btn)

		var selected: bool = gun.thrower_nozzle == entry["type"]
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.22, 0.22, 0.24, 0.96) if selected else Color(0.12, 0.12, 0.14, 0.96)
		normal_style.border_color = Color(0.93, 0.20, 0.20, 1.0) if selected else Color(0.34, 0.36, 0.42, 0.9)
		normal_style.set_border_width_all(2)
		normal_style.set_corner_radius_all(8)
		normal_style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style := normal_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.18, 0.18, 0.22, 0.98)
		hover_style.border_color = Color(0.85, 0.85, 0.92, 1.0) if not selected else Color(0.93, 0.20, 0.20, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := normal_style.duplicate() as StyleBoxFlat
		pressed_style.bg_color = Color(0.24, 0.24, 0.28, 1.0)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		var icon := TextureRect.new()
		var icon_path := String(entry["icon_path"])
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(90, 52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		var lbl := Label.new()
		lbl.text = entry["label"]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.86, 0.84, 0.8))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)

		var desc := Label.new()
		desc.text = entry["desc"]
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color(0.62, 0.6, 0.55))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(124, 0)
		col.add_child(desc)

	_sub_modal_open_frame = Engine.get_process_frames()
	_sub_modal_overlay.set_deferred("visible", true)


func _on_thrower_nozzle_selected(selected_nozzle: WeaponData.ThrowerNozzle, gun: WeaponData) -> void:
	gun.thrower_nozzle = selected_nozzle
	_record_step()
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
	_record_step()
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
	_record_step()
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
	_missile_fire_mode_buttons.clear()

	for child in _sub_modal_panel.get_children():
		_sub_modal_panel.remove_child(child)
		child.free()

	var root := VBoxContainer.new()
	var viewport_size := get_viewport_rect().size
	root.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 72.0, 560.0, 1080.0),
		clampf(viewport_size.y - 72.0, 500.0, 720.0)
	)
	root.add_theme_constant_override("separation", 14)
	_sub_modal_panel.add_child(root)

	var title := Label.new()
	title.text = "ROCKET POD / ORDNANCE DESIGN BENCH / %s" % gun.name.to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.72, 0.28))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	root.add_child(sep)

	var body: BoxContainer = VBoxContainer.new() if viewport_size.x < 900.0 else HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var parts_panel := PanelContainer.new()
	parts_panel.custom_minimum_size = Vector2(286, 170)
	parts_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	var parts_scroll := ScrollContainer.new()
	parts_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_vbox.add_child(parts_scroll)

	var parts_list := VBoxContainer.new()
	parts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_list.add_theme_constant_override("separation", 7)
	parts_scroll.add_child(parts_list)

	for part_id in ["fuel", "explosive", "cluster", "proximity_trigger", "wire_guided", "homing"]:
		var def: Dictionary = _MISSILE_PART_DEFS[part_id]
		var card: Control = _MISSILE_BUILDER_PART_CARD_SCRIPT.new()
		card.setup(part_id, def.get("title", "Part"), def.get("desc", ""), int(def.get("cost", 1)))
		card.drag_started.connect(_on_missile_part_drag_started)
		card.drag_finished.connect(_on_missile_part_drag_finished)
		parts_list.add_child(card)

	var parts_hint := Label.new()
	parts_hint.text = "MICRO THRUSTER + INITIATOR ARE BUILT IN\nDrag upgrades into bays. Click a module to remove it."
	parts_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parts_hint.add_theme_font_size_override("font_size", 11)
	parts_hint.add_theme_color_override("font_color", Color(0.68, 0.65, 0.54))
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
	missile_title.text = "LIVE CUTAWAY / 6 MODULAR BAYS"
	missile_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	missile_title.add_theme_font_size_override("font_size", 14)
	missile_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	builder_vbox.add_child(missile_title)

	_missile_builder_preview = _MISSILE_BUILDER_PREVIEW_SCRIPT.new()
	_missile_builder_preview.setup(_can_place_missile_part)
	_missile_builder_preview.part_dropped.connect(_on_missile_part_dropped)
	_missile_builder_preview.slot_clicked.connect(_on_missile_slot_clicked)
	_missile_builder_preview.drag_target_changed.connect(_on_missile_drag_target_changed)
	builder_vbox.add_child(_missile_builder_preview)
	_missile_slot_zones.clear()
	_missile_slot_zones.assign(_missile_builder_preview.slot_zones)

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

	var fire_control := HBoxContainer.new()
	fire_control.alignment = BoxContainer.ALIGNMENT_CENTER
	fire_control.add_theme_constant_override("separation", 0)
	builder_vbox.add_child(fire_control)

	var fire_label := Label.new()
	fire_label.text = "FIRE CONTROL  "
	fire_label.add_theme_font_size_override("font_size", 12)
	fire_label.add_theme_color_override("font_color", Color(0.5, 0.82, 0.84))
	fire_control.add_child(fire_label)

	for mode in [WeaponData.MissileFireMode.SINGLE, WeaponData.MissileFireMode.TRIPLE, WeaponData.MissileFireMode.ALL_AMMO]:
		var mode_button := Button.new()
		mode_button.text = _get_missile_fire_mode_label(mode)
		mode_button.toggle_mode = true
		mode_button.custom_minimum_size = Vector2(104, 34)
		mode_button.pressed.connect(_on_missile_fire_mode_selected.bind(mode))
		fire_control.add_child(mode_button)
		_missile_fire_mode_buttons[mode] = mode_button

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


func _on_missile_part_drag_started(part_id: String, slot_cost: int) -> void:
	if _missile_builder_preview:
		_missile_builder_preview.set_dragged_part(part_id, slot_cost)
	if _missile_builder_status_label:
		_missile_builder_status_label.text = "ROUTING %s / SELECT A GLOWING BAY" % part_id.to_upper().replace("_", " ")
		_missile_builder_status_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.86))


func _on_missile_part_drag_finished(part_id: String, successful: bool) -> void:
	if _missile_builder_preview:
		_missile_builder_preview.clear_dragged_part()
	if not successful and _missile_builder_status_label:
		_missile_builder_status_label.text = "%s RETURNED TO PARTS TRAY" % part_id.to_upper().replace("_", " ")
		_missile_builder_status_label.add_theme_color_override("font_color", Color(0.95, 0.62, 0.28))


func _on_missile_drag_target_changed(part_id: String, slot_index: int, valid: bool) -> void:
	if _missile_builder_status_label == null:
		return
	_missile_builder_status_label.text = "%s / BAY %02d / %s" % [
		part_id.to_upper().replace("_", " "),
		slot_index + 1,
		"READY TO INSTALL" if valid else "BAY INCOMPATIBLE",
	]
	_missile_builder_status_label.add_theme_color_override(
		"font_color", Color(0.45, 0.95, 0.86) if valid else Color(1.0, 0.34, 0.24)
	)


func _on_missile_fire_mode_selected(mode: WeaponData.MissileFireMode) -> void:
	if _missile_builder_weapon == null:
		return
	_missile_builder_weapon.missile_fire_mode = mode
	_record_step()
	_refresh_missile_builder_view()
	_refresh_ui()


func _get_missile_fire_mode_label(mode: WeaponData.MissileFireMode) -> String:
	match mode:
		WeaponData.MissileFireMode.SINGLE:
			return "SINGLE"
		WeaponData.MissileFireMode.ALL_AMMO:
			return "ALL AMMO"
		_:
			return "TRIPLE"


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
	_record_step()
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
	_record_step()
	_refresh_missile_builder_view()


func _on_missile_builder_clear() -> void:
	if _missile_builder_weapon == null:
		return
	_missile_builder_layout = _normalize_missile_layout([])
	_apply_missile_builder_to_weapon()
	_record_step()
	_refresh_missile_builder_view()


func _refresh_missile_builder_view() -> void:
	_missile_builder_layout = _normalize_missile_layout(_missile_builder_layout)
	if _missile_builder_preview:
		_missile_builder_preview.set_layout(_missile_builder_layout)
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
			"cluster":
				zone.set_display("C", Color(0.84, 0.42, 1.0), true, false)
			"proximity_trigger":
				zone.set_display("P", Color(0.35, 0.95, 0.88), true, false)
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
		var payloads: Array[String] = ["BASELINE FUEL", "LIVE INITIATOR"]
		if _missile_builder_weapon.missile_has_cluster:
			payloads.append("CLUSTER x%d" % RocketProjectile.CLUSTER_EXPLOSION_COUNT)
		if _missile_builder_weapon.missile_has_proximity_trigger:
			payloads.append("PROXIMITY FUSE")
		_missile_builder_stats_label.text = "THRUST %.0f  |  RANGE %.0f px  |  YIELD %d  |  BLAST %.2f\n%s" % [
			speed,
			range_px,
			_missile_builder_weapon.damage,
			_missile_builder_weapon.area,
			"  /  ".join(payloads),
		]
		for mode in _missile_fire_mode_buttons:
			var button := _missile_fire_mode_buttons[mode] as Button
			button.set_pressed_no_signal(mode == _missile_builder_weapon.missile_fire_mode)


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
	_record_step()
	call_deferred("_show_attachment_modal", gun)
