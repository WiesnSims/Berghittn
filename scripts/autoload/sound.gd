extends Node
## Every sound in the game (M6 part 2), all synthesised by tools/audio/build.py. A sound is named by
## its id; the files are res://assets/audio/<folder>/<id>_<n>.ogg and a random variant plays each time
## (never the same one twice in a row). The folder picks the bus: sfx = Effects, ambience = Ambience,
## music = Music.
## play(): what the player hears as themselves (their own gun, a purchase): no position.
## play_at(): a sound out in the world, quieter with distance.
## attach(): a looping sound that rides along on a node (a ringing bell, a rolling barrel) until the
## caller frees it or the node goes.

const ROOT: String = "res://assets/audio/%s/"
const FOLDERS: Dictionary = {"sfx": &"Effects", "ambience": &"Ambience", "music": &"Music"}
## Sounds that loop: attached ones, the band, the wind.
const LOOPS: Array[StringName] = [
	&"flame_loop", &"kuhglocke_ring", &"resi_bell", &"eisstock_slide", &"fassl_roll", &"wind_loop",
	&"fire_crackle", &"harmonika_play", &"band_menu",
]
## Level per sound in dB: the synth writes every file at full scale, this sets the balance.
const MIX: Dictionary = {
	&"shot_pistole": 0.0, &"shot_jagdflinte": 2.0, &"shot_jagdflinte_both": 3.0, &"shot_stutzen": 1.0,
	&"shot_repetierer": 1.0, &"dry_click": -6.0, &"mag_out": -8.0, &"mag_in": -6.0, &"break_open": -6.0,
	&"break_close": -6.0, &"bolt_open": -6.0, &"bolt_close": -6.0, &"lever_open": -4.0,
	&"lever_close": -6.0, &"load_clunk": -8.0, &"ricochet": -6.0, &"load_ready": -8.0, &"weapon_raise": -10.0,
	&"hitmarker": -12.0, &"headshot": -9.0, &"kill_thock": -8.0, &"kill_bumm": -6.0, &"bellows": -8.0, &"alphorn_load": -8.0,
	&"swing": -9.0, &"throw": -8.0, &"schaufel_hit": -3.0, &"pfanne_bonk": -2.0, &"goassl_crack": 2.0,
	&"mistgabel_stab": -2.0, &"rute_hit": 0.0, &"block_hit": -3.0,
	&"alphorn_blast": -1.0, &"alphorn_echo": -1.0, &"knoedel_launch": -5.0, &"knoedel_splat": -4.0, &"knoedel_ready": -8.0,
	&"rodel_launch": -4.0, &"rodel_hit": -3.0, &"flame_loop": -8.0, &"flame_start": -5.0,
	&"boeller_launch": 1.0, &"boeller_bang": 4.0, &"harmonika_polka": -3.0, &"harmonika_play": -4.0, &"harmonika_chord": -4.0,
	&"kuhglocke_ring": -5.0, &"resi_bell": -3.0, &"eisstock_slide": -6.0, &"eisstock_hit": -2.0,
	&"kuhfladen_splat": -4.0, &"kuhfladen_squelch": -4.0,
	&"groan_wanderer": -6.0, &"groan_knappe": -6.0, &"groan_perchte": -7.0, &"groan_tourist": -8.0,
	&"krampus_roar": 0.0, &"chains": -6.0, &"enemy_death": -5.0, &"enemy_attack": -6.0,
	&"board_pull": -4.0, &"board_nail": -6.0, &"window_climb": -7.0,
	&"player_hurt": -4.0, &"player_death": -2.0, &"step_snow": -17.0, &"step_wood": -15.0, &"land": -5.0,
	&"buy": -7.0, &"deny": -9.0, &"door_open": -2.0, &"creak": -12.0, &"chest_open": -4.0,
	&"chest_tick": -10.0, &"chest_reveal": -6.0, &"anvil_clang": -6.0, &"dengel_quench": -6.0, &"perk_drink": -4.0, &"jause_eat": -4.0,
	&"ammo_crate": -4.0, &"ui_click": -12.0, &"wave_start": -5.0, &"boss_wave": -2.0,
	&"resi_moo": -2.0, &"milk": -6.0, &"fassl_roll": -3.0, &"fassl_tap": -4.0,
	&"murmeltier_scream": 1.0, &"murmeltier_pop": -6.0, &"murmeltier_hit": -4.0, &"camera": -6.0,
	&"event_call": -6.0, &"wind_loop": -6.0, &"fire_crackle": -8.0,
	# The band 25 % down (play-test 2026-10-18).
	&"band_menu": -11.5, &"band_1": -2.5, &"band_2": -2.5, &"band_3": -2.5, &"band_4": -2.5,
	&"band_5": -2.5, &"band_6": -2.5, &"band_7": -2.5, &"band_8": -2.5, &"game_over": -6.5,
}
## At most this many of one sound at once; another one takes over the oldest. Keeps a horde from
## drowning out everything else.
const DEFAULT_VOICES: int = 4
const VOICES: Dictionary = {
	&"groan_wanderer": 2, &"groan_knappe": 2, &"groan_perchte": 2, &"groan_tourist": 2,
	&"krampus_roar": 1, &"enemy_death": 3, &"enemy_attack": 2, &"hitmarker": 2, &"step_snow": 1,
	&"step_wood": 1, &"creak": 1, &"board_pull": 2,
}

