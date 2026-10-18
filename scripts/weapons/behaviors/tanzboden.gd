extends Node3D
## The Harmonika's Tanzboden (play-test 2026-10-18): a round wooden dance floor laid where the player
## aims. For TANZBODEN_TIME the Landler plays from it, golden notes rise, and whoever is on it dances
## (asking its weapon every TANZBODEN_SCAN, so walls and perks count). Then the music stops and it
## sinks away. Built in code: planks in a ring, a gold rim pulsing to the tune.

const NOTES := preload("res://scripts/weapons/behaviors/harmonika_notes.gd")
const SINK_TIME: float = 0.5
# Seconds between puffs of notes.
const NOTES_EVERY: float = 0.8

var _launcher: Object
var _left: float = 0.0
var _radius: float = 0.0
var _scan_left: float = 0.0
var _notes_left: float = 0.0
var _time: float = 0.0
var _floor: MeshInstance3D
var _rim: MeshInstance3D
var _rim_material: StandardMaterial3D
var _tune: AudioStreamPlayer3D


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.2)
	wood.roughness = 0.8
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.12
	disc.radial_segments = 12
	disc.rings = 1
	disc.material = wood
	_floor = MeshInstance3D.new()
	_floor.mesh = disc
	# Standing proud of bumps in the snow.
	_floor.position.y = 0.08
	add_child(_floor)
	_rim_material = StandardMaterial3D.new()
	_rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_material.albedo_color = Color(1.0, 0.8, 0.3, 0.6)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.94
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 4
	ring.material = _rim_material
	_rim = MeshInstance3D.new()
	_rim.mesh = ring
	_rim.position.y = 0.15
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rim)
	visible = false


func is_busy() -> bool:
	return _left > -SINK_TIME


func lay(launcher: Object, at: Vector3, radius: float) -> void:
	_launcher = launcher
	global_position = at
	_radius = radius
	_left = Constants.TANZBODEN_TIME
	_scan_left = 0.0
	_notes_left = 0.0
	scale = Vector3(radius, 1.0, radius)
	visible = true
	if is_instance_valid(_tune):
		_tune.queue_free()
	_tune = Sound.attach(&"harmonika_play", self)


func _physics_process(delta: float) -> void:
	if _left <= -SINK_TIME:
		return
	_left -= delta
	_time += delta
	if _left <= 0.0:
		# The music stops and it sinks into the ground.
		if is_instance_valid(_tune):
			_tune.queue_free()
		position.y -= 0.12 * delta / SINK_TIME
		if _left <= -SINK_TIME:
			visible = false
		return
	# The rim swells with the three-four of the Landler.
	_rim.scale = Vector3.ONE * (1.0 + 0.04 * sin(_time * TAU / Constants.TANZBODEN_BEAT))
	_rim_material.albedo_color.a = 0.4 + 0.25 * (0.5 + 0.5 * sin(_time * TAU / Constants.TANZBODEN_BEAT))
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = Constants.TANZBODEN_SCAN
		_launcher.call("dance_floor", global_position, _radius)
	_notes_left -= delta
	if _notes_left <= 0.0:
		_notes_left = NOTES_EVERY
		var notes := Node3D.new()
		notes.set_script(NOTES)
		notes.set("reach", _radius)
		notes.set("amount", 0.35)
		get_parent().add_child(notes)
		# The notes start their eye height below where they are put.
		notes.global_position = global_position + Vector3.UP * -NOTES.FEET
