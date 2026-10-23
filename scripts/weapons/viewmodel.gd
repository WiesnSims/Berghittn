class_name Viewmodel
extends Node3D
## First-person gun model: recoil kick, slide blowback, ejected casings, reload, draw and muzzle flash. Purely visual.
## This base is the pistol (slide and magazine); guns that work differently extend it and override
## play_fire and play_reload.

## Kick per shot: metres back and degrees of muzzle climb.
@export var kick_distance: float = 0.05
@export var kick_angle: float = 9.0
@export var kick_time: float = 0.12
## Reload pose: where the gun is held up for the mag swap (so the drop is on screen) and its roll, how far the old mag falls and the new one
## starts below the grip, and how high the gun jumps when the mag is slapped in. Metres/degrees.
@export var reload_offset: Vector3 = Vector3(-0.06, 0.07, 0.0)
@export var reload_tilt: float = 40.0
@export var mag_drop: float = 0.35
@export var mag_insert_from: float = 0.12
@export var slap_lift: float = 0.03
## How far the slide is pulled back when chambering a round. Metres.
@export var slide_travel: float = 0.06
## Degrees the gun turns to show its side while racking.
@export var chamber_turn: float = 50.0
## Where the whole gun moves when fully aimed, so its sights sit on the middle of the screen. Metres.
@export var aim_offset: Vector3 = Vector3.ZERO
## How far the gun drops out of view during a melee swing. Metres.
@export var lower_drop: float = 0.3
## Where casings leave the gun (model space) and how they fly (camera space: right, up, back; m/s).
@export var ejection_port: Vector3 = Vector3(0.02, 0.02, -0.02)
@export var ejection_velocity: Vector3 = Vector3(1.8, 1.4, 0.4)
@export var casing_color: Color = Color(0.8, 0.62, 0.25, 1)
@export var casing_size: Vector3 = Vector3(0.009, 0.009, 0.022)

@onready var _model: Node3D = $Model
# Pistol parts; other guns do not have them.
@onready var _slide: Node3D = get_node_or_null("Model/Slide")
@onready var _slide_rest: Vector3 = _slide.position if _slide else Vector3.ZERO
@onready var _flash: Node3D = $Model/MuzzleFlash
@onready var _flash_light: OmniLight3D = $Model/MuzzleFlash/Light
@onready var _flash_energy: float = _flash_light.light_energy
@onready var _mag: Node3D = get_node_or_null("Model/Grip/Magazine")
@onready var _mag_rest: Vector3 = _mag.position if _mag else Vector3.ZERO

## Seconds from this shot to the next one (set by the WeaponHolder before play_fire): a gun worked
## between shots fits its action into it, e.g. the Repetierer when fanned.
var cycle_time: float = 0.0

var _rest: Transform3D
var _tween: Tween
# Moving parts (slide, bolt, barrels) animate on their own tween, alongside the kick.
var _parts_tween: Tween
var _flash_left: float = 0.0
var _aim: float = 0.0
# Pooled casings, flown by hand: a physics body per shot would be wasted on something gone in half a second.
var _casings: Array[MeshInstance3D] = []
var _casing_velocity: Array[Vector3] = []
var _casing_spin: Array[Vector3] = []
var _casing_left: Array[float] = []
var _next_casing: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_rest = _model.transform
	_flash.visible = false
	var mesh := BoxMesh.new()
	mesh.size = casing_size
	var material := StandardMaterial3D.new()
	material.albedo_color = casing_color
	material.metallic = 0.7
	mesh.material = SharedLook.adopt(material)
	for i: int in Constants.CASING_POOL_SIZE:
		var casing := MeshInstance3D.new()
		casing.mesh = mesh
		casing.top_level = true
		casing.visible = false
		casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(casing)
		_casings.append(casing)
		_casing_velocity.append(Vector3.ZERO)
		_casing_spin.append(Vector3.ZERO)
		_casing_left.append(0.0)


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_flash.visible = _flash_left > 0.0
		# The light dies out instead of switching off, so the room visibly flickers with each shot.
		_flash_light.light_energy = _flash_energy * lerpf(1.0, Constants.AIM_FLASH_LIGHT, _aim) 				* clampf(_flash_left / Constants.MUZZLE_FLASH_TIME, 0.0, 1.0)
	for i: int in _casings.size():
		if _casing_left[i] <= 0.0:
			continue
		_casing_left[i] -= delta
		_casing_velocity[i].y -= _gravity * delta
		var casing: MeshInstance3D = _casings[i]
		casing.global_position += _casing_velocity[i] * delta
		casing.rotate(_casing_spin[i].normalized(), _casing_spin[i].length() * delta)
		casing.visible = _casing_left[i] > 0.0