var _streams: Dictionary = {}
var _bus: Dictionary = {}
var _last_variant: Dictionary = {}
# When each sound last started (on _clock), so one that is triggered several times at once plays once.
var _started: Dictionary = {}
# Seconds of game time (frame deltas, so tests at a fixed frame rate count the same as play).
var _clock: float = 0.0
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
# Menu sounds keep playing while the game is paused under them.
var _pool_ui: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for folder: String in FOLDERS:
		_scan(folder)
	for i: int in Constants.SOUND_POOL_2D:
		_pool_2d.append(_add_player(AudioStreamPlayer.new(), Node.PROCESS_MODE_PAUSABLE))
	for i: int in Constants.SOUND_POOL_UI:
		_pool_ui.append(_add_player(AudioStreamPlayer.new(), Node.PROCESS_MODE_ALWAYS))
	for i: int in Constants.SOUND_POOL_3D:
		var player := AudioStreamPlayer3D.new()
		_setup_3d(player)
		_pool_3d.append(_add_player(player, Node.PROCESS_MODE_PAUSABLE))
	# Every button in every menu clicks.
	get_tree().node_added.connect(_on_node_added)


func has(id: StringName) -> bool:
	return _streams.has(id)


## A random variant of a sound (for players the caller owns, like the band's).
func stream(id: StringName) -> AudioStream:
	var variants: Array = _streams.get(id, [])
	if variants.is_empty():
		return null
	var index: int = _rng.randi_range(0, variants.size() - 1)
	if variants.size() > 1 and index == _last_variant.get(id, -1):
		index = (index + 1) % variants.size()
	_last_variant[id] = index
	return variants[index]


func bus_of(id: StringName) -> StringName:
	return _bus.get(id, &"Effects")


func level(id: StringName) -> float:
	return MIX.get(id, 0.0)


## The player's own sound, no position. `ui` ones also play while the game is paused (menus).
## Like play_at, a sound already started a moment ago is not started again (see _stacked).
func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0, ui: bool = false) -> AudioStreamPlayer:
	if id == &"" or not has(id) or _stacked(id):
		return null
	var player := _take(_pool_ui if ui else _pool_2d, id) as AudioStreamPlayer
	_start(player, id, volume_db, pitch)
	return player


