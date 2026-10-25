extends Node
## Run: godot --headless --fixed-fps 60 res://tests/v12_extras.tscn
## The 1.2 extras (GAME_DESIGN section 12), headless on the real main scene: the Huatständer, the
## Bsundan on the end screen and in the Gipfelbuch entry, "Bsundane Woch!", the others greeting a
## Bsundan, the Zeitlupe, the Steckbriefe (met, kills, posters) and the Wandernadln. What it changes
## in Settings is put back at the end.

const GARDEN := Vector3(-12.0, -0.3, 16.5)
const SAVED: Array[String] = ["met", "kills", "hats", "headshots", "coop_best", "badges", "zeitlupe", "best_wave", "best_points"]

var main: Node
var player: Player
var waves: WaveManager
var gredn: Gredn
var rack: HatRack
var nadln: Wandernadln
var failures: Array[String] = []
var banners: Array[String] = []
var _saved: Dictionary = {}


func _ready() -> void:
	for key: String in SAVED:
		var value: Variant = Settings.get(key)
		_saved[key] = value.duplicate(true) if value is Dictionary or value is Array else value
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
		player.health._health = float(player.health.max_health)


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	gredn = main.get_node("Gredn")
	waves = main.get_node("WaveManager")
	nadln = main.get_node("Wandernadln")
	rack = get_tree().get_first_node_in_group("hat_rack") as HatRack
	waves.wave = 12
	waves.zones.unlock(&"terrasse", null)
	waves._break_left = 1.0e9
	main.get_node("EventDirector").random_events = false
	Settings.chatter = true
	Settings.badges = {}
	Settings.kills = {}
	Events.event_announced.connect(func(text: String) -> void: banners.append(text))
	_strings()
	await _rack()
	await _stats()
	await _event()
	await _greet()
	await _zeitlupe()
	await _steckbriefe()
	await _nadln()
	_panel()
	for key: String in SAVED:
		Settings.set(key, _saved[key])
	Settings.save()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _strings() -> void:
	var keys: Array[String] = ["EVENT_HAT_RACK", "EVENT_BSUNDAN_WEEK", "UI_DEATH_BSUNDAN", "UI_SET_ZEITLUPE",
		"UI_STECKBRIEFE_BUTTON", "UI_STECKBRIEFE", "UI_NADLN", "UI_GSUACHT", "UI_STECK_BSUNDAN", "UI_STECK_KILLS",
		"UI_STECK_UNKNOWN", "UI_NADL_COUNT", "UI_NADL_EARNED", "UI_NADL_ALL", "UI_NADL_GOAL_BSUNDAN_ALL", "UI_NADL_GOAL_HUAT_FULL"]
	for id: String in SteckbriefPanel.ENEMIES:
		keys.append("STECK_" + id.to_upper())
	for badge: StringName in Wandernadln.BADGES:
		keys.append("UI_NADL_" + String(badge).to_upper())
		keys.append("UI_NADL_GOAL_" + String(badge).to_upper())
	for tier: String in Wandernadln.TIERS.slice(1):
		keys.append(tier)
	var missing: Array[String] = []
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for key: String in keys:
			if TranslationServer.translate(key) == key:
				missing.append("%s:%s" % [locale, key])
	TranslationServer.set_locale(Settings.locale)
	_check(missing.is_empty(), "every new text in English and German %s" % [missing])
	var portraits: Array[String] = SteckbriefPanel.ENEMIES.filter(func(id: String) -> bool: return not ResourceLoader.exists(SteckbriefPanel.PORTRAITS % id))
	_check(portraits.is_empty(), "every enemy has a Steckbrief picture %s" % [portraits])


## A plain enemy of the wave at `at`.
func _plain(id: String, at: Vector3) -> Enemy:
	return waves._take(load("res://data/enemies/%s.tres" % id), Transform3D(Basis.IDENTITY, at))


func _send(id: String, at: Vector3) -> Enemy:
	return waves.send_variant(load("res://data/enemies/%s.tres" % id), Transform3D(Basis(Vector3.UP, PI * 0.5), at))[0]


