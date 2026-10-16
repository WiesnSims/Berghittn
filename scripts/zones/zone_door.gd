class_name ZoneDoor
extends Node3D
## Locked door between two zones (section 4). Buying it opens the zone behind it at that zone's cost.
## A door also swings open by itself once both its zones are open, so a loop of zones never leaves
## a paid-for passage shut. Sits at the floor in the middle of the doorway; opens towards local +Z.

@export var zone_a: StringName
@export var zone_b: StringName

## Doors are bought with one press, not held.
var interact_repeat: float = 0.0
var _open: bool = false

# Pivots on the hinge edge, so rotating it swings the panel flat against the wall.
@onready var _hinge: Node3D = $Hinge
@onready var _panel: CSGShape3D = $Hinge/Panel


func _ready() -> void:
	add_to_group("zone_doors")
	add_to_group("interactables")
	Events.zone_unlocked.connect(_on_zone_unlocked.unbind(2))


func is_open() -> bool:
	return _open


## The zone across this door from `id`, or "" if this door does not touch `id`.
func other_side(id: StringName) -> StringName:
	if id == zone_a:
		return zone_b
	if id == zone_b:
		return zone_a
	return &""


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return global_position


func get_interact_prompt(player: Node3D) -> String:
	var zone: ZoneData = _zone_behind()
	if zone == null:
		return ""
	if (player as Player).points.can_afford(zone.cost):
		return tr("UI_DOOR_OPEN") % [zone.display_name, zone.cost]
	return tr("UI_DOOR_NEED") % [zone.display_name, zone.cost]


func interact(player: Node3D) -> void:
	var zone: ZoneData = _zone_behind()
	if zone and (player as Player).points.spend(zone.cost):
		_zones().unlock(zone.id, player)


func _zones() -> ZoneMap:
	return get_tree().get_first_node_in_group("zone_map") as ZoneMap


## The locked zone this door leads into; null when open or when neither side is reachable yet.
func _zone_behind() -> ZoneData:
	var zones: ZoneMap = _zones()
	if _open or zones == null:
		return null
	var a_open: bool = zones.is_unlocked(zone_a)
	if a_open == zones.is_unlocked(zone_b):
		return null
	return zones.get_zone(zone_b if a_open else zone_a)


func _on_zone_unlocked() -> void:
	var zones: ZoneMap = _zones()
	if not _open and zones.is_unlocked(zone_a) and zones.is_unlocked(zone_b):
		_swing_open()


func _swing_open() -> void:
	_open = true
	# Out of the way at once (and out of the navmesh rebake that follows); the swing is just for show.
	_panel.use_collision = false
	var tween: Tween = create_tween()
	tween.tween_property(_hinge, "rotation:y", -PI, Constants.DOOR_OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
