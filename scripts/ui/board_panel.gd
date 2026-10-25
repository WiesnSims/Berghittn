class_name BoardPanel
extends Control
## Das Gipfelbuch over the title screen (Board): the global leaderboard's top entries, Solo or Co-op,
## all time or this week, our own entries highlighted, and Back. Built in code like the patch notes.

signal closed

const HEADER_KEYS: Array[String] = [
	"UI_BOARD_PLACE", "UI_WERTUNG_NAME", "UI_BOARD_WAVE", "UI_WERTUNG_POINTS", "UI_DEATH_KILLS", "UI_DEATH_BSUNDAN",
	"UI_DEATH_FAVOURITE",
]
const HEADER_COLOR := Color(0.75, 0.7, 0.62)
const CELL_COLOR := Color(0.95, 0.92, 0.85)
const MINE_COLOR := Color(1.0, 0.86, 0.45)

var _mode: String = "solo"
var _period: String = "all"
var _mode_buttons: Dictionary = {}
var _period_buttons: Dictionary = {}
var _status: Label
var _grid: GridContainer
var _scroll: ScrollContainer


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
	var board := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, 0.94)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	board.add_theme_stylebox_override("panel", style)
	center.add_child(board)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	board.add_child(box)
	var title := Label.new()
	title.text = tr("UI_BOARD")
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	var modes := ButtonGroup.new()
	for mode: String in Board.MODES:
		_mode_buttons[mode] = _tab(tabs, "UI_SOLO" if mode == "solo" else "UI_COOP", modes, func() -> void: _show(mode, _period))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(40, 0)
	tabs.add_child(gap)
	var periods := ButtonGroup.new()
	for period: String in Board.PERIODS:
		_period_buttons[period] = _tab(tabs, "UI_BOARD_ALL" if period == "all" else "UI_BOARD_WEEK", periods, func() -> void: _show(_mode, period))
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Constants.BOARD_PANEL_SIZE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(column)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	column.add_child(_status)
	_grid = GridContainer.new()
	_grid.columns = HEADER_KEYS.size()
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_grid)
	var back := Button.new()
	back.text = tr("UI_BACK")
	back.custom_minimum_size = Vector2(220, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(close)
	box.add_child(back)
	Board.listed.connect(_on_listed)
	hide()


## Opens on `mode`'s board ("solo" or "coop"), or the one last shown.
func open(mode: String = "") -> void:
	show()
	_show(mode if mode in Board.MODES else _mode, _period)


func close() -> void:
	hide()
	closed.emit()


## The board for `mode` and `period`, fresh from the server.
func _show(mode: String, period: String) -> void:
	_mode = mode
	_period = period
	(_mode_buttons[mode] as Button).set_pressed_no_signal(true)
	(_period_buttons[period] as Button).set_pressed_no_signal(true)
	_clear()
	_status.text = tr("UI_BOARD_LOADING")
	_status.show()
	Board.fetch(mode, period)


func _on_listed(mode: String, period: String, entries: Array, ok: bool) -> void:
	# An answer for a board no longer shown (the player clicked on) is left out.
	if mode != _mode or period != _period or not visible:
		return
	_clear()
	_status.visible = not ok or entries.is_empty()
	_status.text = tr("UI_BOARD_OFFLINE") if not ok else tr("UI_BOARD_EMPTY")
	if _status.visible:
		return
	for key: String in HEADER_KEYS:
		_grid.add_child(_cell(tr(key), HEADER_COLOR))
	for i: int in entries.size():
		var entry: Dictionary = entries[i] if entries[i] is Dictionary else {}
		var color: Color = MINE_COLOR if int(entry.get("id", 0)) in Settings.board_ids else CELL_COLOR
		var names: PackedStringArray = []
		for player_name: Variant in entry.get("names", []):
			names.append(str(player_name))
		var fav: String = str(entry.get("fav", ""))
		for text: String in [
			str(i + 1), ", ".join(names), str(int(entry.get("wave", 0))), str(int(entry.get("points", 0))),
			str(int(entry.get("kills", 0))), str(int(entry.get("bsundan", 0))), tr(fav) if fav != "" else tr("UI_DEATH_NONE"),
		]:
			_grid.add_child(_cell(text, color))
	_scroll.scroll_vertical = 0


func _clear() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


func _tab(parent: Control, key: String, group: ButtonGroup, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = key
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(160, 42)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func _cell(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	# Names come from players and are shown as they are, not looked up.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", Constants.BOARD_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
