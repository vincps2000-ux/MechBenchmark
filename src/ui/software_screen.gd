# software_screen.gd — Sci-fi weapon keybind configuration screen.
# Appears after Utility Modules, before Level Select.
# Each equipped weapon gets a bind-row: weapon icon + name + rebind button.
# Clicking the rebind button enters "listening" mode — press any key/mouse
# button to assign that input as the weapon's fire trigger.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const _UTILITY_MODULE_DATA_SCRIPT := preload("res://src/player/utility_module_data.gd")
const ACCENT         := Color(0.0, 0.85, 0.95, 1.0)   # Cyan neon
const ACCENT_DIM     := Color(0.0, 0.45, 0.55, 0.7)
const ACCENT_GLOW    := Color(0.0, 0.95, 1.0, 0.35)
const BG_DARK        := Color(0.04, 0.05, 0.08, 0.97)
const BG_CARD        := Color(0.07, 0.09, 0.14, 0.92)
const TEXT_MAIN      := Color(0.82, 0.88, 0.92, 1.0)
const TEXT_DIM       := Color(0.45, 0.52, 0.58, 0.85)
const WARNING_COLOR  := Color(1.0, 0.35, 0.25, 1.0)
const LISTENING_COLOR := Color(1.0, 0.82, 0.0, 1.0)
const GRID_LINE      := Color(0.08, 0.18, 0.22, 0.3)
const LISTEN_TARGET_NONE := 0
const LISTEN_TARGET_UTILITY := 1
const LISTEN_TARGET_WEAPON := 2
const LISTEN_TARGET_MOVEMENT := 3

# ── State ─────────────────────────────────────────────────────────────────────
var _weapon_names: Array[String] = []
var _utility_modules: Array[String] = []
var _utility_bindings: Array[InputEvent] = []
var _bindings: Array[InputEvent] = []
var _movement_bindings: Array[InputEvent] = []
var _movement_indices: Array[int] = []  # Indices of movement bindings used by this mech
var _movement_labels: Array[String] = []  # Labels for those bindings
var _utility_bind_buttons: Array[Button] = []
var _bind_buttons: Array[Button] = []
var _movement_bind_buttons: Array[Button] = []
var _listening_target: int = LISTEN_TARGET_NONE
var _listening_index: int = -1
var _listening_binding_index: int = -1  # Actual binding index for movement (0-5)
var _time: float = 0.0
var _scanline_offset: float = 0.0

# ── Scene refs built in code ──────────────────────────────────────────────────
var _utility_container: VBoxContainer = null
var _weapons_container: VBoxContainer = null
var _movement_container: VBoxContainer = null
var _deploy_button: Button = null
var _back_button: Button = null
var _title_label: Label = null
var _status_label: Label = null
var _grid_overlay: Control = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	modulate.a = 0.0

	_load_weapon_data()
	_build_ui()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)


func _load_weapon_data() -> void:
	var loadout: MechLoadout = GameManager.current_loadout
	if not loadout:
		return

	_utility_modules.clear()
	for module in loadout.selected_utility_modules:
		var module_label := _get_utility_module_label(module)
		if not module_label.is_empty():
			_utility_modules.append(module_label)

	if GameManager.utility_bindings.size() == _utility_modules.size():
		_utility_bindings = GameManager.utility_bindings.duplicate()
	else:
		_utility_bindings = GameManager.get_default_utility_bindings(loadout)

	# Gather weapon names (main guns + light guns)
	for gun in loadout.selected_guns:
		if gun:
			_weapon_names.append(gun.name)
	for gun in loadout.selected_light_guns:
		if gun:
			_weapon_names.append(gun.name)

	# Load existing bindings or generate defaults
	if GameManager.weapon_bindings.size() == _weapon_names.size():
		_bindings = GameManager.weapon_bindings.duplicate()
	else:
		_bindings = GameManager.get_default_bindings(loadout)

	# Load movement bindings (always 6: up, down, left, right, turn_left, turn_right)
	if GameManager.movement_bindings.size() == 6:
		_movement_bindings = GameManager.movement_bindings.duplicate()
	else:
		_movement_bindings = GameManager.get_default_movement_bindings()
	
	# Determine which movement keys this mech uses
	_determine_mech_movement_keys(loadout)


