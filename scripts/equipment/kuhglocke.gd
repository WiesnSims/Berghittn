class_name Kuhglocke
extends Node3D
## A thrown Kuhglocke (section 6a): flies in an arc where the player looks, bounces off walls, and once
## it lies still it rings for KUHGLOCKE_RING_TIME: every enemy within KUHGLOCKE_LURE_RADIUS walks to it
## and stands around it instead of chasing players (group "lures", see Enemy). A ring pulses out on
## the floor with each swing and a comic "BIMM!" floats up until the M6 sounds. Then it goes quiet and
## sinks away.

const RADIUS: float = 0.2
const SINK_TIME: float = 0.6

var velocity: Vector3
var _thrower: Node3D
var _flying: bool = true
var _ring_left: float = 0.0
var _word_left: float = 0.0
var _swing: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var _model: Node3D = $Model
# Drawn big (a proper Almkuh bell), so it can be spotted across the garden.
@onready var _model_scale: Vector3 = _model.scale
@onready var _pulse: MeshInstance3D = $Pulse


func _ready() -> void:
	add_to_group("lures")
	_pulse.visible = false


func launch(from: Vector3, _direction: Vector3, thrower: Node3D) -> void:
	_thrower = thrower
	# Thrown from the hand where the player looks, pitch included, so it can go up onto the gallery
	# or far over the beer garden.
	var player := thrower as Player
	var aim: Vector3 = -player.weapons.global_basis.z if player else _direction
	global_position = player.weapons.global_position + aim * 0.5 if player else from
	velocity = (aim + Vector3.UP * 0.25).normalized() * Constants.KUHGLOCKE_THROW_SPEED


func is_ringing() -> bool:
	return _ring_left > 0.0


# Lure interface (see Enemy._find_lure).

func is_luring() -> bool:
	return is_ringing()


func lure_radius() -> float:
	return Constants.KUHGLOCKE_LURE_RADIUS


func pulls_inside() -> bool:
	return true


func lure_reached(_enemy: Node3D) -> void:
	pass


func _physics_process(delta: float) -> void:
	if _flying:
		_fly(delta)
		return
	if _ring_left > 0.0:
		_ring(delta)
		return
	_ring_left -= delta
	_model.scale = _model_scale * clampf(1.0 + (_ring_left / SINK_TIME), 0.0, 1.0)
	if _ring_left <= -SINK_TIME:
		queue_free()


func _fly(delta: float) -> void:
	velocity.y -= _gravity * delta
	var step: Vector3 = velocity * delta
	var exclude: Array[RID] = []
	if _thrower is CollisionObject3D:
		exclude.append((_thrower as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step + step.normalized() * RADIUS, Constants.LAYER_WORLD, exclude)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_model.rotate(Vector3.RIGHT, 12.0 * delta)
	if hit.is_empty():
		global_position += step
		return
	var normal: Vector3 = hit.normal
	if normal.y > 0.6:
		# Landed on something to stand on: comes to rest upright and starts ringing.
		global_position = hit.position + Vector3.UP * 0.01
		_flying = false
		_model.rotation = Vector3(0.0, randf() * TAU, 0.0)
		_ring_left = Constants.KUHGLOCKE_RING_TIME
		_word_left = 0.0
		return
	# A wall or a ceiling: it bounces off, losing most of its speed.
	global_position = hit.position + normal * (RADIUS + 0.02)
	velocity = velocity.bounce(normal) * Constants.KUHGLOCKE_BOUNCE_KEEP


func _ring(delta: float) -> void:
	_ring_left -= delta
	# Swings to and fro on its strap like a cow is shaking it.
	_swing += delta * TAU * 1.6
	_model.rotation.z = sin(_swing) * 0.35
	var pulse_phase: float = fmod(_swing / TAU, 1.0)
	_pulse.visible = true
	_pulse.scale = Vector3.ONE * lerpf(0.3, 3.0, pulse_phase)
	(_pulse.material_override as StandardMaterial3D).albedo_color.a = 0.45 * (1.0 - pulse_phase)
	_word_left -= delta
	if _word_left <= 0.0:
		_word_left = Constants.KUHGLOCKE_WORD_EVERY
		_float_word()
	if _ring_left <= 0.0:
		_pulse.visible = false
		_model.rotation.z = 0.0


func _float_word() -> void:
	var label := Label3D.new()
	label.text = tr("HIT_BIMM")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.001
	label.font_size = 56
	label.outline_size = 10
	label.modulate = Color(1.0, 0.9, 0.45)
	label.outline_modulate = Color(0.3, 0.18, 0.05)
	add_child(label)
	label.position = Vector3(randf_range(-0.2, 0.2), 0.6, randf_range(-0.2, 0.2))
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", 1.4, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
