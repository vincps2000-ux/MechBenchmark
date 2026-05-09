# engineering_screen.gd — Module grid builder screen.
# Allows players to arrange modules on a torso-specific grid layout.
extends Control

class_name EngineeringScreen

const CELL_SIZE := 48
const CELL_PADDING := 2
const DRAG_PREVIEW_SCALE := 0.8

## Colour palette (matches software/workshop screens)
const C_BG          := Color(0.04, 0.05, 0.07, 1.0)
const C_PANEL       := Color(0.08, 0.09, 0.12, 0.92)
const C_PANEL_BORDER := Color(0.25, 0.30, 0.38, 0.60)
const C_ACCENT      := Color(0.0,  0.85, 0.95, 1.0)
const C_ACCENT_DIM  := Color(0.0,  0.45, 0.55, 0.70)
const C_HEADER      := Color(0.70, 0.85, 0.95, 1.0)
const C_TEXT_DIM    := Color(0.45, 0.52, 0.58, 0.85)
const C_GRID_LINE   := Color(0.08, 0.18, 0.22, 0.30)

## Signals
signal back_pressed
signal next_pressed

## Preloads
const _ModuleData = preload("res://src/player/module_data.gd")
const _ModuleGrid = preload("res://src/player/module_grid.gd")
const _GridLayout = preload("res://src/player/grid_layout.gd")

## References
var mech_loadout: MechLoadout
var all_modules: Array = []
var current_torso_index: int = 0
var current_grid_type: int = 0  # GridLayout.GridType enum value
var current_grid_state: Array[Array]  # 2D grid of ModuleData or null

## UI Components (created in _setup_ui)
var torso_selector: HBoxContainer
var module_catalog_container: VBoxContainer
var grid_display: Control
var back_button: Button
var next_button: Button
var torso_name_label: Label

## Drag state
var dragging_module = null
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_preview: Control = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not mech_loadout:
		mech_loadout = GameManager.current_loadout
	_setup_ui()
	if mech_loadout:
		_load_modules()
		_setup_torso_selector()
		_select_torso(0)

