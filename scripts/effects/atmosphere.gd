class_name Atmosphere
extends Node
## Inside the hut the air is warm and clear; outside the storm swallows everything past a few
## metres. The Compatibility renderer has one global fog, so this eases it (and the ambient light)
## between an indoor and an outdoor look as the camera passes under a roof. The Environment resource
## itself holds the outdoor look, since the mountain backdrop takes its fog colour from it at load.

@export var environment: WorldEnvironment
@export var roof_map: RoofMap

@export_group("Outdoors")
@export var outdoor_fog_color: Color = Color(0.36, 0.4, 0.5)
@export var outdoor_fog_density: float = 0.045
@export var outdoor_ambient_color: Color = Color(0.42, 0.48, 0.6)
@export var outdoor_ambient_energy: float = 0.45

@export_group("Indoors")
@export var indoor_fog_color: Color = Color(0.2, 0.14, 0.1)
@export var indoor_fog_density: float = 0.012
@export var indoor_ambient_color: Color = Color(0.5, 0.42, 0.36)
@export var indoor_ambient_energy: float = 0.3

# 0 = outdoors, 1 = indoors.
var _inside: float = 1.0
var _last_camera: Vector3 = Vector3.ZERO


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or environment == null:
		return
	var target: float = 1.0 if roof_map.is_covered(camera.global_position) else 0.0
	# A jump in position (respawn, a test camera) is a cut, not a walk through a door.
	var cut: bool = camera.global_position.distance_to(_last_camera) > Constants.ATMOSPHERE_CUT_DISTANCE
	_last_camera = camera.global_position
	_inside = target if cut else move_toward(_inside, target, delta / Constants.ATMOSPHERE_BLEND_TIME)
	var t: float = smoothstep(0.0, 1.0, _inside)
	var env: Environment = environment.environment
	env.fog_light_color = outdoor_fog_color.lerp(indoor_fog_color, t)
	env.fog_density = lerpf(outdoor_fog_density, indoor_fog_density, t)
	env.ambient_light_color = outdoor_ambient_color.lerp(indoor_ambient_color, t)
	env.ambient_light_energy = lerpf(outdoor_ambient_energy, indoor_ambient_energy, t)
