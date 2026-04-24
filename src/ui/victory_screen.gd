# victory_screen.gd — Reusable mission-complete overlay with workshop navigation.
extends Control
class_name VictoryScreen

const WORKSHOP_SCENE_PATH := "res://scenes/ui/workshop_screen.tscn"

var _title_text: String = "MISSION COMPLETE"
var _message_text: String = ""
var _auto_return_delay: float = 2.0
var _is_returning: bool = false

var _panel: PanelContainer
var _title_label: Label
var _message_label: Label
var _button: Button

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func configure(title_text: String, message_text: String, auto_return_delay: float = 2.0) -> void:
	_title_text = title_text
	_message_text = message_text
	_auto_return_delay = auto_return_delay
	if _title_label:
		_title_label.text = _title_text
	if _message_label:
		_message_label.text = _message_text

func show_victory() -> void:
	if _is_returning:
		return
	visible = true
	if _title_label:
		_title_label.text = _title_text
	if _message_label:
		_message_label.text = _message_text
	if _button:
		_button.grab_focus()
	if _auto_return_delay > 0.0:
		var return_timer := get_tree().create_timer(_auto_return_delay)
		return_timer.timeout.connect(_return_to_workshop)

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.01, 0.02, 0.62)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.custom_minimum_size = Vector2(420.0, 0.0)
	_panel.position = Vector2(-210.0, -120.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	panel_style.border_color = Color(0.87, 0.64, 0.23, 0.9)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = _title_text
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58, 1.0))
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)

	_message_label = Label.new()
	_message_label.text = _message_text
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color(0.83, 0.84, 0.86, 0.92))
	_message_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_message_label)

	_button = Button.new()
	_button.text = "BACK TO WORKSHOP"
	_button.custom_minimum_size = Vector2(0.0, 48.0)
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(_return_to_workshop)
	vbox.add_child(_button)

func _return_to_workshop() -> void:
	if _is_returning:
		return
	_is_returning = true
	if get_tree():
		get_tree().change_scene_to_file(WORKSHOP_SCENE_PATH)