func _determine_mech_movement_keys(loadout: MechLoadout) -> void:
	_movement_indices.clear()
	_movement_labels.clear()
	
	if not loadout or not loadout.selected_legs:
		return
	
	var leg_name := loadout.selected_legs.name.to_lower() if loadout.selected_legs else ""
	
	# Movement binding indices: 0=up, 1=down, 2=left, 3=right, 4=turn_left, 5=turn_right
	# All mechs have: up, down, turn_left, turn_right
	_movement_indices = [0, 1, 4, 5]
	_movement_labels = ["UP", "DOWN", "TURN LEFT", "TURN RIGHT"]
	
	# Spider, Walker, and Legs have strafe (left/right)
	if "spider" in leg_name or "walker" in leg_name or "legs" in leg_name:
		_movement_indices = [0, 1, 2, 3, 4, 5]
		_movement_labels = ["UP", "DOWN", "LEFT", "RIGHT", "TURN LEFT", "TURN RIGHT"]
		# Walkers don't use turn_right (only turn_left for mouse tracking)
		if "walker" in leg_name or "legs" in leg_name:
			_movement_indices = [0, 1, 2, 3, 4]
			_movement_labels = ["UP", "DOWN", "LEFT", "RIGHT", "TURN TO MOUSE"]


func _get_movement_binding_label(binding_index: int) -> String:
	var pos := _movement_indices.find(binding_index)
	if pos >= 0 and pos < _movement_labels.size():
		return _movement_labels[pos]

	var fallback_labels: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT", "TURN LEFT", "TURN RIGHT"]
	if binding_index >= 0 and binding_index < fallback_labels.size():
		return fallback_labels[binding_index]
	return "MOVEMENT %d" % binding_index


func _get_all_movement_binding_labels() -> Array[String]:
	var labels: Array[String] = []
	for i in _movement_bindings.size():
		labels.append(_get_movement_binding_label(i))
	return labels


func _get_utility_module_label(module: Variant) -> String:
	var utility_module_data = _UTILITY_MODULE_DATA_SCRIPT.new()
	var module_data = utility_module_data.ensure_module_data(module)
	var module_name := utility_module_data.get_module_name(module_data)
	if module_name.is_empty():
		return ""
	if module_name == "Booster" and module_data != null:
		return "%s [%s]" % [
			module_name,
			utility_module_data.get_booster_direction_label(float(module_data.get("direction_angle"))),
		]
	return module_name


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Scanline/grid overlay (drawn procedurally)
	_grid_overlay = Control.new()
	_grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_overlay.draw.connect(_draw_grid_overlay.bind(_grid_overlay))
	add_child(_grid_overlay)

	# Main margin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   80)
	margin.add_theme_constant_override("margin_top",    40)
	margin.add_theme_constant_override("margin_right",  80)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# ── Header ────────────────────────────────────────────────────────────
	_build_header(main_vbox)

	# ── Subtitle / instructions ───────────────────────────────────────────
	var subtitle := Label.new()
	subtitle.text = "CONFIGURE MOVEMENT CONTROLS, UTILITY LOADOUT, AND FIRE CONTROL BINDINGS"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	# Separator line
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	sep.add_theme_stylebox_override("separator", _make_line_stylebox(ACCENT_DIM, 1))
	main_vbox.add_child(sep)

	# ── Weapon bindings section ───────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 10)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sections)

	_movement_container = _add_collapsible_section(sections, "MOVEMENT SECTION", true)
	_utility_container = _add_collapsible_section(sections, "UTILITY SECTION", true)
	_weapons_container = _add_collapsible_section(sections, "WEAPON SECTION", true)

	_build_movement_rows()
	_build_utility_rows()
	_build_weapon_rows()

	# ── Status label ──────────────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", ACCENT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	# ── Bottom bar ────────────────────────────────────────────────────────
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	main_vbox.add_child(bottom)

	_back_button = _make_nav_button("← BACK TO UTILITY MODULES", false)
	_back_button.pressed.connect(_on_back_pressed)
	bottom.add_child(_back_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_deploy_button = _make_nav_button("DEPLOY  ▸", true)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	bottom.add_child(_deploy_button)


func _build_header(parent: VBoxContainer) -> void:
	# Decorative top bar
	var top_bar := ColorRect.new()
	top_bar.custom_minimum_size = Vector2(0, 2)
	top_bar.color = ACCENT_DIM
	parent.add_child(top_bar)

	# Title row with flanking dashes
	var title_hbox := HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.add_theme_constant_override("separation", 20)
	parent.add_child(title_hbox)

	var left_dash := Label.new()
	left_dash.text = "//————"
	left_dash.add_theme_font_size_override("font_size", 28)
	left_dash.add_theme_color_override("font_color", ACCENT_DIM)
	title_hbox.add_child(left_dash)

	_title_label = Label.new()
	_title_label.text = "SOFTWARE  CONFIGURATION"
	_title_label.add_theme_font_size_override("font_size", 38)
	_title_label.add_theme_color_override("font_color", ACCENT)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0.5, 0.6, 0.5))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_hbox.add_child(_title_label)

	var right_dash := Label.new()
	right_dash.text = "————//"
	right_dash.add_theme_font_size_override("font_size", 28)
	right_dash.add_theme_color_override("font_color", ACCENT_DIM)
	title_hbox.add_child(right_dash)

	# Version tag line
	var version := Label.new()
	version.text = "[  FIRE CONTROL SYSTEM  v2.7.1  |  MECH OS  ]"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.3, 0.55, 0.6, 0.6))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(version)


