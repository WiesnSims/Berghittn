extends Node
## Player-adjustable settings. Persistence and a settings menu follow in M6.

# Registered here instead of in project settings: Godot 4.7 loads project translations
# before the .tres loader exists ("No loader found"), so they would silently be missing.
const STRING_TABLES: Array[String] = ["res://data/strings_en.tres", "res://data/strings_de.tres"]

var mouse_sensitivity: float = Constants.DEFAULT_MOUSE_SENSITIVITY
## Share of the sensitivity left while aiming down the sights or through the scope.
var aim_sensitivity: float = Constants.DEFAULT_AIM_SENSITIVITY


func _ready() -> void:
	for path: String in STRING_TABLES:
		TranslationServer.add_translation(load(path) as Translation)
	# Godot would otherwise pick the browser/OS language; English is the agreed default.
	TranslationServer.set_locale(Constants.DEFAULT_LOCALE)
