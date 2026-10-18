extends Node3D
## Play/pause/death flow. Browsers can revoke pointer lock at any time (Esc, tab switch),
## so the game state follows the actual mouse capture instead of the other way round.

enum State { MENU, CAPTURING, PLAYING, DEAD }

@onready var _player: Player = $Player
@onready var _hud: Hud = $UI/Hud
@onready var _start_screen: StartScreen = $UI/StartScreen
@onready var _pause_menu: PauseMenu = $UI/PauseMenu
@onready var _death_screen: DeathScreen = $UI/DeathScreen
@onready var _settings_menu: SettingsMenu = $UI/SettingsMenu
@onready var _waves: WaveManager = $WaveManager
@onready var _lobby: Lobby = $UI/Lobby
@onready var _warmup: ShaderWarmup = $ShaderWarmup

var _state: State = State.MENU
# This scene runs (or ran) a co-op match: Net.in_match() turns false the moment the session ends.
var _coop: bool = false


func _ready() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	_player.spawn_at(spawn.global_transform)
	_hud.bind_player(_player)
	_warmup.progress.connect(_start_screen.set_ready)
	_player.died.connect(_on_player_died)
	_start_screen.play_requested.connect(_request_play)
	_pause_menu.resume_requested.connect(_request_play)
	_death_screen.restart_requested.connect(_restart)
	_start_screen.settings_requested.connect(_settings_menu.open)
	_pause_menu.settings_requested.connect(_settings_menu.open)
	_start_screen.coop_requested.connect(_open_lobby)
	_pause_menu.leave_requested.connect(Net.leave)
	_lobby.closed.connect(_enter_menu)
	Net.match_started.connect(_on_match_started)
	Net.ended.connect(_on_net_ended)
	_enter_menu()
	if GameState.pending_match and Net.in_match():
		# The host started again while this browser still showed the last match's end.
		GameState.pending_match = false
		_on_match_started.call_deferred()
	elif GameState.open_lobby and Net.in_lobby():
		GameState.open_lobby = false
		_open_lobby()
	elif GameState.has_started:
		# A restart already asked for pointer lock; go straight in once the browser grants it.
		_state = State.CAPTURING
	elif not GameState.invite_used:
		# Opened from an invite link (?room=4711): straight into that room's lobby.
		GameState.invite_used = true
		var room: String = Net.room_from_url()
		if room != "":
			_join_from_invite(room)


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
	# Into the game before the shaders are all built (a co-op start): the rest in one go now.
	if is_instance_valid(_warmup):
		_warmup.finish_now()
	GameState.has_started = true
	_start_screen.hide()
	_pause_menu.hide()
	get_tree().paused = false


func _enter_menu() -> void:
	_state = State.MENU
	# One player's menu must not freeze the world for everyone else.
	get_tree().paused = not _coop
	_start_screen.visible = not GameState.has_started
	_pause_menu.visible = GameState.has_started


## The lobby (and the game) only once the shaders are built: the title shows how far that is.
func _join_from_invite(room: String) -> void:
	if is_instance_valid(_warmup) and not _start_screen.is_revealed():
		await _warmup.finished
	_open_lobby()
	_lobby.join(room)


func _open_lobby() -> void:
	_start_screen.hide()
	_lobby.open()


func _on_match_started() -> void:
	if _coop:
		# This scene already ran a match; the new one starts in a fresh one.
		GameState.pending_match = true
		get_tree().paused = false
		get_tree().reload_current_scene.call_deferred()
		return
	_coop = true
	_lobby.hide()
	_death_screen.hide()
	_setup_coop()
	# The world runs for everyone from now on, whether or not this browser has its pointer lock yet.
	get_tree().paused = false
	if Net.is_host():
		# The host's Start click is the gesture the browser wants for pointer lock.
		_request_play()
	else:
		_start_screen.set_join_mode(true)
		_enter_menu()


## The host runs the waves; guests play the host's world back (CoopEnemies, CoopWorld). The events
## (section 8a) come to co-op with M7 part 3.
func _setup_coop() -> void:
	if not Net.is_host():
		_waves.process_mode = Node.PROCESS_MODE_DISABLED
	($EventDirector as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var peers: Array = Net.roster.keys()
	peers.sort()
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	var slot: float = float(peers.find(Net.my_id())) - float(peers.size() - 1) * 0.5
	_player.spawn_at(spawn.global_transform.translated_local(Vector3.RIGHT * slot * Constants.NET_SPAWN_SPACING))
	var players := CoopPlayers.new()
	players.name = "CoopPlayers"
	add_child(players)
	players.setup(_player)
	var enemies := CoopEnemies.new()
	enemies.name = "CoopEnemies"
	add_child(enemies)
	enemies.setup(_waves)
	var world := CoopWorld.new()
	world.name = "CoopWorld"
	add_child(world)
	world.setup(self, _waves, $Zones as ZoneMap)
	world.game_over.connect(_on_coop_over)


## Everyone is down or out: the match is over; all go back to the same room's lobby from here.
func _on_coop_over(wave: int) -> void:
	_state = State.DEAD
	await get_tree().create_timer(Constants.DEATH_SCREEN_DELAY).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_menu.hide()
	_hud.end_coop()
	_death_screen.present(wave, _player.points.total, true)
	Net.back_to_lobby()


func _on_net_ended(reason: String) -> void:
	if not _coop:
		return
	# Back to the title screen, saying why (unless we left ourselves).
	GameState.notice = "" if reason == "left" else Lobby.reason_text(reason)
	GameState.has_started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()


func _on_player_died() -> void:
	_state = State.DEAD
	# Let the fall play out with the world still running before freezing it under the death screen.
	await get_tree().create_timer(Constants.DEATH_SCREEN_DELAY).timeout
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_death_screen.present(_waves.wave, _player.points.total)


func _restart() -> void:
	if _coop:
		# Co-op: back to the room's lobby, in a fresh scene.
		GameState.has_started = false
		GameState.open_lobby = true
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	# Request the lock inside the click so the reloaded scene can skip the menus.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()
