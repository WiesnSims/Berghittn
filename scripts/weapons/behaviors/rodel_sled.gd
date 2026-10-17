extends Node3D
## The Rodelkanone's sled, pooled by its behavior: set down on the floor a step ahead of the shooter,
## it rides the ground (up steps up to RODEL_STEP, down slopes, off edges with a fall) at the
## weapon's projectile_speed until it has run its distance or hits a wall, striking every body in
## its lane once. With banks left it turns off a wall like a ball off a cushion instead of breaking.
## Built in code: two runners with curled tips, slats on top, a puff of snow behind.

const LENGTH: float = 1.1
const WIDTH: float = 0.5
# How far ahead of the shooter's feet it lands, and how far ahead of its middle it looks for walls.
const LAND_AHEAD: float = 0.9
const NOSE: float = 0.55
# Where bodies are looked for, above its runners.
const BODY_HEIGHT: float = 0.9
# How far below its runners the ground may fall away in one step and still be ridden down (slopes).
const STICK: float = 0.35

var _launcher: Object
var _direction: Vector3 = Vector3.FORWARD
var _damage: int = 0
var _left: float = 0.0
var _banks: int = 0
var _fall: float = 0.0
var _dropped: float = 0.0
var _struck: Dictionary = {}
var _busy: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _model: Node3D
var _spray: CPUParticles3D
var _splinters: CPUParticles3D


func _ready() -> void:
	_build()
	_model.visible = false


func is_busy() -> bool:
	return _busy


func launch(launcher: Object, feet: Vector3, direction: Vector3, damage: int, distance: float, banks: int) -> void:
	_launcher = launcher
	_direction = direction
	_damage = damage
	_left = distance
	_banks = banks
	_fall = 0.0
	_dropped = 0.0
	_struck.clear()
	_busy = true
	_model.visible = true
	_spray.emitting = true
	global_position = feet
	_face(Vector3.UP)
	# Out of the barrel and onto the ground ahead, unless a wall is right there.
	_ride(LAND_AHEAD, true)


func _physics_process(delta: float) -> void:
	if not _busy:
		return
	var speed: float = _launcher.get("data").projectile_speed
	_ride(minf(speed * delta, _left), false)
	if _busy:
		_strike_lane()
	if _busy and _left <= 0.0:
		_crash()


## Moves `distance` along the lane: off a wall (bank or break), then onto the floor below. The wall
## ray runs at step height, so steps and kerbs below it are ridden over.
func _ride(distance: float, landing: bool) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var exclude: Array[RID] = _launcher.get("holder").shooter_exclude()
	var knee := Vector3.UP * Constants.RODEL_STEP
	var wall := PhysicsRayQueryParameters3D.create(global_position + knee, global_position + knee + _direction * (distance + NOSE), Constants.LAYER_WORLD, exclude)
	var hit: Dictionary = space.intersect_ray(wall)
	# A slope it can ride up is no wall.
	if not hit.is_empty() and hit.normal.y < 0.6:
		if _banks <= 0 or landing:
			_crash()
			return
		_banks -= 1
		var normal := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
		var turned: Vector3 = _direction.bounce(normal)
		_direction = Vector3(turned.x, 0.0, turned.z).normalized()
		# Its nose against the wall, pointing the new way.
		global_position = Vector3(hit.position.x, global_position.y, hit.position.z) + normal * NOSE
		_face(Vector3.UP)
		return
	var next: Vector3 = global_position + _direction * distance
	if not landing:
		_left -= distance
	var delta: float = get_physics_process_delta_time()
	var reach: float = STICK + _fall * delta
	var down := PhysicsRayQueryParameters3D.create(next + knee, next + Vector3.DOWN * reach, Constants.LAYER_WORLD, exclude)
	var ground: Dictionary = space.intersect_ray(down)
	if not ground.is_empty():
		next.y = ground.position.y
		_fall = 0.0
		_dropped = 0.0
		_face(ground.normal)
	else:
		# Off an edge: it drops, and is lost if it falls too far.
		_fall += _gravity * delta
		next.y -= _fall * delta
		_dropped += _fall * delta
	global_position = next
	if _dropped > Constants.RODEL_MAX_DROP:
		_crash()


