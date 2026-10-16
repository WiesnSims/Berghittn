extends Node3D
## Play/pause/death flow. Browsers can revoke pointer lock at any time (Esc, tab switch),
## so the game state follows the actual mouse capture instead of the other way round.

enum State { MENU, CAPTURING, PLAYING, DEAD }

@onready var _player: Player = $Player
@onready var _hud: Hud = $UI/Hud
@onready var _start_screen: StartScreen = $UI/StartScreen
@onready var _pause_menu: PauseMenu = $UI/PauseMenu
@onready var _death_screen: DeathScreen = $UI/DeathScreen
@onready var _waves: WaveManager = $WaveManager

var _state: State = State.MENU


func _ready() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	_player.spawn_at(spawn.global_transform)
	_hud.bind_player(_player)
	_player.died.connect(_on_player_died)
	_start_screen.play_requested.connect(_request_play)
	_pause_menu.resume_requested.connect(_request_play)
	_death_screen.restart_requested.connect(_restart)
	_enter_menu()
	if GameState.has_started:
		# A restart already asked for pointer lock; go straight in once the browser grants it.
		_state = State.CAPTURING


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
	GameState.has_started = true
	_start_screen.hide()
	_pause_menu.hide()
	get_tree().paused = false


func _enter_menu() -> void:
	_state = State.MENU
	get_tree().paused = true
	_start_screen.visible = not GameState.has_started
	_pause_menu.visible = GameState.has_started


func _on_player_died() -> void:
	_state = State.DEAD
	# Let the fall play out with the world still running before freezing it under the death screen.
	await get_tree().create_timer(Constants.DEATH_SCREEN_DELAY).timeout
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_death_screen.present(_waves.wave, _player.points.total)


func _restart() -> void:
	# Request the lock inside the click so the reloaded scene can skip the menus.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()
