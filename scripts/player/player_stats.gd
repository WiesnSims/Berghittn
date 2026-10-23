class_name PlayerStats
extends Node
## This player's run for the death screen: kills, headshot kills, kills per weapon and Schnaps drunk.
## Like PlayerPoints it only counts what its own player did, so in co-op every screen shows its own run.

var kills: int = 0
var headshots: int = 0
## Every Schnaps that went down, bought at the shrine or tapped from the Bierfassl; a Schnaps had again
## after going down counts again.
var schnaps: int = 0
# WeaponData id -> kills with it, and id -> the WeaponData (for its name).
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
	return _weapon_kills.get(data.id, 0) if data else 0


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
	_weapon_kills[data.id] = int(_weapon_kills.get(data.id, 0)) + 1
	_weapons[data.id] = data


func _on_drunk(_perk: PerkData) -> void:
	schnaps += 1
