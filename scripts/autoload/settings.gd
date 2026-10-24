extends Node
## Player-adjustable settings, saved to user:// (IndexedDB in the browser) so they survive reloads.

signal changed

# Registered here instead of in project settings: Godot 4.7 loads project translations
# before the .tres loader exists ("No loader found"), so they would silently be missing.
const STRING_TABLES: Array[String] = ["res://data/strings_en.tres", "res://data/strings_de.tres"]
const SAVE_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
## Locales the menu offers, in its order.
const LOCALES: Array[String] = ["en", "de"]
## Audio buses the menu has a slider for (default_bus_layout.tres).
const BUSES: Array[StringName] = [&"Master", &"Music", &"Effects", &"Ambience"]

var mouse_sensitivity: float = Constants.DEFAULT_MOUSE_SENSITIVITY
## Share of the sensitivity left while aiming down the sights or through the scope.
var aim_sensitivity: float = Constants.DEFAULT_AIM_SENSITIVITY
var invert_y: bool = false
## Damage numbers over hit enemies (M9 part 2): off by default.
var damage_numbers: bool = false
## Enemies say their lines (M9 part 3, Gredn): on by default.
var chatter: bool = true
## The newest version whose patch notes this player has opened; the title screen marks newer ones.
var seen_version: String = ""
var locale: String = Constants.DEFAULT_LOCALE
## Linear 0..1 per bus name.
var volumes: Dictionary = {}
## Share of the window resolution the 3D view renders at; lower helps weak laptops.
var render_scale: float = 1.0
## Constants.Antialiasing. MSAA is the window's; FXAA is the post pass's switch (main.gd sets it).
var antialiasing: int = Constants.DEFAULT_ANTIALIASING
## Co-op name and hiker (HikerStyle profile), chosen in the lobby; empty until the player changes
## something there, and until then each player wears their peer's default (profile_for).
var profile: Dictionary = {}
## Earned hats (HatUnlocks): their unlock ids, and how many Perchten have fallen in our matches.
var unlocks: Array[String] = []
var perchten: int = 0
## Personal best (death screen): the furthest wave, and the points of that run. Solo and co-op alike,
## in this browser only.
var best_wave: int = 0
var best_points: int = 0
## Das Gipfelbuch: runs are sent to the global leaderboard (on until switched off), and the ids of
## our entries there (Board.remember).
var board: bool = true
var board_ids: Array[int] = []
## Key bindings (Keys): each rebindable action's first key or button; empty means the defaults.
var bindings: Dictionary = {}
## The view (1.1.2): field of view in degrees, aiming by toggle (a click on, a click off) instead of
## holding right click, and the crosshair's colour (Constants.CROSSHAIR_COLORS) and size.
var fov: float = Constants.DEFAULT_FOV
var toggle_aim: bool = false
var crosshair_color: int = 0
var crosshair_size: float = 1.0
## The last kill of a wave in slow motion (Zeitlupe, 1.2): on by default.
var zeitlupe: bool = true
## The Steckbriefe and the Wandernadln (1.2), this browser's player only: the enemy ids met in our
## matches, our kills per enemy id, hats shot off and headshot kills in all, the furthest co-op wave,
## and each badge's tier (Wandernadln.BADGES id -> 1 Bronze, 2 Silber, 3 Gold).
var met: Array[String] = []
var kills: Dictionary = {}
var hats: int = 0
var headshots: int = 0
var coop_best: int = 0
var badges: Dictionary = {}


func _ready() -> void:
	for path: String in STRING_TABLES:
		TranslationServer.add_translation(load(path) as Translation)
	for bus: StringName in BUSES:
		volumes[bus] = Constants.DEFAULT_VOLUME
	_load()
	Keys.apply(bindings)
	apply(false)


func volume(bus: StringName) -> float:
	return volumes.get(bus, Constants.DEFAULT_VOLUME)


func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)