func _add_collapsible_section(parent: VBoxContainer, title: String, starts_open: bool) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var toggle := Button.new()
	toggle.text = ("▼ " if starts_open else "▶ ") + title
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.add_theme_color_override("font_color", ACCENT)
	toggle.add_theme_color_override("font_hover_color", Color(0.35, 0.9, 1.0, 1.0))
	section.add_child(toggle)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.visible = starts_open
	section.add_child(body)

	toggle.pressed.connect(func() -> void:
		body.visible = not body.visible
		toggle.text = ("▼ " if body.visible else "▶ ") + title
	)

	return body


# ── Movement rows ─────────────────────────────────────────────────────────────

func _build_movement_rows() -> void:
	_movement_bind_buttons.clear()
	for child in _movement_container.get_children():
		child.queue_free()

	if _movement_indices.is_empty():
		var empty := Label.new()
		empty.text = "NO MOVEMENT CONTROLS AVAILABLE"
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", TEXT_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_movement_container.add_child(empty)
		return

	# Create a panel containing a VBoxContainer for multi-row layout
	var row_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.16, 0.9)
	style.set_border_width_all(1)
	style.border_color = ACCENT_DIM * 0.6
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	row_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(vbox)

	# Title row
	var title := Label.new()
	title.text = "MECH MOVEMENT"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	vbox.add_child(title)

	# Split binding keys across HBox rows — max 3 per row
	const COLS_PER_ROW := 3
	var current_hbox: HBoxContainer = null

	for i in _movement_indices.size():
		if i % COLS_PER_ROW == 0:
			current_hbox = HBoxContainer.new()
			current_hbox.add_theme_constant_override("separation", 16)
			vbox.add_child(current_hbox)

		var binding_idx := _movement_indices[i]
		var direction_label := _movement_labels[i]

		# Each key is a vertical cell: label on top, button below
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_hbox.add_child(cell)

		var key_label := Label.new()
		key_label.text = direction_label
		key_label.add_theme_font_size_override("font_size", 13)
		key_label.add_theme_color_override("font_color", TEXT_DIM)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(key_label)

		var bind_btn := _make_compact_bind_button("movement", binding_idx)
		bind_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(bind_btn)
		_movement_bind_buttons.append(bind_btn)

	_movement_container.add_child(row_panel)


func _make_movement_section_header() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	var idx_label := _make_col_label("IDX", 50)
	hbox.add_child(idx_label)
	var name_label := _make_col_label("DIRECTION", 0, true)
	hbox.add_child(name_label)
	var badge_label := _make_col_label("TYPE", 80)
	hbox.add_child(badge_label)
	var bind_label := _make_col_label("ASSIGN", 200)
	hbox.add_child(bind_label)

	return hbox


func _build_single_movement_row(index: int, direction_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.16, 0.9)
	style.set_border_width_all(1)
	style.border_color = ACCENT_DIM * 0.6
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var idx := Label.new()
	idx.text = "M%02d" % (index + 1)
	idx.custom_minimum_size.x = 48
	idx.add_theme_font_size_override("font_size", 16)
	idx.add_theme_color_override("font_color", ACCENT_DIM)
	idx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(idx)

	var name := Label.new()
	name.text = direction_name.to_upper()
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", TEXT_MAIN)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name)

	var badge := Label.new()
	badge.text = "MOVE"
	badge.custom_minimum_size.x = 80
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.7, 0.95, 0.45, 0.95))
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(badge)

	var bind_btn := _make_bind_button("movement", index)
	hbox.add_child(bind_btn)
	_movement_bind_buttons.append(bind_btn)

	return panel

