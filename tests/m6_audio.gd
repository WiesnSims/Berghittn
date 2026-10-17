extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m6_audio.tscn
## Headless check of the sound (M6 part 2) on the real main scene: every sound the weapons, enemies and
## scripts ask for exists (and the loops loop), all audio stays inside its 8 MB budget, the band plays
## the title tune and then one tempo tier per wave (faster each wave, higher past the last tier) and
## falls silent when a wave is cleared, the guns, footsteps (boards indoors, snow outdoors), groans and
## purchases make their sounds, and the storm is muffled indoors.

const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)
const AUDIO_BUDGET: int = 8 * 1024 * 1024
const CALL := "Sound\\.(?:play|play_at|attach)\\(&\"([a-z0-9_]+)\""

var main: Node
var player: Player
var waves: WaveManager
var band: BandDirector
var failures: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


## Some player in the Sound pools is playing `id` right now.
func _sounding(id: StringName) -> bool:
	for pool: Array in [Sound._pool_2d, Sound._pool_3d, Sound._pool_ui]:
		for p: Node in pool:
			if p.call("is_playing") and p.get_meta(&"id", &"") == id:
				return true
	return false


func _quiet() -> void:
	for pool: Array in [Sound._pool_2d, Sound._pool_3d, Sound._pool_ui]:
		for p: Node in pool:
			p.call("stop")


func _run() -> void:
	await _frames(3)
	band = main.get_node("BandDirector")
	_check(band.playing_tune() == &"band_menu", "the title tune plays under the start screen (%s)" % band.playing_tune())
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	# The waves started by hand below must not bring Resi or a random event along.
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	Events.wave_started.disconnect((main.get_node("EventDirector") as EventDirector)._on_wave_started)
	await _frames(10)

	_library()
	_budget()
	await _band()
	await _weapons()
	await _footsteps()
	await _enemies()
	await _purchases()
	await _wind()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _library() -> void:
	var missing: Array[String] = []
	for id: StringName in Sound.MIX:
		if not Sound.has(id):
			missing.append(String(id))
	for file: String in ResourceLoader.list_directory("res://data/weapons/"):
		var weapon := load("res://data/weapons/" + file) as WeaponData
		if weapon == null:
			continue
		for field: String in ["fire_sound", "fire_loop_sound", "secondary_sound", "play_sound", "reload_sound", "reload_end_sound", "swing_sound", "hit_sound"]:
			var id: StringName = weapon.get(field)
			if id != &"" and not Sound.has(id):
				missing.append("%s.%s = %s" % [weapon.id, field, id])
	for file: String in ResourceLoader.list_directory("res://data/enemies/"):
		var enemy := load("res://data/enemies/" + file) as EnemyData
		if enemy == null:
			continue
		for id: StringName in enemy.groan_sounds + [enemy.death_sound]:
			if not Sound.has(id):
				missing.append("%s: %s" % [enemy.id, id])
	var calls := RegEx.create_from_string(CALL)
	var called: int = 0
	for path: String in _scripts("res://scripts/"):
		for found: RegExMatch in calls.search_all(FileAccess.get_file_as_string(path)):
			called += 1
			if not Sound.has(StringName(found.get_string(1))):
				missing.append("%s: %s" % [path.get_file(), found.get_string(1)])
	_check(missing.is_empty(), "every sound asked for exists (%d calls in scripts) %s" % [called, missing])
	var wrong: Array[String] = []
	for id: StringName in Sound._streams:
		for stream: AudioStream in Sound._streams[id]:
			var ogg := stream as AudioStreamOggVorbis
			if ogg and ogg.loop != (id in Sound.LOOPS):
				wrong.append(String(id))
	_check(wrong.is_empty() and Sound.has(&"wind_loop") and Sound.has(&"band_8"), "loops loop and one-shots do not %s" % [wrong])


func _scripts(directory: String) -> Array[String]:
	var out: Array[String] = []
	for name: String in ResourceLoader.list_directory(directory):
		if name.ends_with("/"):
			out.append_array(_scripts(directory + name))
		elif name.ends_with(".gd"):
			out.append(directory + name)
	return out


func _budget() -> void:
	var total: int = 0
	var files: int = 0
	for folder: String in ["sfx", "music", "ambience"]:
		var directory: String = "res://assets/audio/%s/" % folder
		for name: String in DirAccess.get_files_at(directory):
			if name.ends_with(".ogg"):
				total += FileAccess.get_file_as_bytes(directory + name).size()
				files += 1
	_check(total > 0 and total < AUDIO_BUDGET, "%d sound files, %.2f MB of the 8 MB audio budget" % [files, total / 1048576.0])


