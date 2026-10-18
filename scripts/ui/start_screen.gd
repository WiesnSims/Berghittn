class_name StartScreen
extends Control
## Title screen (#77): the game's teaser behind, Solo, Co-op and Settings. Solo's click doubles as the
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


func _ready() -> void:
	_solo.pressed.connect(play_requested.emit)
	_coop.pressed.connect(coop_requested.emit)
	(%SettingsButton as Button).pressed.connect(settings_requested.emit)
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
	return [_solo, _coop, %SettingsButton, %Controls]


## A co-op match started without our click (we are a guest): the button now joins it.
func set_join_mode(on: bool) -> void:
	_join_mode = on
	_coop.visible = not on and _revealed
	_refresh()


func _refresh() -> void:
	_solo.text = tr("UI_JOIN_MATCH") if _join_mode else tr("UI_SOLO")
