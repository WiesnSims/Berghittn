extends Node3D
## The Alphorn's note made visible: pale rings of sound that roll out from the bell along the cone,
## growing to its width as they go, or, for the Echo, rings rolling out flat around the player and
## one rising to the sky. Placed at the camera, -Z along the aim. Built in code, gone after a moment;
## the horn sound itself comes with M6.

const RINGS: int = 4
const RING_GAP: float = 0.07
const TRAVEL_TIME: float = 0.45
const LIFETIME: float = 1.2
const COLOR := Color(1.0, 0.9, 0.7, 0.3)
# The Echo's rings: fainter, since they sweep right past the camera.
const ECHO_COLOR := Color(1.0, 0.9, 0.7, 0.18)

var all_around: bool = false
## Metres the wave reaches, and the cone half-angle in degrees.
var reach: float = 12.0
var angle: float = 30.0


func _ready() -> void:
	if all_around:
		_echo()
	else:
		_cone()
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _cone() -> void:
	# The rings start at the bell, about a metre ahead and below the eye, and spread to the cone's width.
	var start := Vector3(0.1, -0.3, -1.0)
	var end := Vector3(0.0, 0.0, -reach)
	var end_radius: float = tan(deg_to_rad(angle)) * reach
	for i: int in RINGS:
		var ring := _ring(0.97, COLOR)
		# Torus axis is Y: turned to face down the aim.
		ring.rotation.x = PI * 0.5
		ring.position = start
		ring.scale = Vector3.ONE * 0.2
		add_child(ring)
		var tween := create_tween().set_parallel()
		var delay: float = i * RING_GAP
		tween.tween_property(ring, "position", end, TRAVEL_TIME).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(ring, "scale", Vector3(end_radius, 1.0 + end_radius * 0.3, end_radius), TRAVEL_TIME).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(ring.material_override, "albedo_color:a", 0.0, TRAVEL_TIME).set_delay(delay + TRAVEL_TIME * 0.3)


func _echo() -> void:
	# Flat, from the floor up to the waist (never at eye height, where a ring would wipe across the
	# whole screen), rolling outwards; and one going straight up into the storm.
	basis = Basis.IDENTITY
	for i: int in RINGS:
		var ring := _ring(0.96, ECHO_COLOR)
		ring.position = Vector3(0.0, -1.5 + 0.22 * i, 0.0)
		ring.scale = Vector3(1.0, 0.6, 1.0)
		add_child(ring)
		var tween := create_tween().set_parallel()
		var delay: float = i * RING_GAP
		tween.tween_property(ring, "scale", Vector3(reach, 0.8, reach), TRAVEL_TIME).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ring.material_override, "albedo_color:a", 0.0, TRAVEL_TIME).set_delay(delay + TRAVEL_TIME * 0.3)
	var sky := _ring(0.9, COLOR)
	sky.scale = Vector3.ONE * 0.3
	add_child(sky)
	var rise := create_tween().set_parallel()
	rise.tween_property(sky, "position:y", 14.0, LIFETIME).set_ease(Tween.EASE_OUT)
	rise.tween_property(sky, "scale", Vector3(2.5, 1.0, 2.5), LIFETIME)
	rise.tween_property(sky.material_override, "albedo_color:a", 0.0, LIFETIME)


func _ring(inner: float, color: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
