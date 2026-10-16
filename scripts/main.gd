extends Node3D
## Play/pause flow. Browsers can revoke pointer lock at any time (Esc, tab switch),
## so the game state follows the actual mouse capture instead of the other way round.

enum State { MENU, CAPTURING, PLAYING }

@onready var _player: Player = $Player
@onready var _start_screen: StartScreen = $UI/StartScreen
@onready var _pause_menu: PauseMenu = $UI/PauseMenu

var _state: State = State.MENU
var _has_started: bool = false


func _ready() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	_player.spawn_at(spawn.global_transform)
	_start_screen.play_requested.connect(_request_play)
	_pause_menu.resume_requested.connect(_request_play)
	_enter_menu()


func _process(_delta: float) -> void:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _state == State.CAPTURING and captured:
		_enter_playing()
	elif _state == State.PLAYING and not captured:
		_enter_menu()


func _unhandled_input(event: InputEvent) -> void:
	# In browsers Esc never reaches us (it just exits pointer lock); this covers desktop runs and the P key.
	if _state == State.PLAYING and event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _request_play() -> void:
	# Stay in the menu until the browser confirms the lock; if it refuses, the player can just click again.
	_state = State.CAPTURING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _enter_playing() -> void:
	_state = State.PLAYING
	_has_started = true
	_start_screen.hide()
	_pause_menu.hide()
	get_tree().paused = false


func _enter_menu() -> void:
	_state = State.MENU
	get_tree().paused = true
	_start_screen.visible = not _has_started
	_pause_menu.visible = _has_started
