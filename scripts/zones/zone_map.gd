class_name ZoneMap
extends Node
## Which zones are open. Adjacency comes from the doors (a door joins two zones), so moving a door
## in a scene is the only edit needed to change the map's layout.

@export var table: ZoneTable

var _unlocked: Dictionary = {}


func _ready() -> void:
	add_to_group("zone_map")
	for zone: ZoneData in table.zones:
		if zone.starts_unlocked:
			_unlocked[zone.id] = true


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


func get_zone(id: StringName) -> ZoneData:
	return table.find(id)


func unlock(id: StringName, source: Node3D) -> void:
	if is_unlocked(id):
		return
	_unlocked[id] = true
	Events.zone_unlocked.emit(id, source)


## Section 4: a spawn point is active if its zone is unlocked or next to an unlocked zone.
func is_spawn_active(id: StringName) -> bool:
	if is_unlocked(id):
		return true
	for node: Node in get_tree().get_nodes_in_group("zone_doors"):
		var door := node as ZoneDoor
		var other: StringName = door.other_side(id)
		if other != &"" and is_unlocked(other):
			return true
	return false
