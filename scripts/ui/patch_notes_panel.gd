class_name PatchNotesPanel
extends Control
## The patch notes over the title screen (PatchNotes): every version, newest first, scrolling, and
## Back. Built in code; the start screen opens it.

signal closed

var _text: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# A dark board behind it, so the text reads over the moving title picture.
	var board := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, 0.94)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	board.add_theme_stylebox_override("panel", style)
	center.add_child(board)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	board.add_child(box)
	var title := Label.new()
	title.text = tr("UI_PATCH_NOTES")
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = true
	_text.custom_minimum_size = Constants.PATCH_NOTES_SIZE
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.add_theme_font_size_override("bold_font_size", 20)
	box.add_child(_text)
	var back := Button.new()
	back.text = tr("UI_BACK")
	back.custom_minimum_size = Vector2(220, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(close)
	box.add_child(back)
	hide()


func open() -> void:
	_text.text = PatchNotes.as_text()
	_text.scroll_to_line(0)
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
