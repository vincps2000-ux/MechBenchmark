# level_select_screen.gd — Mission / level selection after the workshop
extends Control

@onready var level_cards: HBoxContainer = %LevelCards
@onready var back_button: Button        = %BackButton

const LEVELS := [
	{
		"name":        "TESTING AREA",
		"description": "Practice your mech in a controlled environment.\nShoot targets, test weapons, learn controls.",
		"scene":       "res://scenes/levels/gameplay.tscn",
		"color":       Color(0.85, 0.65, 0.1),
	},
	{
		"name":        "LEVEL 1",
		"description": "The first real mission.\nSurvive waves of enemies in the wasteland.",
		"scene":       "res://scenes/levels/level_1.tscn",
		"color":       Color(0.3, 0.7, 0.5),
	},
	{
		"name":        "LEVEL 2",
		"description": "Storm the trenches.\nPush from the south line and reach the northern edge while enemies reinforce from above.",
		"scene":       "res://scenes/levels/level_2.tscn",
		"color":       Color(0.55, 0.72, 0.34),
	},
	{
		"name":        "LEVEL 3",
		"description": "The Duel.\nFace a single enemy in a forest clearing. One on one.",
		"scene":       "res://scenes/levels/level_3.tscn",
		"color":       Color(0.30, 0.58, 0.22),
	},
	{
		"name":        "COLUMNN AMBUSH",
		"description": "Five tanks are crossing from west to east on a curved route.\nYou lose if one breaks through. Win by destroying all five.",
		"scene":       "res://scenes/levels/level_4.tscn",
		"color":       Color(0.86, 0.62, 0.24),
	},
]

# ─── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

	back_button.pressed.connect(_on_back_pressed)
	_build_level_cards()

# ─── Card builder ───────────────────────────────────────────────────────────────

func _build_level_cards() -> void:
	for level in LEVELS:
		var card := _create_level_card(level)
		level_cards.add_child(card)

func _create_level_card(data: Dictionary) -> PanelContainer:
	var accent: Color = data.color

	# ── Panel ────────────────────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.92)
	style.set_border_width_all(3)
	style.border_color = accent * 0.5
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size  = 8
	panel.add_theme_stylebox_override("panel", style)

	# ── Inner margin ─────────────────────────────────────────────────────
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# ── Level name ───────────────────────────────────────────────────────
	var name_label := Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", accent)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# ── Separator ────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator_color", accent * 0.35)
	vbox.add_child(sep)

	# ── Description ──────────────────────────────────────────────────────
	var desc := Label.new()
	desc.text = data.description
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# ── Spacer ───────────────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# ── Deploy button ────────────────────────────────────────────────────
	var button := Button.new()
	button.text = "DEPLOY  ▸"
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.92))

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = accent * 0.65
	btn_normal.set_border_width_all(2)
	btn_normal.border_color = accent
	btn_normal.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = accent * 0.85
	button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = accent * 0.45
	button.add_theme_stylebox_override("pressed", btn_pressed)

	button.pressed.connect(_on_level_selected.bind(data.scene))
	vbox.add_child(button)

	# ── Hover glow on the whole card ─────────────────────────────────────
	panel.mouse_entered.connect(_on_card_hover.bind(panel, style, accent))
	panel.mouse_exited.connect(_on_card_unhover.bind(panel, style, accent))

	return panel

# ─── Card hover ─────────────────────────────────────────────────────────────────

func _on_card_hover(panel: PanelContainer, style: StyleBoxFlat, accent: Color) -> void:
	style.border_color = accent
	style.shadow_size  = 14
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "scale", Vector2(1.03, 1.03), 0.15)

func _on_card_unhover(panel: PanelContainer, style: StyleBoxFlat, accent: Color) -> void:
	style.border_color = accent * 0.5
	style.shadow_size  = 8
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15)

# ─── Navigation ─────────────────────────────────────────────────────────────────

func _on_level_selected(scene_path: String) -> void:
	# Disable all buttons so the player can't double-click
	back_button.disabled = true
	for card in level_cards.get_children():
		card.set_process_input(false)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		GameManager.start_game()
		get_tree().change_scene_to_file(scene_path)
	)

func _on_back_pressed() -> void:
	back_button.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/ui/software_screen.tscn")
	)
