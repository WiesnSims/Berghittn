class_name PauseMenu
extends Control

signal resume_requested
signal settings_requested
## Co-op only: leave the match (and the room) for the title screen.
signal leave_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _relock_timer: Timer = $RelockTimer


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	(%SettingsButton as Button).pressed.connect(settings_requested.emit)
	(%LeaveButton as Button).pressed.connect(leave_requested.emit)
	_relock_timer.wait_time = Constants.POINTER_RELOCK_DELAY
	_relock_timer.timeout.connect(_on_relock_timeout)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if not visible:
		return
	(%LeaveButton as Button).visible = Net.in_match()
	# Browsers reject a pointer lock request made right after the user exited one,
	# so keep Resume disabled until it would actually work.
	_resume_button.disabled = true
	_relock_timer.start()


func _on_relock_timeout() -> void:
	_resume_button.disabled = false
	_resume_button.grab_focus()
