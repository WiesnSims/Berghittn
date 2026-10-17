extends LobbedShot
## A gulp of schnaps squirted from the Brennkessel's lance (a LobbedShot), already alight, trailing
## flame; it splashes on the first wall, floor or body and its weapon lays a burning puddle there.
## Built in code: a glowing amber blob.

const RADIUS: float = 0.12

var _blob: MeshInstance3D
var _trail: CPUParticles3D


func _ready() -> void:
	hit_radius = RADIUS
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.7, 0.25)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = glow
	_blob = MeshInstance3D.new()
	_blob.mesh = sphere
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blob)
	_trail = Flames.particles(20, 0.35, Vector2(0.2, 0.26))
	_trail.local_coords = false
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = RADIUS
	_trail.gravity = Vector3(0.0, 2.0, 0.0)
	add_child(_trail)
	_blob.visible = false


func _on_launch() -> void:
	_blob.visible = true
	_trail.emitting = true


func _on_burst(_at: Vector3) -> void:
	_blob.visible = false
	_trail.emitting = false
