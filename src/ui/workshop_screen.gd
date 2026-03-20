# workshop_screen.gd — Flow-based Workshop: Movement → Torso → Weapon
# Step 1 shows the movement parts list.  Steps 2+ start with a clickable [+]
# slot on the mech preview.  Clicking the slot opens the parts list.
# Left / Right arrows navigate steps.
#
# ARCHITECTURE NOTE — Slot-driven design, future multi-weapon support:
# Each slot-based step (torso, weapon, …) follows the same pattern:
#   1. Enter step → parts list HIDDEN, slot button VISIBLE on preview
#   2. Click slot  → parts list VISIBLE, slot button HIDDEN
#   3. Pick part   → slot filled, parts list stays for re-pick
# To add more weapon slots, duplicate the weapon slot logic and give each
# slot its own position callback and selection index.
extends Control

signal deploy_pressed(loadout: MechLoadout)

# ── Flow steps ────────────────────────────────────────────────────────────────
enum Step { MOVEMENT, TORSO, WEAPON }

const STEP_COUNT := 3
const STEP_TITLES: Array[String] = [
	"STEP 1: CHOOSE MOVEMENT",
	"STEP 2: CHOOSE TORSO",
	"STEP 3: CHOOSE WEAPON",
]
const STEP_HINTS: Array[String] = [
	"Select a movement system for your mech",
	"Click the [+] slot on the mech to choose a torso",
	"Click the [+] slot on the mech to mount a weapon",
]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _step_label:     Label            = %StepLabel
@onready var _parts_panel:    VBoxContainer     = %PartsPanel
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

var _current_step: Step = Step.MOVEMENT
var _part_buttons: Array[Button] = []

var _selected_leg_index:   int = -1
var _selected_torso_index: int = -1
var _selected_gun_index:   int = -1

## Whether the parts list is showing for the current step.
## false = slot-prompt mode (hint label + slot button visible).
var _parts_list_open: bool = false

# ── Preview texture layers ────────────────────────────────────────────────────
var _legs_rect:   TextureRect = null
var _torso_rect:  TextureRect = null
var _weapon_rect: TextureRect = null

# Clickable slot buttons overlayed on the preview
var _torso_slot_btn:  Button = null
var _weapon_slot_btn: Button = null

# Per-weapon sprite correction — mirrors rotation_degrees in weapon .tscn scenes.
var _weapon_sprite_correction: float = 0.0
var _weapon_mount_offset: Vector2 = Vector2.ZERO

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_all_legs   = MechCatalog.get_all_legs()
	_all_torsos = MechCatalog.get_all_torsos()
	_all_guns   = MechCatalog.get_all_guns()

	_build_preview_layers()
	_build_slot_buttons()

	_left_arrow.pressed.connect(_on_left_arrow)
	_right_arrow.pressed.connect(_on_right_arrow)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	_deploy_button.disabled = true
	_deploy_button.visible  = false

	_go_to_step(Step.MOVEMENT)

func _process(_delta: float) -> void:
	if _preview_stack == null or _torso_rect == null:
		return
	var half := _preview_stack.size * 0.5
	_torso_rect.pivot_offset = half
	_weapon_rect.pivot_offset = _weapon_rect.size * 0.5
	var center := _preview_stack.global_position + half
	var mouse  := get_viewport().get_mouse_position()
	if center.distance_to(mouse) < 20.0:
		return
	var angle := (mouse - center).angle()
	_torso_rect.rotation = angle
	_update_slot_positions()

# ── Preview layer construction ────────────────────────────────────────────────

func _build_preview_layers() -> void:
	_legs_rect   = _make_preview_rect()
	_torso_rect  = _make_preview_rect()
	_weapon_rect = _make_preview_rect()

	for rect in [_legs_rect, _torso_rect]:
		_preview_stack.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.modulate.a = 0.0

	_torso_rect.add_child(_weapon_rect)
	_weapon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapon_rect.modulate.a = 0.0

