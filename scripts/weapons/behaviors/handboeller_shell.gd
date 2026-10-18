extends LobbedShot
## The Handböller's iron shell (a LobbedShot): a black ball with its fuse sputtering, trailing powder
## smoke. Built in code; the burst itself is the Böller blast the behavior sets off.

const RADIUS: float = 0.09

var _ball: Node3D
var _smoke: CPUParticles3D


func _ready() -> void:
	hit_radius = RADIUS
	_ball = Node3D.new()
	add_child(_ball)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.1, 0.11)
	iron.metallic = 0.6
	iron.roughness = 0.5
	SharedLook.adopt(iron)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	sphere.material = iron
	var body := MeshInstance3D.new()
	body.mesh = sphere
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.add_child(body)
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = Color(1.0, 0.7, 0.25)
	var spark := SphereMesh.new()
	spark.radius = 0.03
	spark.height = 0.06
	spark.radial_segments = 6
	spark.rings = 3
	spark.material = fire
	var fuse := MeshInstance3D.new()
	fuse.mesh = spark
	fuse.position = Vector3.UP * RADIUS
	fuse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.add_child(fuse)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 24
	_smoke.lifetime = 0.6
	_smoke.local_coords = false
	_smoke.emitting = false
	_smoke.direction = Vector3.UP
	_smoke.spread = 40.0
	_smoke.initial_velocity_min = 0.2
	_smoke.initial_velocity_max = 0.6
	_smoke.gravity = Vector3(0, 0.5, 0)
	var puff := SphereMesh.new()
	puff.radius = 0.06
	puff.height = 0.12
	puff.radial_segments = 6
	puff.rings = 3
	var grey := StandardMaterial3D.new()
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grey.albedo_color = Color(0.7, 0.68, 0.64, 0.5)
	puff.material = grey
	_smoke.mesh = puff
	add_child(_smoke)
	_ball.visible = false


func _on_launch() -> void:
	_ball.visible = true
	_smoke.emitting = true


func _on_fly(delta: float, velocity: Vector3) -> void:
	_ball.rotate(Vector3(velocity.z, 0.0, -velocity.x).normalized(), 6.0 * delta)


func _on_burst(_at: Vector3) -> void:
	_ball.visible = false
	_smoke.emitting = false
