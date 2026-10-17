class_name BandDirector
extends Node
## The hut's brass band (section 11, M6 part 2): "Da Berghittn-Polka" (tools/audio/music.py), played
## off an old gramophone. A slow take under the title screen; each wave the hut bell rings and the band
## strikes up, faster every wave (one tempo tier per wave, then a little higher and faster still);
## a cleared wave ends on a "ta-da" and the break stays quiet but for the storm; at game over the
## record winds down.

const TIERS: int = 8

# Two players, so one tune fades into the next.
var _players: Array[AudioStreamPlayer] = []
var _current: int = 0
var _tweens: Array[Tween] = [null, null]
var _in_menu: bool = false


func _ready() -> void:
	# Plays on behind the pause menu and the death screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_players.append(player)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.player_died.connect(_on_player_died)
	if not GameState.has_started:
		_in_menu = true
		_play(&"band_menu", 1.0)


# Stopped before the engine shuts down, or the running playback outlives the audio server.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()


func _process(_delta: float) -> void:
	# The title tune makes way once the player is in.
	if _in_menu and GameState.has_started:
		_in_menu = false
		_fade_out()


## The tempo tier (1..TIERS) and the pitch the band plays at in a wave.
static func tier_for(wave: int) -> int:
	return clampi(wave, 1, TIERS)


static func pitch_for(wave: int) -> float:
	return minf(1.0 + maxi(wave - TIERS, 0) * Constants.BAND_PITCH_PER_WAVE, Constants.BAND_PITCH_MAX)


## The tune playing now ("" when silent).
func playing_tune() -> StringName:
	var player: AudioStreamPlayer = _players[_current]
	return player.get_meta(&"tune", &"") if player.playing else &""


func _on_wave_started(wave: int, is_boss_wave: bool) -> void:
	_in_menu = false
	Sound.play(&"boss_wave" if is_boss_wave else &"wave_start")
	_play(StringName("band_%d" % tier_for(wave)), pitch_for(wave))


func _on_wave_cleared(_wave: int) -> void:
	_fade_out()
	Sound.play(&"wave_cleared")


func _on_player_died(_player: Node3D) -> void:
	_fade_out(0.3)
	# A menu sound: the tree pauses under the death screen while it still plays.
	Sound.play(&"game_over", 0.0, 1.0, true)


func _play(tune: StringName, pitch: float) -> void:
	if not Sound.has(tune):
		return
	_fade_out()
	_current = 1 - _current
	var player: AudioStreamPlayer = _players[_current]
	player.stream = Sound.stream(tune)
	player.pitch_scale = pitch
	player.set_meta(&"tune", tune)
	player.volume_db = -40.0
	player.play()
	_fade(_current, Sound.level(tune), Constants.BAND_FADE_TIME)


func _fade_out(time: float = Constants.BAND_FADE_TIME) -> void:
	if _players[_current].playing:
		_fade(_current, -40.0, time, true)


func _fade(index: int, to_db: float, time: float, stop_after: bool = false) -> void:
	if _tweens[index]:
		_tweens[index].kill()
	var player: AudioStreamPlayer = _players[index]
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, time)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens[index] = tween