func _clear() -> void:
	for child: Node in waves.get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive():
			enemy._despawn()
		if enemy:
			enemy.set_physics_process(true)
	await _frames(2)


func _rack() -> void:
	_check(rack != null and rack.hung().is_empty(), "the Huatständer hangs in the Stube, empty")
	player.global_position = GARDEN
	var wanderer: Enemy = _plain("wanderer", GARDEN + Vector3(6, 0, 0))
	var hats: int = Settings.hats
	wanderer.knock_hat(Vector3.RIGHT, player)
	_check(rack.hung() == [&"wanderer"], "a Wanderer's hat shot off goes up on its peg")
	_check(Settings.hats == hats + 1, "and counts for the Huatsammler")
	var other: Enemy = _plain("wanderer", GARDEN + Vector3(6, 0, 2))
	other.knock_hat(Vector3.RIGHT, player)
	_check(rack.hung().size() == 1, "the next Wanderer's hat does not hang twice")
	banners.clear()
	var kassier: Enemy = _send("kassier", GARDEN + Vector3(8, 0, -2))
	banners.clear()
	kassier.knock_hat(Vector3.RIGHT, player)
	_check(&"kassier" in rack.hung() and banners.has(tr("EVENT_HAT_RACK") % tr("ENEMY_KASSIER")),
		"a Bsundan's hat goes up with a banner %s" % [banners])
	_check(Wandernadln.tier(&"huat") < 3, "no Gold Huatsammler before the rack is full")
	rack.hang_all()
	_check(rack.is_full() and Wandernadln.tier(&"huat") == 3, "a full rack in one match: the Gold Huatsammler")
	await _clear()


func _stats() -> void:
	var before: int = player.stats.bsundan
	var kassier: Enemy = _send("kassier", GARDEN + Vector3(6, 0, 0))
	kassier.receive_hit(100000, false, false, player)
	var wanderer: Enemy = _plain("wanderer", GARDEN + Vector3(6, 0, 3))
	wanderer.receive_hit(100000, false, false, player)
	_check(player.stats.bsundan == before + 1, "the death screen counts the Bsundan killed, not the plain ones")
	var row: Dictionary = player.stats.row("Sepp", 100)
	_check(row["bsundan"] == player.stats.bsundan and PlayerStats.sanitize_row(row)["bsundan"] == row["bsundan"],
		"and the Hüttenwertung row carries it")
	_check(PlayerStats.sanitize_row({"bsundan": "viel"})["bsundan"] == 0, "a broken row from another browser is 0")
	var screen := main.get_node("UI/DeathScreen") as DeathScreen
	screen.present(12, 100, player.stats, false)
	_check((screen.get_node("%Bsundan") as Label).text == str(player.stats.bsundan), "the death screen shows it")
	screen.hide()
	get_tree().paused = false
	await _clear()


func _event() -> void:
	var director := main.get_node("EventDirector") as EventDirector
	director._wave = 12
	waves._phase = WaveManager.Phase.SPAWNING
	waves._to_spawn = 20
	_check(&"bsundan" in director.available_random_events(), "Bsundane Woch can come in wave 12 with 20 still to come")
	waves._to_spawn = 3
	_check(not &"bsundan" in director.available_random_events(), "not with 3 left")
	director._wave = 6
	waves._to_spawn = 20
	_check(not &"bsundan" in director.available_random_events(), "not before wave %d" % Constants.BSUNDAN_WEEK_FIRST_WAVE)
	director._wave = 12
	banners.clear()
	director.bsundane_woch()
	_check(waves.variant_chance == Constants.BSUNDAN_WEEK_CHANCE and banners.has(tr("EVENT_BSUNDAN_WEEK")),
		"it raises the variant chance to %d %% and says so" % roundi(Constants.BSUNDAN_WEEK_CHANCE * 100))
	_check(not &"bsundan" in director.available_random_events(), "and does not come again in the same wave")
	var rolled: int = 0
	for i: int in 2000:
		if waves._roll_variant():
			rolled += 1
	_check(rolled > 400 and rolled < 600, "about a quarter of the spawns are a Bsundan now (%d of 2000)" % rolled)
	waves._start_wave(13)
	_check(waves.variant_chance == Constants.VARIANT_CHANCE, "the next wave is back to %d %%" % roundi(Constants.VARIANT_CHANCE * 100))
	waves.wave = 12
	waves._phase = WaveManager.Phase.BREAK
	waves._break_left = 1.0e9
	waves._to_spawn = 0
	await _clear()


