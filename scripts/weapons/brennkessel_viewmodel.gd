class_name BrennkesselViewmodel
extends Viewmodel
## Brennkessel-Werfer: the brass lance held at the hip, a wooden grip with the trigger lever and a front
## handle, a black hose dropping away to the still on the back, a pilot flame at the copper nozzle and
## a gauge on top whose needle shows the fuel left. Held down, a stream of flame pours from the nozzle
## (only as far as the first wall) and the lance shudders; the Brennlacke jerks it up with a gulp.
## The reload is pumping the still: four strokes, the needle climbing back to full.

## Seconds the stream keeps pouring after the last tick (ticks come 8 times a second).
@export var stream_hold: float = 0.16
## Metres a second the flames leave the nozzle, how far the stream reaches at most, and the degrees
## the lance shudders while it pours.
@export var stream_speed: float = 16.0
@export var stream_reach: float = 8.0
@export var shudder: float = 0.6
## Needle angles (degrees) for an empty and a full still.
@export var needle_empty: float = 120.0
@export var needle_full: float = -120.0

@onready var _stream: CPUParticles3D = $Stream
@onready var _stream_light: OmniLight3D = $Stream/Light
@onready var _pilot: Node3D = $Model/Pilot
@onready var _needle: Node3D = $Model/Gauge/Needle

var _pouring_left: float = 0.0
var _holder: WeaponHolder
# During the reload the needle is animated instead of following the fuel.
var _pumping: bool = false


func _ready() -> void:
	super()
	(_stream.mesh as QuadMesh).material = Flames.material()
	_stream.color_ramp = Flames.ramp()
	# Thin at the nozzle, swelling as it goes.
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.15))
	swell.add_point(Vector2(0.4, 1.1))
	swell.add_point(Vector2(1.0, 2.2))
	_stream.scale_amount_curve = swell
	_stream.emitting = false
	_stream_light.light_energy = 0.0
	var node: Node = get_parent()
	while node and not node is WeaponHolder:
		node = node.get_parent()
	_holder = node as WeaponHolder


func fire_animation_time() -> float:
	# One tick of the flame; the stream itself runs on while the trigger is held.
	return 0.125


func play_fire(_rounds: int = 1) -> void:
	if _pouring_left <= 0.0:
		_stream.restart()
	_pouring_left = stream_hold
	_stream.emitting = true


func play_secondary(_rounds: int) -> void:
	# A gulp of schnaps out of the nozzle: the lance jerks up and back.
	_restart_tween()
	var up: Transform3D = _rest.translated_local(Vector3(0, 0, kick_distance)).rotated_local(Vector3.RIGHT, deg_to_rad(kick_angle))
	_tween.tween_property(_model, "transform", up, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_model, "transform", _rest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	# Lance lowered to the side, four strokes of the pump on the still, the needle climbing back.
	_restart_tween()
	_pumping = true
	var d: float = duration
	var lowered: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", lowered, d * 0.15).set_trans(Tween.TRANS_QUAD)
	_tween.parallel().tween_property(_needle, "rotation:z", deg_to_rad(needle_empty), d * 0.15)
	for i: int in 4:
		var share: float = (i + 1) / 4.0
		_tween.tween_property(_model, "transform", lowered.translated(Vector3(0, -0.03, 0)), d * 0.08).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(_model, "transform", lowered, d * 0.08).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(_needle, "rotation:z", deg_to_rad(lerpf(needle_empty, needle_full, share)), d * 0.08)
	_tween.tween_property(_model, "transform", _rest, d * 0.21).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void: _pumping = false)


func _process(delta: float) -> void:
	super(delta)
	# The pilot flame flickers all the time.
	_pilot.scale = Vector3.ONE * randf_range(0.8, 1.2)
	if _holder and _holder.weapon and not _pumping:
		var fuel: float = float(_holder.mag) / maxf(_holder.weapon.mag_size, 1.0)
		_needle.rotation.z = deg_to_rad(lerpf(needle_empty, needle_full, fuel))
	if _pouring_left <= 0.0:
		return
	_pouring_left -= delta
	# The stream stops at the first wall instead of pouring through it.
	var reach: float = stream_reach
	var from: Vector3 = _stream.global_position
	var ray := PhysicsRayQueryParameters3D.create(from, from - global_basis.z * stream_reach, Constants.LAYER_WORLD)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		reach = from.distance_to(hit.position)
	var lifetime: float = clampf(reach / stream_speed, 0.06, stream_reach / stream_speed)
	# Only on a real change: a new lifetime starts the emitter over.
	if absf(lifetime - _stream.lifetime) > 0.04:
		_stream.lifetime = lifetime
	_stream_light.light_energy = randf_range(2.0, 3.0)
	_model.transform = _rest.rotated_local(Vector3.UP, deg_to_rad(randf_range(-shudder, shudder))).rotated_local(Vector3.RIGHT, deg_to_rad(randf_range(-shudder, shudder)))
	if _pouring_left <= 0.0:
		_stream.emitting = false
		_stream_light.light_energy = 0.0
		_model.transform = _rest


func _reset_parts() -> void:
	super()
	_pumping = false
