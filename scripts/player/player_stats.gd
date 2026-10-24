class_name PlayerStats
extends Node
## This player's run for the death screen: kills, headshot kills, kills per weapon and Schnaps drunk.
## Like PlayerPoints it only counts what its own player did, so in co-op every screen shows its own run.

## Caps for a Hüttenwertung row from another browser (sanitize_row).
const ROW_MAX: int = 9999999
const ROW_TEXT_MAX: int = 48

var kills: int = 0
var headshots: int = 0
## Every Schnaps that went down, bought at the shrine or tapped from the Bierfassl; a Schnaps had again
## after going down counts again.
var schnaps: int = 0
# Base weapon id -> kills with it (a dengelt one counts for its base), and id -> the highest version
# of it that made a kill (its name is the one shown).
var _weapon_kills: Dictionary = {}
var _weapons: Dictionary = {}
@onready var _player: Node3D = get_parent()


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	# The Player's own @onready vars are not set yet while its children get ready.
	(get_node("../Perks") as PlayerPerks).drunk.connect(_on_drunk)


## The weapon with the most kills (the first to get there on a tie), or null without a kill.
func favourite() -> WeaponData:
	var best: StringName = &""
	for id: StringName in _weapon_kills:
		if best == &"" or int(_weapon_kills[id]) > int(_weapon_kills[best]):
			best = id
	return _weapons.get(best)


func kills_with(data: WeaponData) -> int:
	return _weapon_kills.get(data.family_id(), 0) if data else 0


## This run as one row of the co-op Hüttenwertung (Net.share_run); `fav` is a translation key.
## For the group's Gipfelbuch entry: `public` (our name may be in it) and `clean` (no debug points).
func row(player_name: String, points: int) -> Dictionary:
	var best: WeaponData = favourite()
	return {
		"name": player_name, "points": points, "kills": kills, "headshots": headshots,
		"fav": String(best.display_name) if best else "", "fav_kills": kills_with(best), "schnaps": schnaps,
		"public": Settings.board, "clean": Board.clean,
	}


## A row from another browser, cut down to what it may hold.
static func sanitize_row(data: Dictionary) -> Dictionary:
	var number := func(key: String) -> int: return clampi(int(data.get(key, 0)) if data.get(key) is int else 0, 0, ROW_MAX)
	return {
		"name": str(data.get("name", "")).left(HikerStyle.NAME_MAX_LENGTH), "points": number.call("points"),
		"kills": number.call("kills"), "headshots": number.call("headshots"),
		"fav": str(data.get("fav", "")).left(ROW_TEXT_MAX), "fav_kills": number.call("fav_kills"),
		"schnaps": number.call("schnaps"),
		"public": data.get("public", true) is bool and data.get("public", true),
		"clean": data.get("clean", true) is bool and data.get("clean", true),
	}


func _on_enemy_killed(_enemy: Node3D, is_headshot: bool, is_melee: bool, source: Node3D) -> void:
	if source != _player:
		return
	kills += 1
	if is_headshot:
		headshots += 1
	# The kill goes to what was in hand: a burn, a mine or a thrown thing has no weapon of its own here.
	var weapons: WeaponHolder = (_player as Player).weapons
	var data: WeaponData = weapons.melee_weapon if is_melee else weapons.weapon
	if data == null:
		return
	var key: StringName = data.family_id()
	_weapon_kills[key] = int(_weapon_kills.get(key, 0)) + 1
	var known: WeaponData = _weapons.get(key)
	if known == null or data.level > known.level:
		_weapons[key] = data


func _on_drunk(_perk: PerkData) -> void:
	schnaps += 1
