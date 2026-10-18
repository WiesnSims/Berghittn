class_name Resi
extends CharacterBody3D
## Die Resi (section 8a): a lost Almkuh who wanders down into the beer garden for a while. Hold E to
## milk her (full heal and a free Brettljause helping). Once a player has come near her, her bell draws
## the enemies around her (group "lures", see Enemy), and if one reaches her she bolts. Until then they
## leave her alone, so she is not chased off before anyone got to her. The EventDirector sends her in.
## Co-op (M7, CoopEvents): she walks on the host; a guest's copy only shows her, and a guest's milking
## is the host's to allow (then the guest's own game heals them and serves the Jause).

enum State { ARRIVING, GRAZING, MILKED, LEAVING, BOLTING }

const JAUSE: Array[JauseData] = [preload("res://data/jause/speck.tres"), preload("res://data/jause/germknedl.tres"), preload("res://data/jause/kasnockn.tres")]
# Pivots of the animated parts in model space (see the model generator).
const HIP_HEIGHT: float = 0.78
const NECK: Vector3 = Vector3(0.0, 1.3, -0.72)
const STRAP: Vector3 = Vector3(0.0, 1.08, -0.86)
const TAIL: Vector3 = Vector3(0.0, 1.38, 0.86)

## Seconds between milking pulls while E is held (Interactor).
var interact_repeat: float = 0.1
## Co-op: a guest's copy of the host's Resi.
var copy: bool = false
# A copy: walking between spots on the host (so not grazing), where it was a frame ago, and whether
# the host has been asked to let us milk her.
var _copy_walking: bool = false
var _copy_last: Vector3
var _asked: bool = false
var _state: State = State.ARRIVING
var _route: Array[Vector3] = []
var _gate: Vector3
var _ramp: Vector3
var _hub: Vector3
var _spots: Array[Vector3] = []
var _stay_left: float = 0.0
var _graze_left: float = 0.0
var _wait_left: float = 0.0
var _leg_time: float = 0.0
var _milk: float = 0.0
var _milk_since: float = INF
# Whether a player has come near her yet; only from then on does her bell lure (and stays luring).
var _noticed: bool = false
var _walk_phase: float = 0.0
var _moving: float = 0.0
var _head_down: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()
# Her bell, ringing for as long as she is about, and seconds until she moos again.
var _bell: AudioStreamPlayer3D
var _moo_left: float = 0.0
var _rest: Dictionary = {}
@onready var _model: Node3D = $Model
@onready var _marker: MapMarker = $Marker


func _ready() -> void:
	add_to_group("lures")
	add_to_group("interactables")
	_rng.randomize()
	for child: Node in _model.get_children():
		_rest[child] = (child as Node3D).transform


## Walks in through the garden gate, down the ramp, and then between the spots, always by way of the
## hub so she never cuts across a table or up a staircase.
func start(gate: Vector3, ramp: Vector3, hub: Vector3, spots: Array[Vector3]) -> void:
	_gate = gate
	_ramp = ramp
	_hub = hub
	_spots = spots
	global_position = gate
	_route = [ramp, hub]
	_state = State.ARRIVING
	_stay_left = Constants.RESI_STAY_TIME
	Coop.announce("EVENT_RESI_ARRIVES")
	_bell = Sound.attach(&"resi_bell", self)
	_moo()


# Co-op copy interface (see CoopEvents).

func start_copy() -> void:
	_copy_last = global_position
	_bell = Sound.attach(&"resi_bell", self)
	_moo()


func net_state() -> Array:
	return [int(_state), not _route.is_empty()]


func net_apply(state: Array) -> void:
	var new_state: State = int(state[0]) as State
	_copy_walking = bool(state[1])
	if new_state == _state:
		return
	if new_state in [State.MILKED, State.LEAVING, State.BOLTING]:
		_drop_marker()
	if new_state == State.MILKED:
		_milk = 0.0
	_state = new_state


