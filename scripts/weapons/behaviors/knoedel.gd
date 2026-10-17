extends Node3D
## One flying Semmelknödel from the Knödelwerfer, pooled. Falls in a ball arc, spinning, and bursts on
## the first wall, floor or body it touches (or in the air after KNOEDEL_MAX_FLIGHT), into a cloud of
## bread crumbs. Built in code: a pale bread ball with darker crust flecks.

const RADIUS: float = 0.17

var _launcher: Object
var _velocity: Vector3
var _gravity: float = 9.8
var _damage: int = 0
var _radius: float = 0.0
var _size: float = 1.0
var _flying: bool = false
var _flight: float = 0.0
var _ball: Node3D
var _crumbs: CPUParticles3D


func _ready() -> void:
	_ball = Node3D.new()
	add_child(_ball)
	var dough := StandardMaterial3D.new()
	dough.albedo_color = Color(0.93, 0.85, 0.66)
	dough.roughness = 0.95
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


func is_busy() -> bool:
	return _flying


func launch(launcher: Object, from: Vector3, velocity: Vector3, damage: int, radius: float, size: float) -> void:
	_launcher = launcher
	global_position = from
	_velocity = velocity
	_gravity = launcher.get("data").projectile_gravity
	_damage = damage
	_radius = radius
	_size = size
	_flight = 0.0
	_flying = true
	_ball.scale = Vector3.ONE * size
	_ball.visible = true


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_flight += delta
	_velocity.y -= _gravity * delta
	var step: Vector3 = _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step + step.normalized() * RADIUS * _size, Constants.LAYER_WORLD | Constants.LAYER_HITBOX, _launcher.get("holder").shooter_exclude())
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_burst(hit.position + hit.normal * 0.15)
		return
	global_position += step
	_ball.rotate(Vector3(_velocity.z, 0.0, -_velocity.x).normalized(), 9.0 * delta)
	if _flight >= Constants.KNOEDEL_MAX_FLIGHT:
		_burst(global_position)


func _burst(at: Vector3) -> void:
	_flying = false
	_ball.visible = false
	global_position = at
	_crumbs.restart()
	_launcher.call("burst", at, _damage, _radius, _size)
