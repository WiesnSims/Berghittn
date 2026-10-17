class_name Murmeltier
extends Node3D
## Das Murmeltier (section 8a): pops out of the floor somewhere on the open part of the map, indoors too,
## stands up and screams, ducks away, and pops up again close by a few times. Hit it (shot or shovel)
## while it is up: points and a full refill of the gun in hand. Its scream is our own take on the
## meme (synthesised, tools/audio).

enum State { RISING, SCREAMING, DUCKING, HIDDEN, CAUGHT }

# Pivots of the animated parts in model space (see the model generator).
const NECK: Vector3 = Vector3(0.0, 0.4, 0.0)
const SHOULDER: Vector3 = Vector3(0.12, 0.34, -0.04)

var _state: State = State.HIDDEN
var _time: float = 0.0
var _pops_left: int = 0
var _rest: Dictionary = {}
# The scream of the current pop, cut short when it is caught.
var _scream: AudioStreamPlayer3D
@onready var _model: Node3D = $Model
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hole: Node3D = $Hole
@onready var _marker: MapMarker = $Marker


func _ready() -> void:
	for child: Node in _model.get_children():
		_rest[child] = (child as Node3D).transform
	_set_up(false)


## Starts its round of pops at `spot`, facing `look_at_point`.
func start(spot: Vector3, look_at_point: Vector3) -> void:
	_pops_left = Constants.MURMEL_POPS
	_pop_at(spot, look_at_point)
	Events.event_announced.emit(tr("EVENT_MURMEL_APPEARS"))


func is_up() -> bool:
	return _state == State.RISING or _state == State.SCREAMING


## Hurtbox receiver: any hit while it is up catches it.
func receive_hit(_amount: int, _is_headshot: bool, _is_melee: bool, source: Node3D) -> Hurtbox.Result:
	if not is_up():
		return Hurtbox.Result.IGNORED
	_state = State.CAUGHT
	_set_up(false)
	if is_instance_valid(_scream):
		_scream.queue_free()
	Sound.play_at(&"murmeltier_hit", global_position + Vector3.UP * 0.4)
	var player := source as Player
	if player:
		player.points.add(Constants.MURMEL_POINTS)
		player.weapons.refill_current()
	Events.event_announced.emit(tr("EVENT_MURMEL_CAUGHT") % Constants.MURMEL_POINTS)
	if is_instance_valid(_marker):
		_marker.queue_free()
	# Bonk: it flies up spinning and is gone.
	var tween := create_tween().set_parallel()
	tween.tween_property(_model, "position:y", 1.6, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_model, "rotation:y", TAU * 3.0, 0.6)
	tween.tween_property(_model, "scale", Vector3.ONE * 0.05, 0.6).set_delay(0.2)
	tween.chain().tween_callback(queue_free)
	return Hurtbox.Result.KILLED


func _process(delta: float) -> void:
	_time += delta
	match _state:
		State.RISING:
			_model.position.y = lerpf(-0.7, 0.0, minf(_time / Constants.MURMEL_RISE_TIME, 1.0))
			if _time >= Constants.MURMEL_RISE_TIME:
				_enter(State.SCREAMING)
				_scream = Sound.attach(&"murmeltier_scream", self)
		State.SCREAMING:
			var scream: float = clampf(_time / 0.25, 0.0, 1.0)
			_pose(scream)
			if _time >= Constants.MURMEL_SCREAM_TIME:
				_enter(State.DUCKING)
		State.DUCKING:
			_pose(1.0 - minf(_time / Constants.MURMEL_RISE_TIME, 1.0))
			_model.position.y = lerpf(0.0, -0.7, minf(_time / Constants.MURMEL_RISE_TIME, 1.0))
			if _time >= Constants.MURMEL_RISE_TIME:
				_set_up(false)
				_pops_left -= 1
				_enter(State.HIDDEN)
		State.HIDDEN:
			if _pops_left <= 0 and _time > 0.5:
				Events.event_announced.emit(tr("EVENT_MURMEL_GONE"))
				queue_free()
			elif _pops_left > 0 and _time >= Constants.MURMEL_HIDE_TIME:
				var next: Vector3 = EventDirector.reachable_spot(get_world_3d(), global_position, Constants.MURMEL_HOP_MIN, Constants.MURMEL_HOP_MAX)
				var player := get_tree().get_first_node_in_group("player") as Node3D
				_pop_at(next if next != Vector3.INF else global_position, player.global_position if player else global_position + Vector3.FORWARD)


func _pop_at(spot: Vector3, look_at_point: Vector3) -> void:
	global_position = spot
	var to := Vector3(look_at_point.x - spot.x, 0.0, look_at_point.z - spot.z)
	if to.length_squared() > 0.01:
		rotation.y = atan2(-to.x, -to.z)
	_model.position.y = -0.7
	_pose(0.0)
	_set_up(true)
	_enter(State.RISING)
	Sound.play_at(&"murmeltier_pop", spot)


func _enter(state: State) -> void:
	_state = state
	_time = 0.0


func _set_up(up: bool) -> void:
	_hurtbox.collision_layer = Constants.LAYER_HITBOX if up else 0
	_model.visible = up or _state == State.CAUGHT
	_hole.visible = _state != State.CAUGHT


## 0 = standing, 1 = full scream: head thrown back, arms up, mouth wide.
func _pose(scream: float) -> void:
	for child: Node3D in _rest:
		var rest: Transform3D = _rest[child]
		var name: String = child.name
		if name.begins_with("Head"):
			var t := Transform3D(Basis(Vector3.RIGHT, 0.45 * scream), NECK) * Transform3D(Basis.IDENTITY, -NECK) * rest
			if name == "HeadMouth":
				t = t * Transform3D(Basis.from_scale(Vector3(1.0, 1.0 + 1.6 * scream, 1.0)), Vector3.ZERO)
			child.transform = t
		elif name.begins_with("Arm"):
			var side: float = -1.0 if name.ends_with("L") else 1.0
			var pivot := Vector3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z)
			child.transform = Transform3D(Basis(Vector3.FORWARD, -side * 2.2 * scream), pivot) * Transform3D(Basis.IDENTITY, -pivot) * rest