## Host: a guest milked their copy of her to the end.
func net_request(what: StringName, peer: int) -> bool:
	if what != &"milk" or not is_milkable():
		return false
	_milked()
	Coop.announce("EVENT_RESI_MILKED_BY", [Coop.name_of(peer)], peer)
	return true


func net_granted(what: StringName, player: Player) -> void:
	if what == &"milk":
		_treat(player)


func is_milkable() -> bool:
	return _state == State.ARRIVING or _state == State.GRAZING


# Lure interface (see Enemy._find_lure).

func is_luring() -> bool:
	return _noticed and is_milkable()


func lure_radius() -> float:
	return Constants.RESI_LURE_RADIUS


func pulls_inside() -> bool:
	return false


func lure_reached(_enemy: Node3D) -> void:
	if is_luring():
		_leave(true)


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return global_position + Vector3.UP * 0.8


func get_interact_prompt(_player: Node3D) -> String:
	if not is_milkable():
		return ""
	if _milk > 0.0:
		return tr("UI_MILKING") % roundi(_milk / Constants.RESI_MILK_TIME * 100.0)
	return tr("UI_MILK")


func interact(player: Node3D) -> void:
	if not is_milkable():
		return
	if _milk <= 0.0:
		Sound.play_at(&"milk", global_position + Vector3.UP * 0.5)
	_milk += interact_repeat
	_milk_since = 0.0
	if _milk >= Constants.RESI_MILK_TIME:
		if copy:
			if not _asked:
				_asked = true
				Coop.events.request(self, &"milk")
			return
		_reward(player as Player)


func _physics_process(delta: float) -> void:
	if copy:
		_copy_step(delta)
		return
	_milk_since += delta
	if not _noticed:
		_noticed = _player_near()
	_moo_left -= delta
	if _moo_left <= 0.0:
		_moo()
	# Let go of E and the pail tips over: start again.
	if _milk_since > interact_repeat * 3.0:
		_milk = 0.0
	match _state:
		State.ARRIVING, State.GRAZING:
			_stay_left -= delta
			if _stay_left <= 0.0:
				_leave(false)
			elif _milk > 0.0:
				_stand(delta)
			elif not _route.is_empty():
				_follow_route(Constants.RESI_WALK_SPEED, delta)
				if _route.is_empty():
					_state = State.GRAZING
					_graze_left = _rng.randf_range(2.0, 5.0)
			else:
				_stand(delta)
				_graze_left -= delta
				if _graze_left <= 0.0:
					_route = [_hub, _spots[_rng.randi() % _spots.size()]]
		State.MILKED:
			_stand(delta)
			_wait_left -= delta
			if _wait_left <= 0.0:
				_leave(false)
		State.LEAVING, State.BOLTING:
			_follow_route(Constants.RESI_BOLT_SPEED if _state == State.BOLTING else Constants.RESI_WALK_SPEED * 1.5, delta)
			if _route.is_empty():
				queue_free()
	_animate(delta)


func _reward(player: Player) -> void:
	_treat(player)
	_milked()
	if Coop.is_host():
		Coop.announce("EVENT_RESI_MILKED_BY", [Coop.name_of(Net.my_id())], Net.my_id())


## What the milker gets: full health and a helping of a Jause they can still eat more of.
func _treat(player: Player) -> void:
	player.health.heal_full()
	var hungry: Array[JauseData] = JAUSE.filter(func(j: JauseData) -> bool: return player.perks.jause_level(j) < j.max_level)
	var text: String = tr("EVENT_RESI_MILKED_FULL")
	if not hungry.is_empty():
		var jause: JauseData = hungry[_rng.randi() % hungry.size()]
		player.perks.eat(jause)
		text = tr("EVENT_RESI_MILKED") % tr(jause.display_name)
	Events.event_announced.emit(text)


func _milked() -> void:
	_moo()
	_milk = 0.0
	_state = State.MILKED
	_wait_left = 1.5
	_drop_marker()