# ── Weapon rows ───────────────────────────────────────────────────────────────

func _build_utility_rows() -> void:
	_utility_bind_buttons.clear()
	for child in _utility_container.get_children():
		child.queue_free()

	if _utility_modules.is_empty():
		var empty := Label.new()
		empty.text = "NO UTILITY MODULES EQUIPPED"
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", TEXT_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_utility_container.add_child(empty)
		return

	_utility_container.add_child(_make_utility_section_header())

	for i in _utility_modules.size():
		_utility_container.add_child(_build_single_utility_row(i, _utility_modules[i]))


func _make_utility_section_header() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	var idx_label := _make_col_label("IDX", 50)
	hbox.add_child(idx_label)
	var name_label := _make_col_label("UTILITY MODULE", 0, true)
	hbox.add_child(name_label)
	var tag_label := _make_col_label("TYPE", 80)
	hbox.add_child(tag_label)
	var bind_label := _make_col_label("ASSIGN", 200)
	hbox.add_child(bind_label)

	return hbox


func _build_single_utility_row(index: int, module_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.16, 0.9)
	style.set_border_width_all(1)
	style.border_color = ACCENT_DIM * 0.6
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var idx := Label.new()
	idx.text = "U%02d" % (index + 1)
	idx.custom_minimum_size.x = 48
	idx.add_theme_font_size_override("font_size", 16)
	idx.add_theme_color_override("font_color", ACCENT_DIM)
	idx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(idx)

	var name := Label.new()
	name.text = module_name.to_upper()
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", TEXT_MAIN)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name)

	var badge := Label.new()
	badge.text = "UTILITY"
	badge.custom_minimum_size.x = 80
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.45, 0.9, 0.95, 0.95))
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(badge)

	var bind_btn := _make_bind_button("utility", index)
	hbox.add_child(bind_btn)
	_utility_bind_buttons.append(bind_btn)

	return panel

func _build_weapon_rows() -> void:
	_bind_buttons.clear()
	for child in _weapons_container.get_children():
		child.queue_free()

	if _weapon_names.is_empty():
		var empty := Label.new()
		empty.text = "NO WEAPONS CONFIGURED — RETURN TO WORKSHOP"
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", WARNING_COLOR)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weapons_container.add_child(empty)
		return

	# Section header
	var header := _make_section_header()
	_weapons_container.add_child(header)

	for i in _weapon_names.size():
		var row := _build_single_weapon_row(i)
		_weapons_container.add_child(row)


func _make_section_header() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	var idx_label := _make_col_label("IDX", 50)
	hbox.add_child(idx_label)
	var name_label := _make_col_label("WEAPON SYSTEM", 0, true)
	hbox.add_child(name_label)
	var slot_label := _make_col_label("SLOT", 80)
	hbox.add_child(slot_label)
	var bind_label := _make_col_label("FIRE BIND", 200)
	hbox.add_child(bind_label)

	return hbox