func _make_preview_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# ── Clickable slot buttons on the preview ─────────────────────────────────────
# Each slot is a Button overlayed on the mech preview.  Slots appear when the
# user reaches a step whose part hasn't been picked yet, prompting them to
# "click to equip".  This pattern is intentionally easy to duplicate — adding
# a second weapon slot only requires another Button + position callback.

func _build_slot_buttons() -> void:
	_torso_slot_btn  = _create_slot_button("+ TORSO")
	_weapon_slot_btn = _create_slot_button("+ WEAPON")
	_preview_stack.add_child(_torso_slot_btn)
	_preview_stack.add_child(_weapon_slot_btn)
	_torso_slot_btn.pressed.connect(_on_slot_clicked.bind(Step.TORSO))
	_weapon_slot_btn.pressed.connect(_on_slot_clicked.bind(Step.WEAPON))
	_torso_slot_btn.visible  = false
	_weapon_slot_btn.visible = false

func _create_slot_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 44)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.5, 1.0))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.1, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.95, 0.7, 0.2, 0.8)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(0.25, 0.18, 0.1, 0.95)
	hover_style.border_color = Color(1.0, 0.85, 0.3, 1.0)
	hover_style.shadow_color = Color(0.95, 0.7, 0.2, 0.4)
	hover_style.shadow_size = 6
	btn.add_theme_stylebox_override("hover", hover_style)
	return btn

func _update_slot_positions() -> void:
	var half := _preview_stack.size * 0.5
	if _torso_slot_btn and _torso_slot_btn.visible:
		_torso_slot_btn.position = half - _torso_slot_btn.size * 0.5
	if _weapon_slot_btn and _weapon_slot_btn.visible:
		var mount := half + _weapon_mount_offset
		_weapon_slot_btn.position = mount - _weapon_slot_btn.size * 0.5

## Generic slot-click handler.  Opens the parts list for the given step.
func _on_slot_clicked(step: Step) -> void:
	_open_parts_list(step)

# ── Flow navigation ───────────────────────────────────────────────────────────

func _go_to_step(step: Step) -> void:
	_current_step = step
	var step_num := step + 1
	_step_label.text     = STEP_TITLES[step]
	_step_indicator.text = "%d / %d" % [step_num, STEP_COUNT]

	# Arrow visibility / enabled state
	_left_arrow.visible  = step > Step.MOVEMENT
	_left_arrow.disabled = step == Step.MOVEMENT
	_right_arrow.visible  = step < Step.WEAPON
	_right_arrow.disabled = not _is_step_complete(step)

	# Deploy button — only on last step when loadout is complete
	_deploy_button.visible  = step == Step.WEAPON and _loadout.is_valid()
	_deploy_button.disabled = not _loadout.is_valid()

	# Decide whether to show the parts list or the slot prompt
	_enter_step(step)
	_update_selection_info()
	_update_stats_preview()

func _is_step_complete(step: Step) -> bool:
	match step:
		Step.MOVEMENT: return _loadout.selected_legs  != null
		Step.TORSO:    return _loadout.selected_torso  != null
		Step.WEAPON:   return _loadout.selected_gun    != null
	return false

func _on_left_arrow() -> void:
	if _current_step > Step.MOVEMENT:
		_go_to_step((_current_step - 1) as Step)

func _on_right_arrow() -> void:
	if _current_step < Step.WEAPON and _is_step_complete(_current_step):
		_go_to_step((_current_step + 1) as Step)

# ── Step entry logic — slot vs. parts list ────────────────────────────────────

## Called when navigating to a step.  Decides between showing the slot prompt
## (part not yet picked) or the parts list (already picked / movement step).
func _enter_step(step: Step) -> void:
	match step:
		Step.MOVEMENT:
			# Movement always shows the parts list — no slot button needed.
			_show_parts_list()
			_build_leg_parts()
			_torso_slot_btn.visible  = false
			_weapon_slot_btn.visible = false

		Step.TORSO:
			_weapon_slot_btn.visible = false
			if _loadout.selected_torso != null:
				# Already picked — show list so user can re-pick.
				_show_parts_list()
				_build_torso_parts()
				_torso_slot_btn.visible = false
			else:
				# Not picked — show slot button, hide parts list.
				_show_slot_prompt()
				_torso_slot_btn.visible = true
				_update_slot_positions()

		Step.WEAPON:
			_torso_slot_btn.visible = false
			if _loadout.selected_gun != null:
				_show_parts_list()
				_build_weapon_parts()
				_weapon_slot_btn.visible = false
			else:
				_show_slot_prompt()
				_weapon_slot_btn.visible = true
				_update_slot_positions()

