# workshop_screen.gd — Workshop: choose category → choose part → live mech preview
extends Control

signal deploy_pressed(loadout: MechLoadout)

# ── Categories ────────────────────────────────────────────────────────────────
enum Category { LEGS, TORSO, WEAPON }

# Names and enum values for all categories.
# Add more entries here to expand the category list (scroll handles overflow).
const CATEGORIES: Array = [
	["LEGS",   Category.LEGS],
	["TORSO",  Category.TORSO],
	["WEAPON", Category.WEAPON],
]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _category_box: VBoxContainer = %CategoryBox
@onready var _parts_box:    VBoxContainer = %PartsBox
@onready var _preview_stack: Control      = %PreviewStack
@onready var _selection_info: Label       = %SelectionInfo
@onready var _stats_label:   Label        = %StatsLabel
@onready var _deploy_button: Button       = %DeployButton

# ── State ─────────────────────────────────────────────────────────────────────
var _loadout := MechLoadout.new()
var _all_legs:   Array[LegData]    = []
var _all_torsos: Array[TorsoData]  = []
var _all_guns:   Array[WeaponData] = []

var _current_category: Category = Category.LEGS
var _category_buttons: Array[Button] = []
var _part_buttons:     Array[Button] = []

var _selected_leg_index:   int = -1
var _selected_torso_index: int = -1
var _selected_gun_index:   int = -1

# ── Preview texture layers ────────────────────────────────────────────────────
var _legs_rect:   TextureRect = null
var _torso_rect:  TextureRect = null
var _weapon_rect: TextureRect = null

func _ready() -> void:
	_all_legs   = MechCatalog.get_all_legs()
	_all_torsos = MechCatalog.get_all_torsos()
	_all_guns   = MechCatalog.get_all_guns()
	_build_preview_layers()
	_build_category_buttons()
	_select_category(Category.LEGS)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	_deploy_button.disabled = true
	_update_stats_preview()

# ── Preview layer construction ────────────────────────────────────────────────

func _build_preview_layers() -> void:
	_legs_rect   = _make_preview_rect()
	_torso_rect  = _make_preview_rect()
	_weapon_rect = _make_preview_rect()
	for rect in [_legs_rect, _torso_rect, _weapon_rect]:
		_preview_stack.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.modulate.a = 0.0

func _make_preview_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# ── Category button list ───────────────────────────────────────────────────────

func _build_category_buttons() -> void:
	for child in _category_box.get_children():
		child.queue_free()
	_category_buttons.clear()
	for entry in CATEGORIES:
		var cat_name: String   = entry[0]
		var cat_id:   Category = entry[1]
		var btn := _create_category_button(cat_name)
		btn.pressed.connect(_select_category.bind(cat_id))
		_category_box.add_child(btn)
		_category_buttons.append(btn)

func _create_category_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color      = Color(0.1, 0.12, 0.16, 0.9)
	style.border_width_bottom = 2
	style.border_color  = Color(0.3, 0.35, 0.45, 0.5)
	btn.add_theme_stylebox_override("normal", style)
	var style_hover: StyleBoxFlat = style.duplicate()
	style_hover.bg_color     = Color(0.15, 0.16, 0.22, 0.95)
	style_hover.border_color = Color(0.85, 0.6, 0.2, 0.8)
	btn.add_theme_stylebox_override("hover", style_hover)
	return btn

# ── Category selection ─────────────────────────────────────────────────────────

func _select_category(cat: Category) -> void:
	_current_category = cat
	_highlight_category(cat)
	_build_parts_for_category(cat)

func _highlight_category(active_cat: Category) -> void:
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.18, 0.14, 0.1, 0.95)
	active_style.border_width_bottom = 3
	active_style.border_color = Color(0.95, 0.7, 0.2, 1.0)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.3, 0.35, 0.45, 0.5)

	for i in _category_buttons.size():
		var btn: Button = _category_buttons[i]
		if CATEGORIES[i][1] == active_cat:
			btn.add_theme_stylebox_override("normal", active_style.duplicate())
			btn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
			btn.add_theme_font_size_override("font_size", 22)
		else:
			btn.add_theme_stylebox_override("normal", normal_style.duplicate())
			btn.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
			btn.add_theme_font_size_override("font_size", 20)

# ── Parts list for the active category ───────────────────────────────────────

func _build_parts_for_category(cat: Category) -> void:
	for child in _parts_box.get_children():
		child.queue_free()
	_part_buttons.clear()

	match cat:
		Category.LEGS:
			for i in _all_legs.size():
				var leg := _all_legs[i]
				var btn := _create_part_button(leg.name, leg.tutorial_text, i == _selected_leg_index)
				btn.pressed.connect(_on_leg_selected.bind(i))
				_parts_box.add_child(btn)
				_part_buttons.append(btn)

		Category.TORSO:
			for i in _all_torsos.size():
				var torso := _all_torsos[i]
				var btn := _create_part_button(torso.name, torso.tutorial_text, i == _selected_torso_index)
				btn.pressed.connect(_on_torso_selected.bind(i))
				_parts_box.add_child(btn)
				_part_buttons.append(btn)

		Category.WEAPON:
			for i in _all_guns.size():
				var gun := _all_guns[i]
				var desc := "DMG: %d  |  CD: %.1fs  |  Proj: %d  |  Pierce: %d" % [
					gun.damage, gun.cooldown, gun.projectile_count, gun.pierce]
				var btn := _create_part_button(gun.name, desc, i == _selected_gun_index)
				btn.pressed.connect(_on_gun_selected.bind(i))
				_parts_box.add_child(btn)
				_part_buttons.append(btn)

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
	_build_parts_for_category(Category.LEGS)
	_update_preview_layer(_legs_rect, _loadout.selected_legs.get_sprite_path())
	_selection_info.text = _loadout.selected_legs.name + " added to preview"
	_update_deploy_state()
	_update_stats_preview()

func _on_torso_selected(index: int) -> void:
	_selected_torso_index    = index
	_loadout.selected_torso  = _all_torsos[index]
	_build_parts_for_category(Category.TORSO)
	_update_preview_layer(_torso_rect, _loadout.selected_torso.get_sprite_path())
	_selection_info.text = _loadout.selected_torso.name + " added to preview"
	_update_deploy_state()
	_update_stats_preview()

func _on_gun_selected(index: int) -> void:
	_selected_gun_index   = index
	_loadout.selected_gun = _all_guns[index]
	_build_parts_for_category(Category.WEAPON)
	_update_preview_layer(_weapon_rect, _loadout.selected_gun.get_sprite_path())
	_selection_info.text = _loadout.selected_gun.name + " added to preview"
	_update_deploy_state()
	_update_stats_preview()

# ── Preview helpers ────────────────────────────────────────────────────────────

func _update_preview_layer(rect: TextureRect, path: String) -> void:
	var tex: Texture2D = load(path)
	if tex:
		rect.texture   = tex
		rect.modulate.a = 1.0
	else:
		rect.modulate.a = 0.0

# ── Stats / deploy ─────────────────────────────────────────────────────────────

func _update_deploy_state() -> void:
	_deploy_button.disabled = not _loadout.is_valid()

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
	_stats_label.text = "HP: %d  |  Speed: %.0f  |  %s  +  %s  +  %s  (DMG: %d)" % [
		preview_stats.max_health,
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
	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/levels/gameplay.tscn")
