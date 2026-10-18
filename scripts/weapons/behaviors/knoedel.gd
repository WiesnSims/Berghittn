extends LobbedShot
## One flying Semmelknödel from the Knödelwerfer (a LobbedShot), spinning in its ball arc and bursting
## into a cloud of bread crumbs. Built in code: a pale bread ball with darker crust flecks.

const RADIUS: float = 0.17

var _ball: Node3D
var _crumbs: CPUParticles3D


func _ready() -> void:
	hit_radius = RADIUS
	_ball = Node3D.new()
	add_child(_ball)
	var dough := StandardMaterial3D.new()
	dough.albedo_color = Color(0.93, 0.85, 0.66)
	dough.roughness = 0.95
	SharedLook.adopt(dough)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	sphere.material = dough
	var body := MeshInstance3D.new()
	body.mesh = sphere
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.add_child(body)
	# Crust and herb flecks, so the spin can be seen.
	var crust := StandardMaterial3D.new()
	crust.albedo_color = Color(0.62, 0.42, 0.2)
	var herb := StandardMaterial3D.new()
	herb.albedo_color = Color(0.22, 0.4, 0.15)
	SharedLook.adopt(crust)
	SharedLook.adopt(herb)
	var fleck := BoxMesh.new()
	fleck.size = Vector3(0.06, 0.06, 0.03)
	for i: int in 7:
		var bit := MeshInstance3D.new()
		bit.mesh = fleck
		bit.material_override = herb if i % 3 == 0 else crust
		var direction: Vector3 = Vector3(sin(i * 2.4), cos(i * 1.7), sin(i * 0.9 + 1.0)).normalized()
		bit.position = direction * RADIUS * 0.95
		bit.rotation = direction * 2.0
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ball.add_child(bit)
	_crumbs = CPUParticles3D.new()
	_crumbs.one_shot = true
	_crumbs.emitting = false
	_crumbs.explosiveness = 1.0
	_crumbs.amount = 36
	_crumbs.lifetime = 0.9
	_crumbs.direction = Vector3.UP
	_crumbs.spread = 90.0
	_crumbs.initial_velocity_min = 3.5
	_crumbs.initial_velocity_max = 8.0
	_crumbs.gravity = Vector3(0, -12, 0)
	_crumbs.scale_amount_min = 0.6
	_crumbs.scale_amount_max = 1.4
	var crumb := BoxMesh.new()
	# Big enough to read as a splash from across the beer garden.
	crumb.size = Vector3(0.13, 0.1, 0.13)
	crumb.material = dough
	_crumbs.mesh = crumb
	add_child(_crumbs)
	_ball.visible = false


func _on_launch() -> void:
	_ball.scale = Vector3.ONE * _size
	_ball.visible = true


func _on_fly(delta: float, velocity: Vector3) -> void:
	_ball.rotate(Vector3(velocity.z, 0.0, -velocity.x).normalized(), 9.0 * delta)


func _on_burst(_at: Vector3) -> void:
	_ball.visible = false
	_crumbs.restart()
