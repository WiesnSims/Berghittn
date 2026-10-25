extends "res://scripts/weapons/behaviors/rodel_sled.gd"
## The Bolingboi's ball (1.2): the Rodelkanone's sled riding (straight along the ground, every body in
## its way struck once), with a glossy purple bowling ball's look, spinning as it rolls. Where the sled
## would break (a wall, the end of its run) it explodes instead: its launcher's crash() does the blast.
## It never banks (launched with none). detonate() sets it off early.

const BALL_RADIUS: float = 0.16

var _spinner: Node3D


func _physics_process(delta: float) -> void:
	var before: Vector3 = global_position
	super(delta)
	if _busy and _spinner:
		var moved: Vector3 = global_position - before
		var flat := Vector3(moved.x, 0.0, moved.z)
		if flat.length() > 0.0001:
			_spinner.global_rotate(flat.cross(Vector3.DOWN).normalized(), flat.length() / BALL_RADIUS)


## Hoch damit!: goes off now, where it is.
func detonate() -> void:
	if _busy:
		_crash()


func _build() -> void:
	_model = Node3D.new()
	add_child(_model)
	_spinner = Node3D.new()
	_spinner.position = Vector3.UP * BALL_RADIUS
	_model.add_child(_spinner)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.42, 0.12, 0.62)
	shell.roughness = 0.15
	shell.metallic = 0.2
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = SharedLook.adopt(shell)
	var ball := MeshInstance3D.new()
	ball.mesh = sphere
	_spinner.add_child(ball)
	# The three finger holes, so its spin shows.
	var hole_material := StandardMaterial3D.new()
	hole_material.albedo_color = Color(0.05, 0.03, 0.06)
	var hole := CylinderMesh.new()
	hole.top_radius = 0.022
	hole.bottom_radius = 0.022
	hole.height = 0.03
	hole.radial_segments = 8
	hole.rings = 1
	hole.material = SharedLook.adopt(hole_material)
	for at: Vector3 in [Vector3(-0.035, 0.0, -0.03), Vector3(0.035, 0.0, -0.03), Vector3(0.0, 0.0, 0.05)]:
		var finger := MeshInstance3D.new()
		finger.mesh = hole
		var out: Vector3 = (at + Vector3.UP * 0.14).normalized()
		finger.position = out * BALL_RADIUS * 0.96
		finger.basis = Basis(Quaternion(Vector3.UP, out))
		_spinner.add_child(finger)
	# Dust off the floor behind it, and the sled's splinters as its sparks when it goes off.
	_spray = CPUParticles3D.new()
	_spray.amount = 10
	_spray.lifetime = 0.4
	_spray.direction = Vector3(0, 1, 1)
	_spray.spread = 25.0
	_spray.initial_velocity_min = 0.5
	_spray.initial_velocity_max = 1.2
	_spray.gravity = Vector3(0, -3, 0)
	var dust := BoxMesh.new()
	dust.size = Vector3(0.03, 0.03, 0.03)
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.75, 0.72, 0.68)
	dust.material = SharedLook.adopt(dust_material)
	_spray.mesh = dust
	_spray.emitting = false
	add_child(_spray)
	_splinters = CPUParticles3D.new()
	_splinters.one_shot = true
	_splinters.emitting = false
	_splinters.explosiveness = 1.0
	_splinters.amount = 12
	_splinters.lifetime = 0.6
	_splinters.direction = Vector3.UP
	_splinters.spread = 80.0
	_splinters.initial_velocity_min = 2.0
	_splinters.initial_velocity_max = 5.0
	_splinters.gravity = Vector3(0, -12, 0)
	var shard := BoxMesh.new()
	shard.size = Vector3(0.05, 0.05, 0.05)
	shard.material = sphere.material
	_splinters.mesh = shard
	_splinters.top_level = true
	add_child(_splinters)