func play_fire(_rounds: int = 1) -> void:
	_flash_and_kick()
	# Blowback: the slide slams back and returns, the casing flies out of the port as it does.
	_parts_tween = create_tween()
	_parts_tween.tween_property(_slide, "position", _slide_rest + Vector3(0, 0, slide_travel * 0.7), kick_time * 0.2)
	_parts_tween.tween_property(_slide, "position", _slide_rest, kick_time * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_eject_casing()


## Seconds the shot animation runs; guns whose action is worked after a shot (Stutzen, Jagdflinte)
## have fire_rate set so the next shot is ready right as it ends (play-test).
func fire_animation_time() -> float:
	return kick_time


## A special weapon's second shot (BEHAVIOR secondary); guns with one override this.
func play_secondary(rounds: int) -> void:
	play_fire(rounds)


## A held PLAY secondary is playing (set every frame while it plays) or stopped; guns with one
## override this.
func set_playing(_on: bool) -> void:
	pass


## Aim pose blend (0 hip, 1 aimed), set every frame by the WeaponHolder.
func set_aim(amount: float) -> void:
	position = aim_offset * amount
	_aim = amount


func _flash_and_kick(strength: float = 1.0) -> void:
	_flash_left = Constants.MUZZLE_FLASH_TIME
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	# Aimed, the flash sits right in front of the sights: keep it small there.
	_flash.scale = Vector3.ONE * lerpf(1.0, Constants.AIM_FLASH_SCALE, _aim)
	_flash_light.light_energy = _flash_energy * lerpf(1.0, Constants.AIM_FLASH_LIGHT, _aim)
	_restart_tween()
	var kicked: Transform3D = _rest.translated_local(Vector3(0, 0, kick_distance * strength)).rotated_local(Vector3.RIGHT, deg_to_rad(kick_angle * strength))
	_model.transform = kicked
	_tween.tween_property(_model, "transform", _rest, kick_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _eject_casing() -> void:
	var i: int = _next_casing
	_next_casing = (_next_casing + 1) % _casings.size()
	var casing: MeshInstance3D = _casings[i]
	var camera_basis: Basis = global_basis
	casing.global_transform = Transform3D(camera_basis, _model.to_global(ejection_port))
	var jitter := Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
	_casing_velocity[i] = camera_basis * (ejection_velocity + jitter)
	_casing_spin[i] = Vector3(randf_range(-30, 30), randf_range(-30, 30), randf_range(-30, 30))
	_casing_left[i] = Constants.CASING_LIFETIME
	casing.visible = true


func play_reload(duration: float, chamber_time: float = 0.0) -> void:
	# Tilt, old mag drops out, new one slapped in; from empty, rack the slide after. Then back to rest.
	_restart_tween()
	var d: float = duration
	var tilted: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", tilted, d * 0.15).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_mag, "position", _mag_rest + Vector3(0, -mag_drop, 0), d * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: _mag.position = _mag_rest + Vector3(0, -mag_insert_from, 0))
	_tween.tween_property(_mag, "position", _mag_rest, d * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The slap: the gun jumps up as the mag seats.
	_tween.tween_property(_model, "transform", tilted.translated(Vector3(0, slap_lift, 0)), d * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if chamber_time > 0.0:
		# Turn the gun side-on so the rack reads, pull the slide back, let it snap forward with a little kick.
		var side_on: Transform3D = tilted.rotated_local(Vector3.UP, deg_to_rad(chamber_turn))
		var back: Vector3 = _slide_rest + Vector3(0, 0, slide_travel)
		_tween.tween_property(_model, "transform", side_on, chamber_time * 0.6).set_trans(Tween.TRANS_QUAD)
		_tween.parallel().tween_property(_slide, "position", back, chamber_time * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_slide, "position", _slide_rest, chamber_time * 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(_model, "transform", side_on.rotated_local(Vector3.RIGHT, deg_to_rad(kick_angle)), chamber_time * 0.15)
		_tween.tween_interval(chamber_time * 0.25)
	_tween.tween_property(_model, "transform", _rest, d * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func play_raise(duration: float) -> void:
	# Drawn: comes up from below the view, settling with a little tilt.
	_restart_tween()
	_model.transform = _rest.translated(Vector3(0.05, -lower_drop, 0.0)).rotated_local(Vector3.RIGHT, deg_to_rad(-30.0))
	_tween.tween_property(_model, "transform", _rest, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_lower(duration: float) -> void:
	# Out of the way while the melee weapon swings, then back up.
	_restart_tween()
	var lowered: Transform3D = _rest.translated(Vector3(0.05, -lower_drop, 0.0)).rotated_local(Vector3.RIGHT, deg_to_rad(-30.0))
	_tween.tween_property(_model, "transform", lowered, duration * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(duration * 0.45)
	_tween.tween_property(_model, "transform", _rest, duration * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	if _parts_tween:
		_parts_tween.kill()
	_reset_parts()
	_tween = create_tween()


## Puts every moving part back where it rests; extended by guns with other parts.
func _reset_parts() -> void:
	if _mag:
		_mag.position = _mag_rest
	if _slide:
		_slide.position = _slide_rest
