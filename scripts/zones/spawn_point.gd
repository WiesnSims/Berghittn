class_name SpawnPoint
extends Marker3D
## Where enemies of one zone come from, outside its windows. Only used while the zone is active
## (see ZoneMap.is_spawn_active).

@export var zone: StringName


func _ready() -> void:
	add_to_group("spawn_points")
	if zone == &"":
		push_warning("Spawn point %s has no zone; it will never be used." % get_path())