func _greet() -> void:
	var silent: Array = Gredn.LINES.filter(func(l: Array) -> bool: return l[1] == Gredn.Moment.GREET and not Sound.has(l[3]))
	_check(silent.is_empty(), "every greeting has its voice %s" % [silent])
	var greeted: Array[String] = []
	for id: String in Wandernadln.VARIANTS:
		if Gredn.LINES.any(func(l: Array) -> bool: return l[1] == Gredn.Moment.GREET and l[4] == StringName(id)):
			greeted.append(id)
	_check(greeted.size() == 6, "each Bsundan has greetings (%d)" % greeted.size())
	player.global_position = GARDEN
	var wanderer: Enemy = _plain("wanderer", GARDEN + Vector3(5, 0, 2))
	wanderer.set_physics_process(false)
	gredn.last_heard = -1
	var kassier: Enemy = _send("kassier", GARDEN + Vector3(7, 0, 0))
	await _frames(roundi((Constants.GREET_DELAY + 0.3) * 60.0))
	var line: Array = Gredn.LINES[gredn.last_heard] if gredn.last_heard >= 0 else []
	_check(not line.is_empty() and line[1] == Gredn.Moment.GREET and line[0] == &"wanderer" and line[4] == &"kassier",
		"a Wanderer near the Kassier greets him: %s" % [line])
	_check(Gredn.greet(kassier) >= 0 and Gredn.greet(wanderer) == -1, "only a Bsundan is greeted")
	await _clear()


func _zeitlupe() -> void:
	var zeitlupe := main.get_node("Zeitlupe") as Zeitlupe
	var master: int = AudioServer.get_bus_index(&"Master")
	var effects: int = AudioServer.get_bus_effect_count(master)
	Settings.zeitlupe = true
	Events.wave_cleared.emit(12)
	_check(is_equal_approx(Engine.time_scale, Constants.ZEITLUPE_SCALE) and AudioServer.get_bus_effect_count(master) == effects + 1,
		"the wave's last kill: slow motion (%.2f) and the sound muffled" % Engine.time_scale)
	await _frames(roundi(Constants.ZEITLUPE_TIME * 60.0) - 6)
	_check(zeitlupe.is_slow(), "still slow after nearly %.1f s" % Constants.ZEITLUPE_TIME)
	await _frames(roundi(Constants.ZEITLUPE_EASE * 60.0) + 15)
	_check(Engine.time_scale == 1.0 and AudioServer.get_bus_effect_count(master) == effects, "then full speed and sound again")
	Settings.zeitlupe = false
	Events.wave_cleared.emit(12)
	_check(Engine.time_scale == 1.0, "switched off in Settings: no slow motion")
	Settings.zeitlupe = true
	zeitlupe.play()
	zeitlupe._exit_tree()
	_check(Engine.time_scale == 1.0 and AudioServer.get_bus_effect_count(master) == effects, "a reload never leaves the game slow")


func _steckbriefe() -> void:
	Settings.met.erase("schoenperchte")
	var perchte: Enemy = _send("schoenperchte", GARDEN + Vector3(9, 0, 0))
	_check("schoenperchte" in Settings.met, "an enemy that turns up counts as met")
	var kills: int = Wandernadln.kills_of("schoenperchte")
	perchte.receive_hit(100000, false, false, player)
	_check(Wandernadln.kills_of("schoenperchte") == kills + 1, "our kill counts for its Steckbrief")
	var wanderer: Enemy = _plain("wanderer", GARDEN + Vector3(6, 0, 0))
	var someone := Node3D.new()
	add_child(someone)
	var wanderers: int = Wandernadln.kills_of("wanderer")
	wanderer.receive_hit(100000, false, false, someone)
	_check(Wandernadln.kills_of("wanderer") == wanderers, "someone else's kill does not")
	someone.queue_free()
	await _clear()


