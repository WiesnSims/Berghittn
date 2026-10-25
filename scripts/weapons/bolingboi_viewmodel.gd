class_name BolingboiViewmodel
extends Viewmodel
## Da Bolingboi (1.2): a hand in a loden sleeve, palm up under a glossy purple bowling ball. A shot
## swings the arm down and forward (the ball is let go), and the next ball is back in the hand as
## the arm comes up (fire_animation_time). Right click, Hoch damit!: a fist pump. The reload brings
## the arm down out of view and back with a ball. Built in code under Model as soon as the scene is
## made, so a copy of Model alone (WeaponPickup.model_of: a co-op hiker's hand, a drop) has it too.

## Seconds from a shot until the next ball is in the hand (= 1 / fire_rate).
@export var ready_time: float = 1.0

var _ball: Node3D
var _arm: Node3D


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_build()


func fire_animation_time() -> float:
	return ready_time


func play_fire(_rounds: int = 1) -> void:
	_restart_tween()
	_ball.visible = false
	var swung: Transform3D = _rest.translated(Vector3(0.0, -0.12, -0.12)).rotated_local(Vector3.RIGHT, deg_to_rad(-35.0))
	_tween.tween_property(_model, "transform", swung, ready_time * 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_model, "transform", _rest.translated(Vector3(0.0, -lower_drop, 0.0)), ready_time * 0.3).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(func() -> void: _ball.visible = true)
	_tween.tween_property(_model, "transform", _rest, ready_time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_secondary(_rounds: int) -> void:
	_restart_tween()
	var pumped: Transform3D = _rest.translated(Vector3(0.0, 0.06, 0.03)).rotated_local(Vector3.RIGHT, deg_to_rad(25.0))
	_tween.tween_property(_model, "transform", pumped, kick_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_model, "transform", _rest, kick_time * 2.0).set_trans(Tween.TRANS_QUAD)


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	_restart_tween()
	var lowered: Transform3D = _rest.translated(Vector3(0.0, -lower_drop, 0.05)).rotated_local(Vector3.RIGHT, deg_to_rad(-20.0))
	_tween.tween_property(_model, "transform", lowered, duration * 0.35).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(func() -> void: _ball.visible = true)
	_tween.tween_interval(duration * 0.2)
	_tween.tween_property(_model, "transform", _rest, duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build() -> void:
	var loden := StandardMaterial3D.new()
	loden.albedo_color = Color(0.22, 0.32, 0.2)
	loden.roughness = 0.95
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.86, 0.66, 0.52)
	skin.roughness = 0.8
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.42, 0.12, 0.62)
	shell.roughness = 0.15
	shell.metallic = 0.2
	var hole_material := StandardMaterial3D.new()
	hole_material.albedo_color = Color(0.05, 0.03, 0.06)
	var model: Node3D = get_node("Model")
	_arm = Node3D.new()
	model.add_child(_arm)
	_part(BoxMesh.new(), Vector3(0.09, 0.09, 0.32), Vector3(0.0, -0.04, 0.2), SharedLook.adopt(loden), _arm)
	_part(BoxMesh.new(), Vector3(0.1, 0.035, 0.12), Vector3(0.0, -0.04, -0.01), SharedLook.adopt(skin), _arm)
	# Fingers curled up round the ball's side.
	for i: int in 4:
		_part(BoxMesh.new(), Vector3(0.018, 0.06, 0.022), Vector3(-0.036 + i * 0.024, -0.005, -0.075), SharedLook.adopt(skin), _arm)
	_part(BoxMesh.new(), Vector3(0.02, 0.05, 0.05), Vector3(0.058, 0.0, -0.01), SharedLook.adopt(skin), _arm)
	_ball = Node3D.new()
	_ball.position = Vector3(0.0, 0.085, -0.03)
	model.add_child(_ball)
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	sphere.radial_segments = 18
	sphere.rings = 9
	_part(sphere, Vector3.ZERO, Vector3.ZERO, SharedLook.adopt(shell), _ball)
	var hole := CylinderMesh.new()
	hole.top_radius = 0.015
	hole.bottom_radius = 0.015
	hole.height = 0.02
	hole.radial_segments = 8
	hole.rings = 1
	for at: Vector3 in [Vector3(-0.025, 0.105, 0.0), Vector3(0.025, 0.105, 0.0), Vector3(0.0, 0.09, 0.05)]:
		var finger: MeshInstance3D = _part(hole, Vector3.ZERO, at, SharedLook.adopt(hole_material), _ball)
		finger.basis = Basis(Quaternion(Vector3.UP, at.normalized()))


func _part(mesh: PrimitiveMesh, size: Vector3, at: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	if mesh is BoxMesh and size != Vector3.ZERO:
		(mesh as BoxMesh).size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