func _make_col_label(text: String, min_w: int, expand := false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.55, 0.6, 0.7))
	if min_w > 0:
		lbl.custom_minimum_size.x = min_w
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _build_single_weapon_row(index: int) -> PanelContainer:
	var loadout: MechLoadout = GameManager.current_loadout
	var all_weapons: Array[WeaponData] = []
	if loadout:
		all_weapons.append_array(loadout.selected_guns)
		all_weapons.append_array(loadout.selected_light_guns)

	var weapon_data: WeaponData = all_weapons[index] if index < all_weapons.size() else null

	# Row panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BG_CARD
	style.set_border_width_all(1)
	style.border_color = ACCENT_DIM * 0.5
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Index number
	var idx_label := Label.new()
	idx_label.text = "%02d" % (index + 1)
	idx_label.custom_minimum_size.x = 38
	idx_label.add_theme_font_size_override("font_size", 22)
	idx_label.add_theme_color_override("font_color", ACCENT_DIM)
	idx_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(idx_label)

	# Weapon type icon (procedural colored square)
	var icon := _make_weapon_type_icon(weapon_data)
	hbox.add_child(icon)

	# Weapon name + type info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = _weapon_names[index].to_upper()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", TEXT_MAIN)
	info_vbox.add_child(name_label)

	var type_label := Label.new()
	if weapon_data:
		type_label.text = _get_weapon_type_string(weapon_data.weapon_type)
	else:
		type_label.text = "UNKNOWN"
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", TEXT_DIM)
	info_vbox.add_child(type_label)

	# Slot type badge
	var slot_label := Label.new()
	if weapon_data and weapon_data.slot_size == WeaponData.SlotSize.LIGHT:
		slot_label.text = "LIGHT"
		slot_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.4, 0.9))
	else:
		slot_label.text = "MAIN"
		slot_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.2, 0.9))
	slot_label.custom_minimum_size.x = 60
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(slot_label)

	# Bind button
	var bind_btn := _make_bind_button("weapon", index)
	hbox.add_child(bind_btn)
	_bind_buttons.append(bind_btn)

	# Hover effects on row
	panel.mouse_entered.connect(_on_row_hover.bind(panel, style))
	panel.mouse_exited.connect(_on_row_unhover.bind(panel, style))

	return panel


func _make_weapon_type_icon(data: WeaponData) -> ColorRect:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	if data:
		match data.weapon_type:
			WeaponData.WeaponType.AUTOCANNON:   icon.color = Color(0.9, 0.55, 0.15, 0.9)
			WeaponData.WeaponType.LASER:        icon.color = Color(0.2, 0.7, 0.95, 0.9)
			WeaponData.WeaponType.RAILGUN:      icon.color = Color(0.6, 0.3, 0.9, 0.9)
			WeaponData.WeaponType.FLAMETHROWER: icon.color = Color(0.95, 0.3, 0.15, 0.9)
			WeaponData.WeaponType.PLASMA_GUN:   icon.color = Color(0.18, 0.58, 0.98, 0.9)
			WeaponData.WeaponType.ROCKET_POD:   icon.color = Color(0.85, 0.75, 0.2, 0.9)
			WeaponData.WeaponType.MACHINEGUN:   icon.color = Color(0.5, 0.7, 0.4, 0.9)
			_: icon.color = Color(0.5, 0.5, 0.5, 0.9)
	else:
		icon.color = Color(0.3, 0.3, 0.3, 0.9)
	return icon


func _make_bind_button(bind_kind: String, index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 44)
	if bind_kind == "utility":
		btn.text = _get_current_utility_bind_text(index)
	elif bind_kind == "movement":
		btn.text = _get_current_movement_bind_text(index)
	else:
		btn.text = _get_current_bind_text(index)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT * 0.8
	normal.set_border_width_all(2)
	normal.border_color = ACCENT
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT
	hover.border_color = Color(1, 1, 1, 0.6)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT * 0.5
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.pressed.connect(_on_bind_pressed.bind(bind_kind, index))
	return btn


func _make_compact_bind_button(bind_kind: String, binding_index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 36)
	btn.text = _get_current_movement_bind_text(binding_index)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT * 0.8
	normal.set_border_width_all(2)
	normal.border_color = ACCENT
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT
	hover.border_color = Color(1, 1, 1, 0.6)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT * 0.5
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.pressed.connect(_on_bind_pressed.bind(bind_kind, binding_index))
	return btn

func _get_current_bind_text(index: int) -> String:
	if index < _bindings.size():
		return "[ %s ]" % GameManager.get_binding_label(_bindings[index])
	return "[ UNBOUND ]"


func _get_current_utility_bind_text(index: int) -> String:
	if index < _utility_bindings.size():
		return "[ %s ]" % GameManager.get_binding_label(_utility_bindings[index])
	return "[ UNBOUND ]"


func _get_current_movement_bind_text(index: int) -> String:
	if index < _movement_bindings.size():
		return "[ %s ]" % GameManager.get_binding_label(_movement_bindings[index])
	return "[ UNBOUND ]"