func _band() -> void:
	GameState.has_started = true
	await _seconds(Constants.BAND_FADE_TIME + 0.3)
	_check(band.playing_tune() == &"", "the title tune fades once the game is on")
	var lengths: Array[float] = []
	for tier: int in range(1, BandDirector.TIERS + 1):
		lengths.append(Sound.stream(StringName("band_%d" % tier)).get_length())
	var faster: bool = true
	for i: int in range(1, lengths.size()):
		faster = faster and lengths[i] < lengths[i - 1]
	_check(faster, "every tier plays the tune faster (%.1f s down to %.1f s a time round)" % [lengths[0], lengths[-1]])
	Events.wave_started.emit(1, false)
	await _frames(2)
	_check(band.playing_tune() == &"band_1" and _sounding(&"wave_start"), "wave 1: the hut bell rings and the band strikes up (%s)" % band.playing_tune())
	Events.wave_started.emit(5, false)
	await _frames(2)
	_check(band.playing_tune() == &"band_5", "wave 5 plays tier 5 (%s)" % band.playing_tune())
	Events.wave_started.emit(12, false)
	await _frames(2)
	var pitch: float = band._players[band._current].pitch_scale
	_check(band.playing_tune() == &"band_8" and is_equal_approx(pitch, 1.08), "wave 12: the fastest tier, pitched up to %.2f" % pitch)
	Events.wave_started.emit(15, true)
	await _frames(2)
	_check(_sounding(&"boss_wave"), "a boss wave tolls the deep bell")
	Events.wave_cleared.emit(15)
	await _frames(2)
	_check(_sounding(&"wave_cleared"), "a cleared wave ends on the band's ta-da")
	await _seconds(Constants.BAND_FADE_TIME + 0.3)
	_check(band.playing_tune() == &"", "and the break is quiet but for the storm")
	_quiet()


func _weapons() -> void:
	var holder: WeaponHolder = player.weapons
	holder.give_weapon(load("res://data/weapons/pistole.tres"))
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	_quiet()
	holder._fire()
	_check(_sounding(&"shot_pistole"), "the pistol goes bang")
	await _seconds(0.3)
	holder.start_reload()
	_check(_sounding(&"mag_out"), "the magazine comes out on a reload")
	await _seconds(holder.weapon.reload_time + 0.2)
	_check(_sounding(&"mag_in"), "and clicks home at the end")
	_quiet()
	holder._start_melee()
	_check(_sounding(&"swing"), "the shovel swings with a whoosh")
	await _seconds(1.0)
	var flinte: WeaponData = load("res://data/weapons/jagdflinte.tres")
	holder.give_weapon(flinte)
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	_quiet()
	holder.fire_all()
	_check(_sounding(&"shot_jagdflinte_both"), "both barrels at once are louder than one")
	_quiet()


func _footsteps() -> void:
	player.global_position = (get_tree().get_first_node_in_group("player_spawn") as Node3D).global_position
	await _frames(20)
	_quiet()
	player.velocity = Vector3(3.0, 0.0, 0.0)
	player._step_left = 0.0
	player._footsteps(0.016, true, 0.0)
	_check(_sounding(&"step_wood"), "footsteps on the boards in the Stube")
	player.global_position = FIELD
	await _frames(20)
	_quiet()
	player.velocity = Vector3(3.0, 0.0, 0.0)
	player._step_left = 0.0
	player._footsteps(0.016, true, 0.0)
	_check(_sounding(&"step_snow"), "and in the snow outside")
	player.velocity = Vector3.ZERO


func _enemies() -> void:
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(load("res://data/enemies/wanderer.tres"), 1, Transform3D(Basis.IDENTITY, FIELD + Vector3(6.0, 0.0, 0.0)))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	_quiet()
	enemy._groan_left = 0.0
	await _frames(2)
	_check(_sounding(&"groan_wanderer"), "a Wanderer groans as it comes")
	_quiet()
	enemy.receive_hit(100000, false, false, player)
	_check(_sounding(&"enemy_death"), "and cries out as it falls")


func _purchases() -> void:
	_quiet()
	player.points.total = 0
	player.points.spend(500)
	_check(_sounding(&"deny"), "too few points: the buyer hears it")
	player.points.add(500)
	player.points.spend(500)
	_check(_sounding(&"buy"), "a purchase rings the till")
	_quiet()


func _wind() -> void:
	var filter := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Wind"), 0) as AudioEffectLowPassFilter
	player.global_position = FIELD
	await _seconds(Constants.ATMOSPHERE_BLEND_TIME + 0.8)
	var outside: float = filter.cutoff_hz
	player.global_position = (get_tree().get_first_node_in_group("player_spawn") as Node3D).global_position
	await _seconds(Constants.ATMOSPHERE_BLEND_TIME + 0.8)
	var inside: float = filter.cutoff_hz
	_check(outside > 10000.0 and inside < 1000.0, "the storm is open outside (%.0f Hz) and muffled in the Stube (%.0f Hz)" % [outside, inside])
