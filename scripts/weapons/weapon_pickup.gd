class_name WeaponPickup
extends Node3D
## A weapon lying on the floor for a player to take with E (the Krampus-Rute where the Krampus fell).
## Shows the weapon's own model, turning slowly over a red glow; stays until someone takes it.

var weapon: WeaponData
var _model: Node3D
var _spin: float = 0.0


## Leaves `data` on the floor below `at`, in `parent`, and announces it.
static func spawn(data: WeaponData, at: Vector3, parent: Node) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.weapon = data
	parent.add_child(pickup)
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 4.0, Constants.LAYER_WORLD)
	var hit: Dictionary = pickup.get_world_3d().direct_space_state.intersect_ray(down)
	pickup.global_position = hit.position if not hit.is_empty() else at
	if data.id == &"krampusrute":
		Events.event_announced.emit(TranslationServer.translate("EVENT_RUTE_DROPPED"))
	return pickup


func _ready() -> void:
	add_to_group("interactables")
	# Only the weapon's meshes, as the Hüttentruhe shows them.
	var viewmodel: Node = weapon.viewmodel.instantiate()
	_model = viewmodel.get_node("Model")
	viewmodel.remove_child(_model)
	viewmodel.free()
	_model.transform = Transform3D.IDENTITY
	_model.visible = true
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 0.7, 0.0)
	# Larger than in hand, to be seen from across the room.
	holder.scale = Vector3.ONE * 1.8
	add_child(holder)
	holder.add_child(_model)
	# Lying across, centred on its length (it runs along -Z from the grip).
	var bounds := AABB()
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		bounds = bounds.merge(mesh.transform * mesh.get_aabb())
	_model.rotation.y = PI * 0.5
	_model.position = -(_model.basis * bounds.get_center())
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.3, 0.2)
	glow.light_energy = 1.5
	glow.omni_range = 2.5
	glow.position = Vector3(0.0, 0.5, 0.0)
	add_child(glow)


func _process(delta: float) -> void:
	_spin += delta
	var holder: Node3D = _model.get_parent()
	holder.rotation.y = _spin * 1.2
	holder.position.y = 0.7 + sin(_spin * 2.0) * 0.08


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return global_position


func get_interact_prompt(player: Node3D) -> String:
	var taker := player as Player
	if taker.weapons.has_weapon(weapon):
		return ""
	return tr("UI_CHEST_TAKE") % tr(weapon.display_name)


func interact(player: Node3D) -> void:
	var taker := player as Player
	if taker.weapons.has_weapon(weapon):
		return
	taker.weapons.give_weapon(weapon)
	queue_free()