func _get_weapon_type_string(wtype: WeaponData.WeaponType) -> String:
	match wtype:
		WeaponData.WeaponType.AUTOCANNON:   return "BALLISTIC  •  BURST FIRE"
		WeaponData.WeaponType.LASER:        return "ENERGY  •  CONTINUOUS BEAM"
		WeaponData.WeaponType.RAILGUN:      return "ENERGY  •  CHARGE FIRE"
		WeaponData.WeaponType.FLAMETHROWER: return "THERMAL  •  AREA DENIAL"
		WeaponData.WeaponType.PLASMA_GUN:   return "ENERGY  •  ARC LOBBER"
		WeaponData.WeaponType.ROCKET_POD:   return "ORDNANCE  •  MULTI-ROCKET"
		WeaponData.WeaponType.MACHINEGUN:   return "BALLISTIC  •  RAPID FIRE"
		_: return "UNKNOWN SYSTEM"


# ── Helper style factories ────────────────────────────────────────────────────

func _make_line_stylebox(color: Color, height: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_content_margin_all(0)
	sb.content_margin_top = height
	sb.content_margin_bottom = 0
	return sb


func _make_nav_button(text: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 55)
	btn.add_theme_font_size_override("font_size", 22)

	if primary:
		btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		var style := StyleBoxFlat.new()
		style.bg_color = ACCENT * 0.85
		style.set_border_width_all(2)
		style.border_color = ACCENT
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = ACCENT
		btn.add_theme_stylebox_override("hover", hover_style)
	else:
		btn.add_theme_color_override("font_color", TEXT_DIM)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.15, 0.8)
		style.set_border_width_all(1)
		style.border_color = ACCENT_DIM * 0.5
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.border_color = ACCENT_DIM
		hover_style.bg_color = Color(0.12, 0.16, 0.2, 0.9)
		btn.add_theme_stylebox_override("hover", hover_style)

	return btn


# ── Row hover ─────────────────────────────────────────────────────────────────

func _on_row_hover(panel: PanelContainer, style: StyleBoxFlat) -> void:
	style.border_color = ACCENT * 0.6
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95)

func _on_row_unhover(panel: PanelContainer, style: StyleBoxFlat) -> void:
	style.border_color = ACCENT_DIM * 0.5
	style.bg_color = BG_CARD


# ── Binding logic ─────────────────────────────────────────────────────────────

func _on_bind_pressed(bind_kind: String, index: int) -> void:
	var target := LISTEN_TARGET_NONE
	if bind_kind == "utility":
		target = LISTEN_TARGET_UTILITY
	elif bind_kind == "movement":
		target = LISTEN_TARGET_MOVEMENT
	else:
		target = LISTEN_TARGET_WEAPON

	if _listening_target == target:
		# For movement, compare against binding index; for others use button index.
		if (target == LISTEN_TARGET_MOVEMENT and _listening_binding_index == index) or (target != LISTEN_TARGET_MOVEMENT and _listening_index == index):
			_cancel_listening()
			return

	_cancel_listening()
	_listening_target = target
	_listening_index = index
	var target_buttons: Array[Button]
	match target:
		LISTEN_TARGET_UTILITY:
			target_buttons = _utility_bind_buttons
		LISTEN_TARGET_MOVEMENT:
			target_buttons = _movement_bind_buttons
		_:
			target_buttons = _bind_buttons
	# For movement, index is the actual binding index (0-5), not button position
	var button_index := index
	if target == LISTEN_TARGET_MOVEMENT:
		_listening_binding_index = index
		# Find position of this binding in the visible buttons
		var button_pos := _movement_indices.find(index)
		if button_pos < 0 or button_pos >= _movement_bind_buttons.size():
			return
		button_index = button_pos
	else:
		_listening_binding_index = -1
		if index < 0 or index >= target_buttons.size():
			return
	_listening_index = button_index
	target_buttons[button_index].text = ">> PRESS KEY <<"
	target_buttons[button_index].add_theme_color_override("font_color", Color(0, 0, 0, 1))

	var style := target_buttons[button_index].get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.bg_color = LISTENING_COLOR
	style.border_color = Color(1, 1, 0.5, 1)
	target_buttons[button_index].add_theme_stylebox_override("normal", style)
	target_buttons[button_index].add_theme_stylebox_override("hover", style)

	var target_name: String
	match target:
		LISTEN_TARGET_UTILITY:
			target_name = _utility_modules[index]
		LISTEN_TARGET_MOVEMENT:
			target_name = _get_movement_binding_label(index)
		_:
			target_name = _weapon_names[index]
	_status_label.text = "[ AWAITING INPUT FOR %s ]" % target_name
	_status_label.add_theme_color_override("font_color", LISTENING_COLOR)