func _setup_ui() -> void:
	# ── Dark background ────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ── Scanline overlay ───────────────────────────────────────────────────
	var grid_overlay := Control.new()
	grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_overlay.draw.connect(func():
		var r := grid_overlay.get_rect()
		var y := 0.0
		while y < r.size.y:
			grid_overlay.draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(0.0, 0.6, 0.7, 0.04), 1.0)
			y += 4.0
		var x := 0.0
		while x < r.size.x:
			grid_overlay.draw_line(Vector2(x, 0), Vector2(x, r.size.y), C_GRID_LINE, 1.0)
			x += 120.0
	)
	add_child(grid_overlay)

	# ── Outer margin container ─────────────────────────────────────────────
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# ── Header row ─────────────────────────────────────────────────────────
	var header_row := HBoxContainer.new()
	root_vbox.add_child(header_row)

	var title_label := Label.new()
	title_label.text = "ENGINEERING — MODULE GRID"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", C_HEADER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_label)

	var sep_line := HSeparator.new()
	sep_line.add_theme_constant_override("separation", 4)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_ACCENT_DIM
	sep_line.add_theme_stylebox_override("separator", sep_style)
	root_vbox.add_child(sep_line)

	# ── Body: left catalog + right grid ───────────────────────────────────
	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 16)
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body_row)

	# LEFT: catalog panel
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(220, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = C_PANEL
	left_style.set_border_width_all(1)
	left_style.border_color = C_PANEL_BORDER
	left_style.set_corner_radius_all(6)
	left_style.set_content_margin_all(12)
	left_panel.add_theme_stylebox_override("panel", left_style)
	body_row.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	var catalog_title := Label.new()
	catalog_title.text = "── MODULES ──"
	catalog_title.add_theme_font_size_override("font_size", 13)
	catalog_title.add_theme_color_override("font_color", C_ACCENT_DIM)
	left_vbox.add_child(catalog_title)

	var scroll_container := ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll_container)

	module_catalog_container = VBoxContainer.new()
	module_catalog_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module_catalog_container.add_theme_constant_override("separation", 8)
	scroll_container.add_child(module_catalog_container)

	# RIGHT: grid panel
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = C_PANEL
	right_style.set_border_width_all(1)
	right_style.border_color = C_PANEL_BORDER
	right_style.set_corner_radius_all(6)
	right_style.set_content_margin_all(16)
	right_panel.add_theme_stylebox_override("panel", right_style)
	body_row.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	# Torso name
	torso_name_label = Label.new()
	torso_name_label.text = "Select a torso"
	torso_name_label.add_theme_font_size_override("font_size", 16)
	torso_name_label.add_theme_color_override("font_color", C_HEADER)
	right_vbox.add_child(torso_name_label)

	# Torso tab buttons
	torso_selector = HBoxContainer.new()
	torso_selector.add_theme_constant_override("separation", 8)
	right_vbox.add_child(torso_selector)

	var grid_sep := HSeparator.new()
	var gs_style := StyleBoxFlat.new()
	gs_style.bg_color = C_PANEL_BORDER
	grid_sep.add_theme_stylebox_override("separator", gs_style)
	right_vbox.add_child(grid_sep)

	# Grid display — centered
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(grid_center)

	grid_display = Control.new()
	grid_display.mouse_filter = Control.MOUSE_FILTER_STOP
	grid_display.draw.connect(_on_grid_display_draw)
	grid_center.add_child(grid_display)

	# ── Bottom nav bar ─────────────────────────────────────────────────────
	var nav_sep := HSeparator.new()
	var ns_style := StyleBoxFlat.new()
	ns_style.bg_color = C_ACCENT_DIM
	nav_sep.add_theme_stylebox_override("separator", ns_style)
	root_vbox.add_child(nav_sep)

	var nav_bar := HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 12)
	root_vbox.add_child(nav_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_bar.add_child(spacer)

	back_button = _make_nav_button("← BACK", false)
	back_button.pressed.connect(_on_back_pressed)
	nav_bar.add_child(back_button)

	next_button = _make_nav_button("NEXT →", true)
	next_button.pressed.connect(_on_next_pressed)
	nav_bar.add_child(next_button)

func _make_nav_button(label: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(140, 40)
	btn.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	var hover  := StyleBoxFlat.new()
	var pressed_style := StyleBoxFlat.new()
	if primary:
		normal.bg_color  = C_ACCENT * 0.8
		hover.bg_color   = C_ACCENT
		pressed_style.bg_color = C_ACCENT * 0.5
		btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))
	else:
		normal.bg_color  = Color(0.10, 0.12, 0.15, 0.85)
		hover.bg_color   = Color(0.14, 0.18, 0.23, 0.95)
		pressed_style.bg_color = Color(0.06, 0.08, 0.10, 0.95)
		btn.add_theme_color_override("font_color", C_TEXT_DIM)
	for s in [normal, hover, pressed_style]:
		s.set_corner_radius_all(4)
		s.set_border_width_all(1)
		s.border_color = C_ACCENT_DIM
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	return btn

func _load_modules() -> void:
	all_modules = MechCatalog.get_all_modules()

func _setup_torso_selector() -> void:
	# Clear existing buttons
	for child in torso_selector.get_children():
		child.queue_free()
	
	# Create a button for each equipped torso
	var num_torsos := mech_loadout.selected_torsos.size()
	if num_torsos == 0:
		num_torsos = 1  # Legacy single torso support
	
	for i in range(num_torsos):
		var button := Button.new()
		button.text = "Torso %d" % (i + 1)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(90, 30)
		button.add_theme_font_size_override("font_size", 12)
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.10, 0.12, 0.15, 0.85)
		btn_normal.set_border_width_all(1)
		btn_normal.border_color = C_ACCENT_DIM
		btn_normal.set_corner_radius_all(4)
		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = C_ACCENT * 0.3
		btn_pressed.set_border_width_all(1)
		btn_pressed.border_color = C_ACCENT
		btn_pressed.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal", btn_normal)
		button.add_theme_stylebox_override("pressed", btn_pressed)
		button.add_theme_stylebox_override("hover", btn_pressed)
		button.add_theme_color_override("font_color", C_TEXT_DIM)
		button.add_theme_color_override("font_pressed_color", C_ACCENT)
		button.pressed.connect(func(): _select_torso(i))
		torso_selector.add_child(button)
	
	# Select first button
	if torso_selector.get_child_count() > 0:
		(torso_selector.get_child(0) as Button).set_pressed_no_signal(true)

