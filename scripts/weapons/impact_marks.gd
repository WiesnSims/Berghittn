class_name ImpactMarks
extends Node3D
## Pooled bullet holes. Decals are not available in the Compatibility renderer, so these are tiny quads.

@export var mark_size: float = 0.07
@export var mark_color: Color = Color(0.05, 0.04, 0.03, 1.0)

var _marks: Array[MeshInstance3D] = []
var _expire_at: Array[float] = []
var _next: int = 0


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(mark_size, mark_size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = mark_color
	quad.material = material
	for i: int in Constants.IMPACT_MARK_COUNT:
		var mark := MeshInstance3D.new()
		mark.mesh = quad
		# The holder moves with the camera; marks must stay where they landed.
		mark.top_level = true
		mark.visible = false
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		_marks.append(mark)
		_expire_at.append(0.0)


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for i: int in _marks.size():
		if _marks[i].visible and now >= _expire_at[i]:
			_marks[i].visible = false


func place(at: Vector3, normal: Vector3) -> void:
	var mark: MeshInstance3D = _marks[_next]
	_expire_at[_next] = Time.get_ticks_msec() / 1000.0 + Constants.IMPACT_MARK_LIFETIME
	_next = (_next + 1) % _marks.size()
	# Lift off the surface slightly to avoid z-fighting; the quad faces +Z, so point that along the normal.
	var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mark.global_transform = Transform3D(Basis.looking_at(-normal, up), at + normal * 0.005)
	mark.visible = true