## Pushes every value to the engine and tells listeners (post effects, menus) to refresh. The menu
## applies live while a slider moves and saves once when it closes.
func apply(and_save: bool = true) -> void:
	# Godot would otherwise pick the browser/OS language; English is the agreed default.
	TranslationServer.set_locale(locale)
	for bus: StringName in BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var linear: float = volume(bus)
		AudioServer.set_bus_mute(index, linear <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	get_tree().root.scaling_3d_scale = render_scale
	var msaa: Dictionary = {Constants.Antialiasing.MSAA_2X: Viewport.MSAA_2X, Constants.Antialiasing.MSAA_4X: Viewport.MSAA_4X}
	get_tree().root.msaa_3d = msaa.get(antialiasing, Viewport.MSAA_DISABLED)
	if and_save:
		save()
	changed.emit()


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = file.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	aim_sensitivity = file.get_value(SECTION, "aim_sensitivity", aim_sensitivity)
	invert_y = file.get_value(SECTION, "invert_y", invert_y)
	damage_numbers = file.get_value(SECTION, "damage_numbers", damage_numbers)
	chatter = file.get_value(SECTION, "chatter", chatter)
	board = file.get_value(SECTION, "board", board)
	fov = clampf(file.get_value(SECTION, "fov", fov), Constants.FOV_MIN, Constants.FOV_MAX)
	toggle_aim = file.get_value(SECTION, "toggle_aim", toggle_aim)
	crosshair_color = clampi(file.get_value(SECTION, "crosshair_color", crosshair_color), 0, Constants.CROSSHAIR_COLORS.size() - 1)
	crosshair_size = clampf(file.get_value(SECTION, "crosshair_size", crosshair_size), Constants.CROSSHAIR_SIZE_MIN, Constants.CROSSHAIR_SIZE_MAX)
	var keys: Variant = file.get_value(SECTION, "bindings", {})
	if keys is Dictionary:
		bindings = keys
	var ids: Variant = file.get_value(SECTION, "board_ids", [])
	if ids is Array:
		for id: Variant in ids:
			if id is int:
				board_ids.append(id)
	seen_version = str(file.get_value(SECTION, "seen_version", seen_version))
	var saved_locale: String = file.get_value(SECTION, "locale", locale)
	if saved_locale in LOCALES:
		locale = saved_locale
	render_scale = clampf(file.get_value(SECTION, "render_scale", render_scale), Constants.RENDER_SCALE_MIN, 1.0)
	antialiasing = clampi(file.get_value(SECTION, "antialiasing", antialiasing), 0, Constants.ANTIALIASING_KEYS.size() - 1)
	for bus: StringName in BUSES:
		set_volume(bus, file.get_value(SECTION, "volume_" + bus, volume(bus)))
	var saved: Variant = file.get_value(SECTION, "profile", {})
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		profile = HikerStyle.sanitize(saved)
	var earned: Variant = file.get_value(SECTION, "unlocks", [])
	if earned is Array:
		for id: Variant in earned:
			if id is String and not (id as String) in unlocks:
				unlocks.append(id)
	perchten = maxi(int(file.get_value(SECTION, "perchten", 0)), 0)
	best_wave = maxi(int(file.get_value(SECTION, "best_wave", 0)), 0)
	best_points = maxi(int(file.get_value(SECTION, "best_points", 0)), 0)
	zeitlupe = file.get_value(SECTION, "zeitlupe", zeitlupe)
	var seen: Variant = file.get_value(SECTION, "met", [])
	if seen is Array:
		for id: Variant in seen:
			if id is String and not (id as String) in met:
				met.append(id)
	kills = _counts(file.get_value(SECTION, "kills", {}))
	badges = _counts(file.get_value(SECTION, "badges", {}))
	hats = maxi(int(file.get_value(SECTION, "hats", 0)), 0)
	headshots = maxi(int(file.get_value(SECTION, "headshots", 0)), 0)
	coop_best = maxi(int(file.get_value(SECTION, "coop_best", 0)), 0)


# A saved Dictionary of String -> whole number, without anything else that may have got in.
static func _counts(saved: Variant) -> Dictionary:
	var counts: Dictionary = {}
	if saved is Dictionary:
		for key: Variant in saved:
			if (key is String or key is StringName) and saved[key] is int:
				counts[String(key)] = maxi(saved[key], 0)
	return counts


## Keeps the run if it beats the personal best: a further wave, or the same wave with more points.
## True when it did (and is saved).
func record_run(wave: int, points: int) -> bool:
	if wave < best_wave or (wave == best_wave and points <= best_points):
		return false
	best_wave = wave
	best_points = points
	save()
	return true


## Our hiker as peer `peer` wears it: the one dressed in the lobby, or that peer's default, so
## four players who never dressed theirs still look different (NETWORKING.md section 6). A hat not
## earned yet stays in the lobby (edit_profile) and is not worn.
func profile_for(peer: int) -> Dictionary:
	var worn: Dictionary = edit_profile(peer)
	if not HatUnlocks.has_hat(worn["hat"]):
		worn["hat"] = 0
	return worn


## Our hiker as the lobby shows it to us, a hat we have not earned yet included.
func edit_profile(peer: int) -> Dictionary:
	return HikerStyle.sanitize(profile) if not profile.is_empty() else HikerStyle.default_profile(peer)


func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	file.set_value(SECTION, "aim_sensitivity", aim_sensitivity)
	file.set_value(SECTION, "invert_y", invert_y)
	file.set_value(SECTION, "damage_numbers", damage_numbers)
	file.set_value(SECTION, "chatter", chatter)
	file.set_value(SECTION, "board", board)
	file.set_value(SECTION, "board_ids", board_ids)
	file.set_value(SECTION, "bindings", bindings)
	file.set_value(SECTION, "fov", fov)
	file.set_value(SECTION, "toggle_aim", toggle_aim)
	file.set_value(SECTION, "crosshair_color", crosshair_color)
	file.set_value(SECTION, "crosshair_size", crosshair_size)
	file.set_value(SECTION, "seen_version", seen_version)
	file.set_value(SECTION, "locale", locale)
	file.set_value(SECTION, "render_scale", render_scale)
	file.set_value(SECTION, "antialiasing", antialiasing)
	for bus: StringName in BUSES:
		file.set_value(SECTION, "volume_" + bus, volume(bus))
	file.set_value(SECTION, "profile", profile)
	file.set_value(SECTION, "unlocks", unlocks)
	file.set_value(SECTION, "perchten", perchten)
	file.set_value(SECTION, "best_wave", best_wave)
	file.set_value(SECTION, "best_points", best_points)
	file.set_value(SECTION, "zeitlupe", zeitlupe)
	file.set_value(SECTION, "met", met)
	file.set_value(SECTION, "kills", kills)
	file.set_value(SECTION, "badges", badges)
	file.set_value(SECTION, "hats", hats)
	file.set_value(SECTION, "headshots", headshots)
	file.set_value(SECTION, "coop_best", coop_best)
	file.save(SAVE_PATH)