func _select_torso(index: int) -> void:
	current_torso_index = index
	
	# Get the torso type
	var torso := mech_loadout.selected_torsos[index] if index < mech_loadout.selected_torsos.size() else mech_loadout.selected_torso
	if not torso:
		return
	
	torso_name_label.text = torso.name
	current_grid_type = _GridLayout.get_grid_type(torso.torso_type)
	
	# Create empty grid or load existing
	var grid = mech_loadout.get_or_create_module_grid(index)
	current_grid_state = _GridLayout.create_empty_grid(current_grid_type)
	
	# Populate grid with existing placements
	for placement in grid.placements:
		var module = placement["module"]
		var pos = placement["position"] as Vector2i
		if module and _GridLayout.is_position_valid(current_grid_type, pos):
			module.place_on_grid(current_grid_state, pos)
	
	# Update UI
	_update_module_catalog()
	grid_display.queue_redraw()

func _update_module_catalog() -> void:
	# Clear existing catalog
	for child in module_catalog_container.get_children():
		child.queue_free()
	
	# Add each available module as a draggable card
	for module in all_modules:
		var card = _create_module_card(module)
		module_catalog_container.add_child(card)

func _create_module_card(module) -> Control:
	var card := PanelContainer.new()
	
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.10, 0.12, 0.16, 0.90)
	style_box.set_border_width_all(1)
	style_box.border_color = module.grid_cell_color * 0.6
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style_box)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	
	# Module name
	var name_label := Label.new()
	name_label.text = module.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", C_HEADER)
	vbox.add_child(name_label)
	
	# Module shape preview — draw cells proportionally
	var bounds = module.get_grid_bounds()
	var preview_cell := 14
	var shape_preview := Control.new()
	shape_preview.custom_minimum_size = Vector2(bounds.size.x * preview_cell, bounds.size.y * preview_cell)
	shape_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	shape_preview.draw.connect(func():
		for offset in module.grid_shape:
			var r := Rect2(offset * preview_cell, Vector2(preview_cell - 2, preview_cell - 2))
			shape_preview.draw_rect(r, module.grid_cell_color)
			shape_preview.draw_rect(r, module.grid_cell_color.lightened(0.3), false, 1.0)
	)
	vbox.add_child(shape_preview)
	shape_preview.queue_redraw()
	# Recharge bonus
	var bonus_label := Label.new()
	if int(module.recharge_rate_bonus) > 0 and int(module.armor_bonus) > 0:
		bonus_label.text = "+%d energy/sec, +%d armor" % [int(module.recharge_rate_bonus), int(module.armor_bonus)]
	elif int(module.recharge_rate_bonus) > 0:
		bonus_label.text = "+%d energy/sec" % int(module.recharge_rate_bonus)
	elif int(module.armor_bonus) > 0:
		bonus_label.text = "+%d armor" % int(module.armor_bonus)
	else:
		bonus_label.text = "No bonus"
	bonus_label.add_theme_font_size_override("font_size", 11)
	bonus_label.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(bonus_label)
	
	# Grid footprint
	var size_label := Label.new()
	size_label.text = "%dx%d grid" % [bounds.size.x, bounds.size.y]
	size_label.add_theme_font_size_override("font_size", 10)
	size_label.add_theme_color_override("font_color", C_TEXT_DIM)
	vbox.add_child(size_label)
	
	card.add_child(vbox)
	card.gui_input.connect(func(event): _on_card_gui_input(event, module, card))
	return card