func _cancel_listening() -> void:
	if _listening_index < 0:
		return
	match _listening_target:
		LISTEN_TARGET_UTILITY:
			_update_utility_bind_button_display(_listening_index)
		LISTEN_TARGET_MOVEMENT:
			_update_movement_bind_button_display(_listening_index)
		_:
			_update_bind_button_display(_listening_index)
	_listening_target = LISTEN_TARGET_NONE
	_listening_index = -1
	_listening_binding_index = -1
	_status_label.text = ""


func _input(event: InputEvent) -> void:
	if _listening_index < 0 or _listening_target == LISTEN_TARGET_NONE:
		return

	# Accept key presses and mouse buttons
	var valid := false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_listening()
			get_viewport().set_input_as_handled()
			return
		valid = true
	elif event is InputEventMouseButton and event.is_pressed():
		valid = true

	if not valid:
		return

	# Store the binding
	var clean_event := _clean_input_event(event)
	match _listening_target:
		LISTEN_TARGET_UTILITY:
			_utility_bindings[_listening_index] = clean_event
			_check_duplicate_bindings(_utility_bindings, _utility_modules)
			_update_utility_bind_button_display(_listening_index)
		LISTEN_TARGET_MOVEMENT:
			_movement_bindings[_listening_binding_index] = clean_event
			_check_duplicate_bindings(_movement_bindings, _get_all_movement_binding_labels())
			_update_movement_bind_button_display(_listening_index)
		_:
			_bindings[_listening_index] = clean_event
			_check_duplicate_bindings(_bindings, _weapon_names)
			_update_bind_button_display(_listening_index)

	_listening_target = LISTEN_TARGET_NONE
	_listening_index = -1
	_listening_binding_index = -1

	_status_label.text = "[ BINDING UPDATED ]"
	_status_label.add_theme_color_override("font_color", ACCENT)

	get_viewport().set_input_as_handled()


func _clean_input_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.keycode = (event as InputEventKey).keycode
		key.physical_keycode = (event as InputEventKey).physical_keycode
		return key
	elif event is InputEventMouseButton:
		var mb := InputEventMouseButton.new()
		mb.button_index = (event as InputEventMouseButton).button_index
		return mb
	return event


func _check_duplicate_bindings(bindings: Array[InputEvent], names: Array[String]) -> void:
	var seen := {}
	for i in bindings.size():
		var label := GameManager.get_binding_label(bindings[i])
		if label in seen:
			_status_label.text = "⚠ WARNING: %s and %s share the same binding [%s]" % [
				names[seen[label]].to_upper(),
				names[i].to_upper(),
				label
			]
			_status_label.add_theme_color_override("font_color", WARNING_COLOR)
			return
		seen[label] = i


func _update_bind_button_display(index: int) -> void:
	if index < 0 or index >= _bind_buttons.size():
		return
	var btn := _bind_buttons[index]
	btn.text = _get_current_bind_text(index)
	btn.modulate.a = 1.0
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT * 0.8
	normal.set_border_width_all(2)
	normal.border_color = ACCENT
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT
	hover.border_color = Color(1, 1, 1, 0.6)
	btn.add_theme_stylebox_override("hover", hover)


func _update_utility_bind_button_display(index: int) -> void:
	if index < 0 or index >= _utility_bind_buttons.size():
		return
	var btn := _utility_bind_buttons[index]
	btn.text = _get_current_utility_bind_text(index)
	btn.modulate.a = 1.0
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT * 0.8
	normal.set_border_width_all(2)
	normal.border_color = ACCENT
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT
	hover.border_color = Color(1, 1, 1, 0.6)
	btn.add_theme_stylebox_override("hover", hover)


func _update_movement_bind_button_display(index: int) -> void:
	if index < 0 or index >= _movement_bind_buttons.size():
		return
	var btn := _movement_bind_buttons[index]
	btn.text = _get_current_movement_bind_text(index)
	btn.modulate.a = 1.0
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT * 0.8
	normal.set_border_width_all(2)
	normal.border_color = ACCENT
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT
	hover.border_color = Color(1, 1, 1, 0.6)
	btn.add_theme_stylebox_override("hover", hover)


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_deploy_pressed() -> void:
	_cancel_listening()
	_deploy_button.disabled = true
	_back_button.disabled = true

	# Save bindings to GameManager
	GameManager.weapon_bindings = _bindings.duplicate()
	GameManager.utility_bindings = _utility_bindings.duplicate()
	GameManager.movement_bindings = _movement_bindings.duplicate()
	GameManager.apply_weapon_bindings()
	GameManager.apply_utility_bindings()
	GameManager.apply_movement_bindings()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/ui/level_select_screen.tscn")
	)


