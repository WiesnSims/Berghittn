class_name StartScreen
extends Control
## Title overlay. The first click doubles as the user gesture browsers require for pointer lock (and later audio).

signal play_requested
signal settings_requested


func _ready() -> void:
	(%SettingsButton as Button).pressed.connect(settings_requested.emit)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		play_requested.emit()
