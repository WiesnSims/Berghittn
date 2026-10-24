class_name Kraxn
extends Node3D
## Die Kraxn (#95, user request 2026-10-24): the wooden carrying frame Alm farmers haul hay and wood
## on, hanging on a hook in the Matratzenlager. Strapped on (KRAXN_COST, once a match, every player
## their own) it carries a third gun. Nothing takes it away again: not going down, not bleeding out.
## In co-op the others see it on the hiker's back with the guns not in hand strapped to it.
## Local -Z faces into the room; the origin sits on the floor against the wall.

const WOOD: Material = preload("res://assets/materials/wood_dark.tres")
const STRAP: Material = preload("res://assets/materials/wool_red.tres")

## Bought with one press, not held.
var interact_repeat: float = 0.0


func _ready() -> void:
	add_to_group("interactables")
	var frame: Node3D = model()
	frame.position = Vector3(0.0, Constants.KRAXN_HOOK_HEIGHT, -0.12)
	add_child(frame)
	# The hook it hangs from.
	var hook := MeshInstance3D.new()
	var peg := CylinderMesh.new()
	peg.top_radius = 0.025
	peg.bottom_radius = 0.025
	peg.height = 0.2
	hook.mesh = peg
	hook.material_override = WOOD
	hook.rotation.x = PI * 0.5
	hook.position = Vector3(0.0, Constants.KRAXN_HOOK_HEIGHT + 1.05, -0.08)
	add_child(hook)


## The frame on its own, its foot board at the origin, the straps on the +Z side (towards the back
## that carries it). For the hook and for the hikers.
static func model() -> Node3D:
	var root := Node3D.new()
	# Two uprights, a little wider at the foot.
	for side: float in [-1.0, 1.0]:
		var post := _part(Vector3(0.05, 1.1, 0.05), Vector3(side * 0.2, 0.55, 0.0), WOOD)
		post.rotation.z = side * 0.04
		root.add_child(post)
		# A shoulder strap, from the top down to the middle.
		root.add_child(_part(Vector3(0.05, 0.6, 0.015), Vector3(side * 0.13, 0.72, 0.06), STRAP))
	# Cross bars, and the foot board things stand on.
	for y: float in [0.3, 0.62, 0.95]:
		root.add_child(_part(Vector3(0.44, 0.04, 0.04), Vector3(0.0, y, 0.0), WOOD))
	root.add_child(_part(Vector3(0.48, 0.04, 0.3), Vector3(0.0, 0.02, -0.13), WOOD))
	return root


static func _part(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.material_override = material
	part.position = at
	return part


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return to_global(Vector3(0.0, 1.0, -0.8))


func get_interact_prompt(player: Node3D) -> String:
	var buyer := player as Player
	if buyer.weapons.has_kraxn():
		return ""
	var key: String = "UI_KRAXN" if buyer.points.can_afford(Constants.KRAXN_COST) else "UI_KRAXN_NEED"
	return tr(key) % Constants.KRAXN_COST


func interact(player: Node3D) -> void:
	var buyer := player as Player
	if buyer.weapons.has_kraxn() or not buyer.points.spend(Constants.KRAXN_COST):
		return
	buyer.weapons.add_kraxn()
	Sound.play(&"buy")
	Events.event_announced.emit(tr("EVENT_KRAXN"))