func _leave(bolt: bool) -> void:
	_state = State.BOLTING if bolt else State.LEAVING
	_route = [_hub, _ramp, _gate, _gate + (_gate - _ramp).normalized() * 8.0]
	if bolt:
		Coop.announce("EVENT_RESI_BOLTED")
		_moo()
	_drop_marker()


func _moo() -> void:
	_moo_left = _rng.randf_range(Constants.RESI_MOO_MIN, Constants.RESI_MOO_MAX)
	Sound.play_at(&"resi_moo", global_position + Vector3.UP * 1.3)


func _player_near() -> bool:
	# Any player on their feet (in co-op the host's hikers too).
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if player != null and player.call("is_targetable") and player.global_position.distance_to(global_position) <= Constants.RESI_NOTICE_RADIUS:
			return true
	return false


## A copy: her walk and grazing from how the host moves her.
func _copy_step(delta: float) -> void:
	_milk_since += delta
	if _milk_since > interact_repeat * 3.0:
		_milk = 0.0
		_asked = false
	_moo_left -= delta
	if _moo_left <= 0.0:
		_moo()
	var moved: Vector3 = global_position - _copy_last
	moved.y = 0.0
	_copy_last = global_position
	var speed: float = moved.length() / maxf(delta, 0.001)
	_moving = move_toward(_moving, 1.0 if speed > 0.2 else 0.0, delta * 4.0)
	_walk_phase += delta * speed * 4.5
	_animate(delta)


func _drop_marker() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()


func _follow_route(speed: float, delta: float) -> void:
	var to: Vector3 = _route[0] - global_position
	to.y = 0.0
	_leg_time += delta
	# Close enough, or shoved off her way by the crowd for too long: on to the next point.
	if to.length() < 0.4 or _leg_time > 12.0:
		_route.pop_front()
		_leg_time = 0.0
		return
	var direction: Vector3 = to.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_fall(delta)
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(4.0 * delta, 1.0))
	_moving = move_toward(_moving, 1.0, delta * 4.0)
	_walk_phase += delta * speed * 4.5


func _stand(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_fall(delta)
	move_and_slide()
	_moving = move_toward(_moving, 0.0, delta * 4.0)


func _fall(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta


func _animate(delta: float) -> void:
	var walking: bool = _copy_walking if copy else not _route.is_empty()
	var grazing: bool = _state == State.GRAZING and not walking and _milk <= 0.0
	_head_down = move_toward(_head_down, 1.0 if grazing else 0.0, delta * 1.5)
	var t: float = Time.get_ticks_msec() / 1000.0
	var swing: float = sin(_walk_phase) * 0.45 * _moving
	for child: Node3D in _rest:
		var rest: Transform3D = _rest[child]
		var name: String = child.name
		if name.begins_with("Leg"):
			var front: bool = name.begins_with("LegF")
			var left: bool = name.substr(4, 1) == "L"
			var angle: float = swing if front == left else -swing
			_turn(child, rest, Vector3(rest.origin.x, HIP_HEIGHT, rest.origin.z), Vector3.RIGHT, angle)
		elif name.begins_with("Head"):
			_turn(child, rest, NECK, Vector3.RIGHT, -0.75 * _head_down + sin(t * 2.0) * 0.05)
		elif name.begins_with("Bell"):
			_turn(child, rest, STRAP, Vector3.RIGHT, sin(_walk_phase * 2.0) * 0.35 * _moving + sin(t * 3.0) * 0.06)
		elif name.begins_with("Tail"):
			_turn(child, rest, TAIL, Vector3.FORWARD, sin(t * 2.6) * 0.35)


static func _turn(node: Node3D, rest: Transform3D, pivot: Vector3, axis: Vector3, angle: float) -> void:
	node.transform = Transform3D(Basis(axis, angle), pivot) * Transform3D(Basis.IDENTITY, -pivot) * rest
