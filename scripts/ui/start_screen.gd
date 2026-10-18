class_name StartScreen
extends Control
## Title screen (#77): the game's teaser behind, Solo, Co-op and Settings. Solo's click doubles as the
## user gesture browsers require for pointer lock (and audio). It waits until the hut's shaders are
## built (#78, ShaderWarmup) and shows how far that is.

signal play_requested
signal settings_requested
signal coop_requested

@onready var _solo: Button = %SoloButton
@onready var _coop: Button = %CoopButton

var _ready_share: float = 0.0
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


## How far the shaders are built (0..1); playing alone waits for 1, so the first room does not stall.
func set_ready(share: float) -> void:
	_ready_share = share
	_refresh()


## A co-op match started without our click (we are a guest): the button now joins it.
func set_join_mode(on: bool) -> void:
	_join_mode = on
	_coop.visible = not on
	_refresh()


func _refresh() -> void:
	var done: bool = _ready_share >= 1.0
	# Joining a running match does not wait: the others are already playing.
	_solo.disabled = not done and not _join_mode
	if _join_mode:
		_solo.text = tr("UI_JOIN_MATCH")
	elif done:
		_solo.text = tr("UI_SOLO")
	else:
		_solo.text = tr("UI_PREPARING") % roundi(_ready_share * 100.0)