func _nadln() -> void:
	# A clean slate: nothing earned from earlier runs on this machine.
	Settings.badges = {}
	Settings.kills = {"krampus": 9}
	Settings.hats = 0
	Settings.headshots = 0
	Settings.coop_best = 0
	banners.clear()
	nadln.check()
	_check(Wandernadln.tier(&"krampus") == 1, "9 Krampusse: the Bronze Krampusbezwinger")
	var krampus: Enemy = _plain("krampus", GARDEN + Vector3(8, 0, 0))
	krampus.receive_hit(10000000, false, false, player)
	_check(Wandernadln.tier(&"krampus") == 2, "the 10th: Silber")
	_check(banners.has(tr("UI_NADL_EARNED") % [tr("UI_NADL_SILBER"), tr("UI_NADL_KRAMPUS")]),
		"with a banner %s" % [banners])
	Settings.best_wave = 3
	Wandernadln.match_wave = 20
	nadln.check()
	_check(Wandernadln.tier(&"gipfel") == 2, "reaching wave 20: Bronze and Silber Gipfelstürmer at once")
	Settings.kills = {"kassier": 3, "influencer": 1}
	nadln.check()
	_check(Wandernadln.tier(&"bsundan") == 1, "a Bsundan killed: Bronze Bsundan-Jaga, not yet Silber (2 of 6 kinds)")
	for id: String in Wandernadln.VARIANTS:
		Settings.kills[id] = 1
	nadln.check()
	_check(Wandernadln.tier(&"bsundan") == 2, "every kind killed once: Silber")
	_check(Wandernadln.tier(&"seilschaft") == 0, "no Seilschaft without co-op")
	nadln.earn(&"krampus", 1)
	_check(Wandernadln.tier(&"krampus") == 2, "a lower tier never replaces a higher one")
	_check(Wandernadln.earned() == 2 + 2 + 2, "the count: %d" % Wandernadln.earned())
	await _clear()


func _panel() -> void:
	Settings.met.erase("trailrunner")
	if not "kassier" in Settings.met:
		Settings.met.append("kassier")
	Settings.kills["kassier"] = 7
	var panel := SteckbriefPanel.new()
	add_child(panel)
	panel.open()
	var posters: Array = panel._posters.get_children()
	_check(posters.size() == SteckbriefPanel.ENEMIES.size(), "a poster for each of the %d enemies" % posters.size())
	var kassier: Control = panel._posters.get_node("Poster_kassier")
	var runner: Control = panel._posters.get_node("Poster_trailrunner")
	_check((kassier.find_child("Name", true, false) as Label).text == tr("ENEMY_KASSIER")
		and (kassier.find_child("Kills", true, false) as Label).text == tr("UI_STECK_KILLS") % 7, "a met one: name and our kills")
	_check((runner.find_child("Name", true, false) as Label).text == "???", "one never met: ???")
	_check(SteckbriefPanel.quote("kassier").contains("Beitrag"), "a poster quotes one of its lines: %s" % SteckbriefPanel.quote("kassier"))
	panel.show_page(1)
	_check(panel._badges.get_child_count() == 1 + Wandernadln.BADGES.size(), "the Wandernadln page: the count and six badges")
	_check(SteckbriefPanel.goal_text(&"huat", 3) == tr("UI_NADL_GOAL_HUAT_FULL")
		and SteckbriefPanel.goal_text(&"gipfel", 2, true).ends_with("(%d/20)" % mini(Wandernadln.value(&"gipfel", 2), 20)),
		"each tier says what it takes and how far we are")
	panel.queue_free()
