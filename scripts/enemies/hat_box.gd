class_name HatBox
extends Area3D
## The hit box round an enemy's hat (Huat obschiaßn). Not a Hurtbox: a bullet that goes through it
## knocks the hat off and flies on, so a shot through the hat can still be a headshot. On its own
## layer (Constants.LAYER_HAT), so only bullet rays see it.

## The enemy wearing it.
var receiver: Enemy
var _shape := CollisionShape3D.new()


func _init() -> void:
	name = "HatBox"
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	_shape.shape = BoxShape3D.new()
	add_child(_shape)


## Fits the box round `bounds` (the hat mesh's, in the model's space), cut off at `floor_y`: a
## helmet's lower half, hidden in the head, is no target, so a shot at the face leaves the hat on.
func fit(bounds: AABB, floor_y: float) -> void:
	var bottom: float = clampf(floor_y, bounds.position.y, bounds.end.y - 0.05)
	var box := AABB(Vector3(bounds.position.x, bottom, bounds.position.z), Vector3(bounds.size.x, bounds.end.y - bottom, bounds.size.z))
	box = box.grow(Constants.HAT_BOX_MARGIN)
	(_shape.shape as BoxShape3D).size = box.size
	_shape.position = box.get_center()


func set_on(on: bool) -> void:
	collision_layer = Constants.LAYER_HAT if on else 0


## Whether the line from `from` to `to` goes through the box (while it is on).
func crosses(from: Vector3, to: Vector3) -> bool:
	if collision_layer == 0:
		return false
	var local: Transform3D = (global_transform * _shape.transform).affine_inverse()
	var half: Vector3 = (_shape.shape as BoxShape3D).size * 0.5
	return AABB(-half, half * 2.0).intersects_segment(local * from, local * to) != null
