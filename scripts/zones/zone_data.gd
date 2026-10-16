class_name ZoneData
extends Resource
## One zone of the map (section 4). Tune data/zone_table.tres, not the code.

@export var id: StringName
## Shown as is in every language: zone names are part of the setting (section 11).
@export var display_name: String
## Points to open a door into this zone.
@export var cost: int = 0
@export var starts_unlocked: bool = false
