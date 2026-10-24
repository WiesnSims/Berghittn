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
	(%CopyLinkButton as Button).pressed.connect(_copy_link)
	_relock_timer.wait_time = Constants.POINTER_RELOCK_DELAY
	_relock_timer.timeout.connect(_on_relock_timeout)
	visibility_changed.connect(_on_visibility_changed)
	Settings.changed.connect(_refresh_controls)
	_refresh_controls()


## The controls line names the keys as they are bound (Keys).
func _refresh_controls() -> void:
	($Center/Box/Controls as Label).text = Keys.fill(tr("UI_CONTROLS"))


func _on_visibility_changed() -> void:
	if not visible:
		return
	(%LeaveButton as Button).visible = Net.in_match()
	# Co-op: the room and its invite link, for a friend who wants in on the next match (M9).
	(%Invite as Control).visible = Net.in_match()
	(%Room as Label).text = tr("UI_LOBBY_ROOM") % Net.code
	(%InviteHint as Control).hide()
	# Browsers reject a pointer lock request made right after the user exited one,
	# so keep Resume disabled until it would actually work.
	_resume_button.disabled = true
	_relock_timer.start()


func _copy_link() -> void:
	DisplayServer.clipboard_set(Net.invite_url())
	(%InviteHint as Control).show()


func _on_relock_timeout() -> void:
	_resume_button.disabled = false
	_resume_button.grab_focus()
