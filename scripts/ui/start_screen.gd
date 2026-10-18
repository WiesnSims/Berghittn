class_name StartScreen
extends Control
## Title overlay. The first click doubles as the user gesture browsers require for pointer lock (and later audio).

signal play_requested
signal settings_requested
signal coop_requested


func _ready() -> void:
	(%SettingsButton as Button).pressed.connect(settings_requested.emit)
	(%CoopButton as Button).pressed.connect(coop_requested.emit)
	if GameState.notice != "":
		show_notice(GameState.notice)
		GameState.notice = ""


## A line above the title, e.g. why a co-op match ended.
func show_notice(text: String) -> void:
	(%Notice as Label).text = text
	(%Notice as Label).visible = text != ""


## A co-op match started without our click (we are a guest): the click now only joins it.
func set_join_mode(on: bool) -> void:
	(%ClickToPlay as Label).text = "UI_CLICK_TO_JOIN" if on else "UI_CLICK_TO_PLAY"
	(%CoopButton as Button).visible = not on


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		play_requested.emit()