## Opens the parts list after a slot button is clicked.
func _open_parts_list(step: Step) -> void:
	_show_parts_list()
	match step:
		Step.TORSO:
			_torso_slot_btn.visible = false
			_build_torso_parts()
			_selection_info.text = "Choose a torso for your mech"
		Step.WEAPON:
			_weapon_slot_btn.visible = false
			_build_weapon_parts()
			_selection_info.text = "Choose a weapon to mount"

# ── Parts panel visibility helpers ────────────────────────────────────────────

## Show the scrollable parts list, hide the "click the slot" hint.
func _show_parts_list() -> void:
	_parts_list_open   = true
	_parts_scroll.visible = true
	_slot_hint.visible    = false

## Hide the parts list and show the slot-click hint.
func _show_slot_prompt() -> void:
	_parts_list_open   = false
	_clear_parts()
	_parts_scroll.visible = false
	_slot_hint.visible    = true

# ── Build parts lists ─────────────────────────────────────────────────────────

func _build_leg_parts() -> void:
	_clear_parts()
	_parts_label.text = "MOVEMENT"
	for i in _all_legs.size():
		var leg := _all_legs[i]
		var btn := _create_part_button(leg.name, leg.tutorial_text, i == _selected_leg_index)
		btn.pressed.connect(_on_leg_selected.bind(i))
		_parts_box.add_child(btn)
		_part_buttons.append(btn)

func _build_torso_parts() -> void:
	_clear_parts()
	_parts_label.text = "TORSOS"
	for i in _all_torsos.size():
		var torso := _all_torsos[i]
		var btn := _create_part_button(torso.name, torso.tutorial_text, i == _selected_torso_index)
		btn.pressed.connect(_on_torso_selected.bind(i))
		_parts_box.add_child(btn)
		_part_buttons.append(btn)

func _build_weapon_parts() -> void:
	_clear_parts()
	_parts_label.text = "WEAPONS"
	for i in _all_guns.size():
		var gun := _all_guns[i]
		var desc := "DMG: %d  |  CD: %.1fs  |  Proj: %d  |  Pierce: %d" % [
			gun.damage, gun.cooldown, gun.projectile_count, gun.pierce]
		var btn := _create_part_button(gun.name, desc, i == _selected_gun_index)
		btn.pressed.connect(_on_gun_selected.bind(i))
		_parts_box.add_child(btn)
		_part_buttons.append(btn)

func _clear_parts() -> void:
	for child in _parts_box.get_children():
		child.queue_free()
	_part_buttons.clear()

# ── Part button factory ───────────────────────────────────────────────────────

func _create_part_button(title: String, desc: String, is_selected: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size    = Vector2(0, 80)
	btn.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	btn.text                   = title + "\n" + desc
	btn.autowrap_mode          = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color",       Color(0.85, 0.8, 0.7, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	btn.add_theme_stylebox_override("normal", _selected_stylebox() if is_selected else _normal_stylebox())
	btn.add_theme_stylebox_override("hover",  _selected_stylebox())
	return btn

func _normal_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.35, 0.3, 0.6)
	style.set_corner_radius_all(8)
	return style

func _selected_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.1, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(0.95, 0.7, 0.2, 1.0)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.95, 0.7, 0.2, 0.3)
	style.shadow_size  = 4
	return style

# ── Part selection handlers ────────────────────────────────────────────────────