## A sound out in the world at `at`.
func play_at(id: StringName, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	if id == &"" or not has(id) or _stacked(id):
		return null
	var player := _take(_pool_3d, id) as AudioStreamPlayer3D
	player.global_position = at
	_start(player, id, volume_db, pitch)
	return player


## A sound that plays (looping, if it is a loop) on `node` and moves with it. The caller frees the
## returned player to stop it; it also goes when the node does. `reach` > 0 makes it carry that far
## (metres) and fall off far more slowly, for sounds the whole map must hear.
func attach(id: StringName, node: Node3D, volume_db: float = 0.0, reach: float = 0.0) -> AudioStreamPlayer3D:
	if id == &"" or not has(id) or node == null:
		return null
	var player := AudioStreamPlayer3D.new()
	_setup_3d(player)
	if reach > 0.0:
		player.max_distance = reach
		player.unit_size = reach * Constants.SOUND_FAR_UNIT_SHARE
	player.stream = stream(id)
	player.bus = bus_of(id)
	player.volume_db = level(id) + volume_db
	node.add_child(player)
	player.play()
	return player


# The same sound triggered again within SOUND_STACK_TIME (one blow striking four enemies, a barrel
# flattening a crowd) is one sound, not four piled up and four times as loud (play-test 2026-10-18).
func _stacked(id: StringName) -> bool:
	if _clock - _started.get(id, -1000.0) < Constants.SOUND_STACK_TIME:
		return true
	_started[id] = _clock
	return false


func _process(delta: float) -> void:
	_clock += delta


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play(&"ui_click", 0.0, 1.0, true)


func _scan(folder: String) -> void:
	var directory: String = ROOT % folder
	# list_directory gives the source names in exports too (not the .import remaps).
	for file: String in ResourceLoader.list_directory(directory):
		if not file.ends_with(".ogg"):
			continue
		var stem: String = file.get_basename()
		# name_3 -> name: the number is the variant.
		var id := StringName(stem.substr(0, stem.rfind("_")))
		var loaded := load(directory + file) as AudioStream
		if loaded == null:
			continue
		if loaded is AudioStreamOggVorbis:
			(loaded as AudioStreamOggVorbis).loop = id in LOOPS
		if not _streams.has(id):
			_streams[id] = []
		_streams[id].append(loaded)
		_bus[id] = FOLDERS[folder]


func _add_player(player: Node, mode: Node.ProcessMode) -> Node:
	player.process_mode = mode
	add_child(player)
	return player


func _setup_3d(player: AudioStreamPlayer3D) -> void:
	player.unit_size = Constants.SOUND_UNIT_SIZE
	player.max_distance = Constants.SOUND_MAX_DISTANCE
	player.attenuation_filter_cutoff_hz = Constants.SOUND_DISTANCE_CUTOFF
	player.panning_strength = 0.8


# A free player; at the cap for this sound, or with all of them busy, the one playing longest.
func _take(pool: Array, id: StringName) -> Node:
	var cap: int = VOICES.get(id, DEFAULT_VOICES)
	var same: Array = []
	var free: Node = null
	var oldest: Node = pool[0]
	for player: Node in pool:
		var busy: bool = player.call("is_playing")
		if busy and player.get_meta(&"id", &"") == id:
			same.append(player)
		elif not busy and free == null:
			free = player
		if player.get_meta(&"since", 0) < oldest.get_meta(&"since", 0):
			oldest = player
	if same.size() >= cap:
		var first: Node = same[0]
		for player: Node in same:
			if player.get_meta(&"since", 0) < first.get_meta(&"since", 0):
				first = player
		return first
	return free if free else oldest


func _start(player: Node, id: StringName, volume_db: float, pitch: float) -> void:
	player.set("stream", stream(id))
	player.set("bus", bus_of(id))
	player.set("volume_db", level(id) + volume_db)
	var jitter: float = 0.0 if bus_of(id) == &"Music" else Constants.SOUND_PITCH_JITTER
	player.set("pitch_scale", pitch * (1.0 + _rng.randf_range(-jitter, jitter)))
	player.set_meta(&"id", id)
	player.set_meta(&"since", Time.get_ticks_usec())
	player.call("play")
