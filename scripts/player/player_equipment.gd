class_name PlayerEquipment
extends Node
## The equipment slot (section 6a): one kind of item, stacked up to its max_carry, thrown with the
## throw action (G or the middle mouse button) the way the player looks, flat along the floor.

signal changed(item: EquipmentData, count: int)
## One left the hand (co-op passes it on: the others get a harmless copy of `thrown`).
signal threw(item: EquipmentData, thrown: Node3D)

var item: EquipmentData
var count: int = 0
var _cooldown: float = 0.0
@onready var _player: Player = get_parent() as Player


func give(data: EquipmentData, amount: int) -> void:
	# Another kind takes the place of what is in the slot.
	if item != data:
		item = data
		count = 0
	count = mini(count + amount, data.max_carry)
	changed.emit(item, count)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if Input.is_action_just_pressed("throw") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		throw()


## Throws one (also used by tests). False if there is nothing to throw yet.
func throw() -> bool:
	if item == null or count <= 0 or _cooldown > 0.0 or _player.health.is_dead():
		return false
	_cooldown = item.cooldown
	count -= 1
	var look: Vector3 = -_player.weapons.global_basis.z
	var forward := Vector3(look.x, 0.0, look.z).normalized()
	if forward.length_squared() < 0.01:
		forward = -_player.global_basis.z
	var thrown := item.projectile.instantiate() as Node3D
	_player.get_parent().add_child(thrown)
	thrown.launch(_player.global_position + forward * 0.7 + Vector3.UP * 0.05, forward, _player)
	_player.kick_view(-1.5, 1.0)
	Sound.play(&"throw")
	threw.emit(item, thrown)
	changed.emit(item, count)
	if count == 0:
		item = null
		changed.emit(null, 0)
	return true