func _on_leg_selected(index: int) -> void:
	_selected_leg_index    = index
	_loadout.selected_legs = _all_legs[index]
	_build_leg_parts()
	_update_preview_layer(_legs_rect, _loadout.selected_legs.get_sprite_path())
	_selection_info.text = _loadout.selected_legs.name + " selected — press NEXT >"
	_right_arrow.disabled = false
	_update_stats_preview()

func _on_torso_selected(index: int) -> void:
	_selected_torso_index    = index
	_loadout.selected_torso  = _all_torsos[index]
	_build_torso_parts()
	_update_preview_layer(_torso_rect, _loadout.selected_torso.get_sprite_path())
	_update_weapon_mount_offset()
	_torso_slot_btn.visible = false
	_selection_info.text = _loadout.selected_torso.name + " mounted — press NEXT >"
	if _current_step == Step.TORSO:
		_right_arrow.disabled = false
	_update_stats_preview()

func _on_gun_selected(index: int) -> void:
	_selected_gun_index   = index
	_loadout.selected_gun = _all_guns[index]
	_build_weapon_parts()
	_update_preview_layer(_weapon_rect, _loadout.selected_gun.get_sprite_path())
	match _loadout.selected_gun.weapon_type:
		WeaponData.WeaponType.AUTOCANNON, WeaponData.WeaponType.FLAMETHROWER:
			_weapon_sprite_correction = deg_to_rad(-90.0)
		_:
			_weapon_sprite_correction = 0.0
	_weapon_rect.rotation = _weapon_sprite_correction
	_weapon_slot_btn.visible = false
	_selection_info.text = _loadout.selected_gun.name + " armed — ready to DEPLOY!"
	_deploy_button.visible  = true
	_deploy_button.disabled = not _loadout.is_valid()
	_update_stats_preview()

# ── Preview helpers ────────────────────────────────────────────────────────────

func _update_preview_layer(rect: TextureRect, path: String) -> void:
	var tex: Texture2D = load(path)
	if tex:
		rect.texture    = tex
		rect.modulate.a = 1.0
	else:
		rect.modulate.a = 0.0

func _update_weapon_mount_offset() -> void:
	if _loadout.selected_torso == null:
		_weapon_mount_offset = Vector2.ZERO
		return
	var raw_offset: Vector2
	match _loadout.selected_torso.torso_type:
		TorsoData.TorsoType.HEAVY_ARMOUR: raw_offset = Vector2(4.0,  17.0)
		TorsoData.TorsoType.STEALTH:      raw_offset = Vector2(10.0,  0.0)
		TorsoData.TorsoType.CARGO:        raw_offset = Vector2(-17.0, 0.0)
		_:                                raw_offset = Vector2.ZERO
	var scale_factor := _preview_stack.size.x / 64.0 if _preview_stack.size.x > 0 else 1.0
	_weapon_mount_offset = raw_offset * scale_factor
	_weapon_rect.position = _weapon_mount_offset

# ── Info / Stats / Deploy ─────────────────────────────────────────────────────

func _update_selection_info() -> void:
	_selection_info.text = STEP_HINTS[_current_step]

func _update_stats_preview() -> void:
	if not _stats_label:
		return
	if not _loadout.is_valid():
		var missing: Array[String] = []
		if _loadout.selected_legs  == null: missing.append("Legs")
		if _loadout.selected_torso == null: missing.append("Torso")
		if _loadout.selected_gun   == null: missing.append("Weapon")
		_stats_label.text = "Still needed: " + "  ·  ".join(missing)
		return
	var preview_stats := PlayerStats.new()
	_loadout.apply_to_stats(preview_stats)
	var integrity_str := "◆".repeat(preview_stats.max_integrity)
	_stats_label.text = "%s  |  Speed: %.0f  |  %s  +  %s  +  %s  (DMG: %d)" % [
		integrity_str,
		preview_stats.speed,
		_loadout.selected_legs.name,
		_loadout.selected_torso.name,
		_loadout.selected_gun.name,
		_loadout.selected_gun.damage,
	]

func _on_deploy_pressed() -> void:
	_deploy_button.disabled = true
	GameManager.current_loadout = _loadout
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(_go_to_game)

func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_select_screen.tscn")
