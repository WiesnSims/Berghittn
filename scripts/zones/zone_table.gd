class_name ZoneTable
extends Resource
## All zones of "Die Hütte" with their door costs (section 4).

@export var zones: Array[ZoneData] = []


func find(id: StringName) -> ZoneData:
	for zone: ZoneData in zones:
		if zone.id == id:
			return zone
	return null