## Every body in its lane it has not run into yet: struck once and thrown aside, out of the lane.
func _strike_lane() -> void:
	var shape := SphereShape3D.new()
	shape.radius = Constants.RODEL_LANE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * BODY_HEIGHT)
	query.collision_mask = Constants.LAYER_HITBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var push_strength: float = _launcher.get("data").knockback
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, Constants.AREA_MAX_TARGETS):
		var hurtbox := found.collider as Hurtbox
		if hurtbox == null or hurtbox.is_head or _struck.has(hurtbox.receiver):
			continue
		_struck[hurtbox.receiver] = true
		var offset: Vector3 = hurtbox.global_position - global_position
		var side: Vector3 = _direction.cross(Vector3.UP)
		if offset.dot(side) < 0.0:
			side = -side
		var push: Vector3 = (_direction + side * Constants.RODEL_SIDE_PUSH).normalized() * push_strength
		_launcher.call("strike", hurtbox, _damage, push)


func _crash() -> void:
	_busy = false
	_model.visible = false
	_spray.emitting = false
	_splinters.global_position = global_position + Vector3.UP * 0.3
	_splinters.restart()
	_launcher.call("crash", global_position)


func _face(up: Vector3) -> void:
	var forward: Vector3 = (_direction - up * _direction.dot(up)).normalized()
	if forward.length() < 0.1:
		forward = _direction
	global_basis = Basis.looking_at(forward, up)


func _build() -> void:
	_model = Node3D.new()
	add_child(_model)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.78, 0.55, 0.32)
	wood.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.58, 0.36, 0.19)
	dark.roughness = 0.8
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.25, 0.25, 0.27)
	iron.metallic = 0.6
	for x: float in [-WIDTH * 0.5, WIDTH * 0.5]:
		# The runner, its iron shoe, and the tip curling up at the front.
		_box(Vector3(0.045, 0.07, LENGTH), Vector3(x, 0.07, 0.0), Vector3.ZERO, dark)
		_box(Vector3(0.05, 0.015, LENGTH), Vector3(x, 0.01, 0.0), Vector3.ZERO, iron)
		_box(Vector3(0.045, 0.07, 0.3), Vector3(x, 0.17, -LENGTH * 0.5 - 0.06), Vector3(deg_to_rad(55.0), 0.0, 0.0), dark)
		for z: float in [-0.3, 0.0, 0.3]:
			_box(Vector3(0.04, 0.16, 0.04), Vector3(x, 0.18, z), Vector3.ZERO, dark)
	for i: int in 5:
		_box(Vector3(WIDTH + 0.08, 0.025, 0.12), Vector3(0.0, 0.27, -0.32 + i * 0.16), Vector3.ZERO, wood)
	# A rope to steer by, looped from tip to tip.
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.85, 0.15, 0.12)
	_box(Vector3(WIDTH, 0.025, 0.025), Vector3(0.0, 0.26, -LENGTH * 0.5 - 0.14), Vector3.ZERO, rope)
	_spray = CPUParticles3D.new()
	_spray.amount = 30
	_spray.lifetime = 0.5
	_spray.local_coords = false
	_spray.emitting = false
	_spray.position = Vector3(0.0, 0.05, LENGTH * 0.5)
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_spray.emission_box_extents = Vector3(WIDTH * 0.5, 0.02, 0.05)
	_spray.direction = Vector3(0.0, 1.0, 0.6)
	_spray.spread = 35.0
	_spray.initial_velocity_min = 1.0
	_spray.initial_velocity_max = 2.5
	_spray.gravity = Vector3(0.0, -6.0, 0.0)
	_spray.scale_amount_min = 0.6
	_spray.scale_amount_max = 1.4
	var puff := SphereMesh.new()
	puff.radius = 0.05
	puff.height = 0.1
	puff.radial_segments = 6
	puff.rings = 3
	var snow := StandardMaterial3D.new()
	snow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow.albedo_color = Color(0.95, 0.97, 1.0, 0.8)
	puff.material = snow
	_spray.mesh = puff
	add_child(_spray)
	_splinters = CPUParticles3D.new()
	_splinters.amount = 18
	_splinters.lifetime = 0.9
	_splinters.one_shot = true
	_splinters.explosiveness = 1.0
	_splinters.emitting = false
	_splinters.local_coords = false
	_splinters.top_level = true
	_splinters.direction = Vector3.UP
	_splinters.spread = 70.0
	_splinters.initial_velocity_min = 2.5
	_splinters.initial_velocity_max = 5.0
	_splinters.angular_velocity_min = -540.0
	_splinters.angular_velocity_max = 540.0
	_splinters.particle_flag_rotate_y = true
	_splinters.gravity = Vector3(0.0, -12.0, 0.0)
	var plank := BoxMesh.new()
	plank.size = Vector3(0.05, 0.025, 0.22)
	plank.material = wood
	_splinters.mesh = plank
	add_child(_splinters)


func _box(size: Vector3, at: Vector3, turn: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.rotation = turn
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(part)