func _on_card_gui_input(event: InputEvent, module, card: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_drag(module, card.get_global_rect().position)

func _start_drag(module, start_pos: Vector2) -> void:
	dragging_module = module
	drag_start_pos = start_pos
	
	# Create preview
	drag_preview = _create_drag_preview(module)
	add_child(drag_preview)
	drag_preview.z_index = 1000
	drag_preview.global_position = get_global_mouse_position()

func _create_drag_preview(module) -> Control:
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Draw the module shape
	var bounds = module.get_grid_bounds()
	preview.custom_minimum_size = bounds.size * CELL_SIZE * DRAG_PREVIEW_SCALE
	
	var drawer := Control.new()
	drawer.custom_minimum_size = preview.custom_minimum_size
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	drawer.draw.connect(func():
		for offset in module.grid_shape:
			var rect = Rect2(offset * CELL_SIZE * DRAG_PREVIEW_SCALE, Vector2(CELL_SIZE * DRAG_PREVIEW_SCALE, CELL_SIZE * DRAG_PREVIEW_SCALE))
			drawer.draw_rect(rect, module.grid_cell_color)
			drawer.draw_rect(rect, Color.WHITE, false, 1.0)
	)
	
	preview.add_child(drawer)
	drawer.queue_redraw()
	
	return preview

func _input(event: InputEvent) -> void:
	if dragging_module:
		if event is InputEventMouseMotion:
			if drag_preview:
				drag_preview.global_position = get_global_mouse_position() - Vector2(CELL_SIZE, CELL_SIZE) * DRAG_PREVIEW_SCALE / 2
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_finish_drag()
			get_tree().root.set_input_as_handled()

func _finish_drag() -> void:
	if not dragging_module:
		return
	
	# Check if we're over the grid display
	var mouse_pos := get_global_mouse_position()
	if grid_display.get_global_rect().has_point(mouse_pos):
		_try_place_module(mouse_pos)
	
	# Clean up
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	dragging_module = null

func _try_place_module(world_pos: Vector2) -> void:
	var grid_rect = grid_display.get_global_rect()
	var dims = _GridLayout.get_grid_dimensions(current_grid_type)
	
	# Calculate grid cell position from world position
	var local_pos = world_pos - grid_rect.position
	var cell_x = int(local_pos.x / CELL_SIZE)
	var cell_y = int(local_pos.y / CELL_SIZE)
	var target_pos = Vector2i(cell_x, cell_y)
	
	# Validate placement
	if not dragging_module.can_fit_at(current_grid_state, target_pos, dims):
		return  # Can't place here
	
	# Place the module
	dragging_module.place_on_grid(current_grid_state, target_pos)
	
	# Update loadout
	var grid = mech_loadout.get_or_create_module_grid(current_torso_index)
	grid.place_module(dragging_module, target_pos)
	
	grid_display.queue_redraw()

func _on_grid_display_draw() -> void:
	var dims = _GridLayout.get_grid_dimensions(current_grid_type)
	var grid_shape = _GridLayout.get_grid_shape(current_grid_type)
	
	# Size the control to exactly fit the grid
	grid_display.custom_minimum_size = Vector2(dims.x * CELL_SIZE, dims.y * CELL_SIZE)
	
	for y in range(dims.y):
		for x in range(dims.x):
			var cell_pos = Vector2(x, y) * CELL_SIZE
			var rect = Rect2(cell_pos + Vector2(1, 1), Vector2(CELL_SIZE - 2, CELL_SIZE - 2))
			var outer = Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE))
			
			var is_valid_cell = Vector2i(x, y) in grid_shape
			
			if is_valid_cell:
				if current_grid_state[y][x] != null:
					var module = current_grid_state[y][x]
					grid_display.draw_rect(rect, module.grid_cell_color)
					grid_display.draw_rect(outer, module.grid_cell_color.lightened(0.3), false, 1.0)
				else:
					grid_display.draw_rect(rect, Color(0.18, 0.22, 0.28, 0.9))
					grid_display.draw_rect(outer, C_PANEL_BORDER, false, 1.0)
			else:
				grid_display.draw_rect(outer, Color(0.0, 0.0, 0.0, 0.2))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/workshop_screen.tscn")

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/utility_modules_screen.tscn")

func set_mech_loadout(loadout: MechLoadout) -> void:
	mech_loadout = loadout
	if is_node_ready():
		_load_modules()
		_setup_torso_selector()
		_select_torso(0)

