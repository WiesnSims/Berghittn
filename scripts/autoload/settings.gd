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
var locale: String = Constants.DEFAULT_LOCALE
## Linear 0..1 per bus name.
var volumes: Dictionary = {}
## Share of the window resolution the 3D view renders at; lower helps weak laptops.
var render_scale: float = 1.0
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


func _ready() -> void:
	for path: String in STRING_TABLES:
		TranslationServer.add_translation(load(path) as Translation)
	for bus: StringName in BUSES:
		volumes[bus] = Constants.DEFAULT_VOLUME
	_load()
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
	var saved_locale: String = file.get_value(SECTION, "locale", locale)
	if saved_locale in LOCALES:
		locale = saved_locale
	render_scale = clampf(file.get_value(SECTION, "render_scale", render_scale), Constants.RENDER_SCALE_MIN, 1.0)
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
	file.set_value(SECTION, "locale", locale)
	file.set_value(SECTION, "render_scale", render_scale)
	for bus: StringName in BUSES:
		file.set_value(SECTION, "volume_" + bus, volume(bus))
	file.set_value(SECTION, "profile", profile)
	file.set_value(SECTION, "unlocks", unlocks)
	file.set_value(SECTION, "perchten", perchten)
	file.set_value(SECTION, "best_wave", best_wave)
	file.set_value(SECTION, "best_points", best_points)
	file.save(SAVE_PATH)
