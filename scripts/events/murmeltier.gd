class_name Murmeltier
extends Node3D
## Das Murmeltier (section 8a): pops out of the floor somewhere on the open part of the map, indoors too,
## stands up and screams, ducks away, and pops up again close by a few times. Hit it (shot or shovel)
## while it is up: points and a full refill of the gun in hand. Its scream is our own take on the
## meme (synthesised, tools/audio).
## Co-op (M7, CoopEvents): it pops on the host; a guest's copy pops when the host's does, and a guest's
## hit on it is the host's to allow (whoever was first gets the points and the full gun).

enum State { RISING, SCREAMING, DUCKING, HIDDEN, CAUGHT }

# Pivots of the animated parts in model space (see the model generator).
const NECK: Vector3 = Vector3(0.0, 0.4, 0.0)
const SHOULDER: Vector3 = Vector3(0.12, 0.34, -0.04)

## Co-op: a guest's copy of the host's Murmeltier.
var copy: bool = false
var _state: State = State.HIDDEN
# A copy: the host was asked to let our hit catch it.
var _asked: bool = false
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
	Coop.announce("EVENT_MURMEL_APPEARS")


# Co-op copy interface (see CoopEvents).

func start_copy() -> void:
	pass


func net_state() -> Array:
	return [int(_state)]


## A copy goes from state to state only on the host's word.
func net_apply(state: Array) -> void:
	var new_state: State = int(state[0]) as State
	if new_state == _state:
		return
	match new_state:
		State.RISING:
			_show_pop()
		State.SCREAMING:
			_enter(State.SCREAMING)
			_start_scream()
		State.DUCKING:
			_enter(State.DUCKING)
		State.HIDDEN:
			_set_up(false)
			_enter(State.HIDDEN)
		State.CAUGHT:
			_catch()


## Host: a guest's hit on their copy.
func net_request(what: StringName, peer: int) -> bool:
	if what != &"catch" or not is_up():
		return false
	_catch()
	Coop.announce("EVENT_MURMEL_CAUGHT_BY", [Coop.name_of(peer)], peer)
	return true


func net_granted(what: StringName, player: Player) -> void:
	if what == &"catch":
		_bag(player)


func is_up() -> bool:
	return _state == State.RISING or _state == State.SCREAMING


## Hurtbox receiver: any hit while it is up catches it.
func receive_hit(_amount: int, _is_headshot: bool, _is_melee: bool, source: Node3D) -> Hurtbox.Result:
	if not is_up():
		return Hurtbox.Result.IGNORED
	var player := source as Player
	if copy:
		# Ours if the host says we were first; the hit marker shows at once.
		if player and not _asked:
			_asked = true
			Coop.events.request(self, &"catch")
		return Hurtbox.Result.KILLED
	_catch()
	if player:
		_bag(player)
	if Coop.is_host():
		Coop.announce("EVENT_MURMEL_CAUGHT_BY", [Coop.name_of(Net.my_id())], Net.my_id())
	return Hurtbox.Result.KILLED


## What the catcher gets: points and the gun in hand full.
func _bag(player: Player) -> void:
	player.points.add(Constants.MURMEL_POINTS)
	player.weapons.refill_current()
	Events.event_announced.emit(tr("EVENT_MURMEL_CAUGHT") % Constants.MURMEL_POINTS)


## Bonked: it flies up spinning and is gone.
func _catch() -> void:
	_state = State.CAUGHT
	_set_up(false)
	if is_instance_valid(_scream):
		_scream.queue_free()
	Sound.play_at(&"murmeltier_hit", global_position + Vector3.UP * 0.4)
	if is_instance_valid(_marker):
		_marker.queue_free()
	# Bonk: it flies up spinning and is gone.
	var tween := create_tween().set_parallel()
	tween.tween_property(_model, "position:y", 1.6, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_model, "rotation:y", TAU * 3.0, 0.6)
	tween.tween_property(_model, "scale", Vector3.ONE * 0.05, 0.6).set_delay(0.2)
	# A copy goes when the host's does.
	if not copy:
		tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	match _state:
		State.RISING:
			_model.position.y = lerpf(-0.7, 0.0, minf(_time / Constants.MURMEL_RISE_TIME, 1.0))
			if _time >= Constants.MURMEL_RISE_TIME and not copy:
				_enter(State.SCREAMING)
				_start_scream()
		State.SCREAMING:
			var scream: float = clampf(_time / 0.25, 0.0, 1.0)
			_pose(scream)
			if _time >= Constants.MURMEL_SCREAM_TIME and not copy:
				_enter(State.DUCKING)
		State.DUCKING:
			_pose(1.0 - minf(_time / Constants.MURMEL_RISE_TIME, 1.0))
			_model.position.y = lerpf(0.0, -0.7, minf(_time / Constants.MURMEL_RISE_TIME, 1.0))
			if _time >= Constants.MURMEL_RISE_TIME and not copy:
				_set_up(false)
				_pops_left -= 1
				_enter(State.HIDDEN)
		State.HIDDEN:
			if copy:
				return
			if _pops_left <= 0 and _time > 0.5:
				Coop.announce("EVENT_MURMEL_GONE")
				queue_free()
			elif _pops_left > 0 and _time >= Constants.MURMEL_HIDE_TIME:
				var next: Vector3 = EventDirector.reachable_spot(get_world_3d(), global_position, Constants.MURMEL_HOP_MIN, Constants.MURMEL_HOP_MAX)
				var player: Node3D = EventDirector.random_player(get_tree())
				_pop_at(next if next != Vector3.INF else global_position, player.global_position if player else global_position + Vector3.FORWARD)


func _start_scream() -> void:
	_scream = Sound.attach(&"murmeltier_scream", self, 0.0, Constants.MURMEL_SCREAM_REACH)


func _pop_at(spot: Vector3, look_at_point: Vector3) -> void:
	global_position = spot
	var to := Vector3(look_at_point.x - spot.x, 0.0, look_at_point.z - spot.z)
	if to.length_squared() > 0.01:
		rotation.y = atan2(-to.x, -to.z)
	_show_pop()


## Out of its hole where it is now.
func _show_pop() -> void:
	_asked = false
	_model.position.y = -0.7
	_pose(0.0)
	_set_up(true)
	_enter(State.RISING)
	Sound.play_at(&"murmeltier_pop", global_position)


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
