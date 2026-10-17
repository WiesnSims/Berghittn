extends Node3D
## A burning puddle of schnaps from the Brennkessel's Brennlacke, pooled. For LACKE_TIME it sets alight
## whatever stands in it (asking its weapon every LACKE_INTERVAL, so walls and perks count), then
## the flames die down. Built in code: a dark wet disc, flames all over it, an orange light.

const FADE_TIME: float = 0.6

var _launcher: Object
var _left: float = 0.0
var _radius: float = 0.0
var _check_left: float = 0.0
var _disc: MeshInstance3D
var _flames: CPUParticles3D
var _light: OmniLight3D


func _ready() -> void:
	var wet := StandardMaterial3D.new()
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color = Color(0.1, 0.05, 0.02, 0.75)
	wet.roughness = 0.05
	wet.metallic = 0.3
	wet.emission_enabled = true
	wet.emission = Color(0.25, 0.08, 0.02)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	disc.material = wet
	_disc = MeshInstance3D.new()
	_disc.mesh = disc
	_disc.position.y = 0.02
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	_flames = Flames.particles(60, 0.7, Vector2(0.35, 0.5))
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.position.y = 0.1
	add_child(_flames)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.position.y = 0.8
	add_child(_light)
	visible = false


func is_busy() -> bool:
	return _left > 0.0


func radius() -> float:
	return _radius


func lay(launcher: Object, at: Vector3, radius: float) -> void:
	_launcher = launcher
	global_position = at
	_radius = radius
	_left = Constants.LACKE_TIME
	_check_left = 0.0
	_disc.scale = Vector3(radius, 1.0, radius)
	# Flames all over the puddle, low down.
	_flames.emission_box_extents = Vector3(radius * 0.7, 0.05, radius * 0.7)
	_flames.emitting = true
	_light.light_energy = 2.0
	_light.omni_range = radius * 3.0
	visible = true


func _physics_process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	# Flickers like a fire.
	_light.light_energy = 1.6 + randf() * 0.8
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = Constants.LACKE_INTERVAL
		_launcher.call("burn_lacke", global_position, _radius)
	if _left <= FADE_TIME:
		_flames.emitting = false
		_light.light_energy *= _left / FADE_TIME
	if _left <= 0.0:
		visible = false