func _on_back_pressed() -> void:
	_cancel_listening()
	_back_button.disabled = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/ui/utility_modules_screen.tscn")
	)


# ── Visual FX: animated scanlines + grid ──────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta
	_scanline_offset += delta * 30.0
	if _scanline_offset > 8.0:
		_scanline_offset -= 8.0
	_grid_overlay.queue_redraw()

	# Subtle title glow pulse
	if _title_label:
		var pulse := 0.85 + 0.15 * sin(_time * 2.0)
		_title_label.add_theme_color_override("font_color",
			Color(0.0 * pulse, 0.85 * pulse, 0.95 * pulse, 1.0))

	# Listening button blink
	if _listening_target == LISTEN_TARGET_WEAPON and _listening_index >= 0 and _listening_index < _bind_buttons.size():
		var blink := 0.7 + 0.3 * sin(_time * 6.0)
		_bind_buttons[_listening_index].modulate.a = blink
	elif _listening_target == LISTEN_TARGET_UTILITY and _listening_index >= 0 and _listening_index < _utility_bind_buttons.size():
		var utility_blink := 0.7 + 0.3 * sin(_time * 6.0)
		_utility_bind_buttons[_listening_index].modulate.a = utility_blink
	elif _listening_target == LISTEN_TARGET_MOVEMENT and _listening_index >= 0 and _listening_index < _movement_bind_buttons.size():
		var movement_blink := 0.7 + 0.3 * sin(_time * 6.0)
		_movement_bind_buttons[_listening_index].modulate.a = movement_blink


func _draw_grid_overlay(overlay: Control) -> void:
	var rect := overlay.get_rect()

	# Horizontal scanlines
	var y := _scanline_offset
	while y < rect.size.y:
		overlay.draw_line(
			Vector2(0, y), Vector2(rect.size.x, y),
			Color(0.0, 0.6, 0.7, 0.04), 1.0)
		y += 4.0

	# Faint vertical grid lines
	var spacing := 120.0
	var x := fmod(_time * 5.0, spacing)
	while x < rect.size.x:
		overlay.draw_line(
			Vector2(x, 0), Vector2(x, rect.size.y),
			GRID_LINE, 1.0)
		x += spacing

	# Corner brackets (sci-fi HUD corners)
	var corner_len := 40.0
	var corner_color := ACCENT_DIM
	var cw := 2.0
	# Top-left
	overlay.draw_line(Vector2(20, 20), Vector2(20 + corner_len, 20), corner_color, cw)
	overlay.draw_line(Vector2(20, 20), Vector2(20, 20 + corner_len), corner_color, cw)
	# Top-right
	overlay.draw_line(Vector2(rect.size.x - 20, 20), Vector2(rect.size.x - 20 - corner_len, 20), corner_color, cw)
	overlay.draw_line(Vector2(rect.size.x - 20, 20), Vector2(rect.size.x - 20, 20 + corner_len), corner_color, cw)
	# Bottom-left
	overlay.draw_line(Vector2(20, rect.size.y - 20), Vector2(20 + corner_len, rect.size.y - 20), corner_color, cw)
	overlay.draw_line(Vector2(20, rect.size.y - 20), Vector2(20, rect.size.y - 20 - corner_len), corner_color, cw)
	# Bottom-right
	overlay.draw_line(Vector2(rect.size.x - 20, rect.size.y - 20), Vector2(rect.size.x - 20 - corner_len, rect.size.y - 20), corner_color, cw)
	overlay.draw_line(Vector2(rect.size.x - 20, rect.size.y - 20), Vector2(rect.size.x - 20, rect.size.y - 20 - corner_len), corner_color, cw)

	# Blinking status dot (top-right)
	var dot_alpha: float = 0.4 + 0.6 * absf(sin(_time * 3.0))
	overlay.draw_circle(Vector2(rect.size.x - 40, 40), 4.0, Color(0, 0.9, 0.5, dot_alpha))
# ── Weapon rows ───────────────────────────────────────────────────────────────
