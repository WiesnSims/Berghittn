class_name StartScreen
extends Control
## Title screen (#77): the game's teaser behind, Solo, Co-op, Settings, the patch notes and das
## Gipfelbuch (the global leaderboard), with the
## version in a corner. Solo's click doubles as the
## user gesture browsers require for pointer lock (and audio). Until the hut's shaders are built
## (#78, ShaderWarmup) it shows only the still picture and how far that is: each new shader blocks the
## browser for a moment, so a live menu would stutter. Then the menu comes in and the picture moves.

signal play_requested
signal settings_requested
signal coop_requested

@onready var _solo: Button = %SoloButton
@onready var _coop: Button = %CoopButton

## How long the menu takes to fade in once everything is built (s).
const REVEAL_TIME: float = 0.4

var _ready_share: float = 0.0
var _revealed: bool = false
# Co-op: the match started without us clicking in yet; the button joins it.
var _join_mode: bool = false
var _version: Label
var _notes: PatchNotesPanel
var _board: BoardPanel


func _ready() -> void:
	_solo.pressed.connect(play_requested.emit)
	_coop.pressed.connect(coop_requested.emit)
	(%SettingsButton as Button).pressed.connect(settings_requested.emit)
	_version = Label.new()
	_version.text = tr("UI_VERSION") % PatchNotes.current()
	_version.add_theme_font_size_override("font_size", 16)
	_version.add_theme_color_override("font_color", Color(0.82, 0.8, 0.76))
	_version.add_theme_color_override("font_outline_color", Color.BLACK)
	_version.add_theme_constant_override("outline_size", 4)
	_version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_version)
	_notes = PatchNotesPanel.new()
	add_child(_notes)
	(%PatchNotesButton as Button).pressed.connect(_open_notes)
	_board = BoardPanel.new()
	add_child(_board)
	(%BoardButton as Button).pressed.connect(_board.open)
	Settings.changed.connect(_refresh_controls)
	_refresh_controls()
	set_ready(0.0)
	if GameState.notice != "":
		show_notice(GameState.notice)
		GameState.notice = ""


## A line above the title, e.g. why a co-op match ended.
func show_notice(text: String) -> void:
	(%Notice as Label).text = text
	(%Notice as Label).visible = text != ""


## How far the shaders are built (0..1); the menu waits for 1, so neither it nor the first room stalls.
func set_ready(share: float) -> void:
	_ready_share = share
	(%LoadingBar as ProgressBar).value = share
	if share >= 1.0 and not _revealed:
		_revealed = true
		_reveal()
	elif not _revealed:
		for item: Control in _menu_items():
			item.hide()
		(%Loading as Control).show()
		(%Backdrop as TeaserBackdrop).set_animated(false)
	_refresh()


func is_revealed() -> bool:
	return _revealed


func _reveal() -> void:
	(%Loading as Control).hide()
	for item: Control in _menu_items():
		item.show()
		item.modulate.a = 0.0
		create_tween().tween_property(item, "modulate:a", 1.0, REVEAL_TIME)
	_coop.visible = not _join_mode
	(%Backdrop as TeaserBackdrop).set_animated(true)


func _menu_items() -> Array[Control]:
	return [_solo, _coop, %SettingsButton, %PatchNotesButton, %BoardButton, %Controls]


## The controls line names the keys as they are bound (Keys).
func _refresh_controls() -> void:
	(%Controls as Label).text = Keys.fill(tr("UI_CONTROLS"))


## The patch notes; from now on this version counts as read.
func _open_notes() -> void:
	_notes.open()
	if Settings.seen_version != PatchNotes.current():
		Settings.seen_version = PatchNotes.current()
		Settings.save()
	_refresh()


## A co-op match started without our click (we are a guest): the button now joins it.
func set_join_mode(on: bool) -> void:
	_join_mode = on
	_coop.visible = not on and _revealed
	_refresh()


func _refresh() -> void:
	_solo.text = tr("UI_JOIN_MATCH") if _join_mode else tr("UI_SOLO")
	# Marked until this version's notes were opened once.
	var unread: bool = Settings.seen_version != PatchNotes.current()
	(%PatchNotesButton as Button).text = tr("UI_PATCH_NOTES_NEW") if unread else tr("UI_PATCH_NOTES")
