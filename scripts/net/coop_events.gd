class_name CoopEvents
extends Node
## The events of section 8a in a co-op match (M7 part 3). The host's EventDirector sends them in and
## the host runs them as in solo (enemies are lured, flattened and go for the Tourist on the host);
## every guest gets a copy of each actor (its `copy` set) that the host's snapshots move and whose
## state they set, and the copy only shows it. What a guest does to one (milking die Resi, tapping
## the Bierfassl, hitting the Murmeltier) is a request: the host's actor decides, and the reward
## (health and a Jause, a Schnaps, points, the Eisstöcke) is paid in the guest's own game.
## Main creates it as /root/Main/CoopEvents on every peer.
##
## Each actor has: `copy`, start_copy() (a copy arrives), net_state() -> Array (host) and
## net_apply(state) (copy), net_request(what) -> bool (host: a guest asks) and
## net_granted(what, player) (the asker gets their reward).

## A copy that jumps further than this between two snapshots (the Murmeltier popping up elsewhere)
## is put there, not slid there (m).
const SNAP_DISTANCE: float = 3.0

var _director: EventDirector
## Net id -> the host's actor or a guest's copy.
var _actors: Dictionary = {}
var _buffers: Dictionary = {}
var _next_id: int = 1
var _send_left: float = 0.0


func setup(director: EventDirector) -> void:
	_director = director
	Coop.events = self


func _exit_tree() -> void:
	if Coop.events == self:
		Coop.events = null


## The id host and guests know `actor` by (0: none).
static func id_of(actor: Node) -> int:
	return int(actor.get_meta(&"net_id", 0))


## Host: the director sent `actor` (of `kind`: resi, fassl, murmeltier, guest) in; the guests get it too.
func share(actor: Node3D, kind: StringName) -> void:
	var id: int = _next_id
	_next_id += 1
	actor.set_meta(&"net_id", id)
	_actors[id] = actor
	actor.tree_exiting.connect(_on_actor_gone.bind(id))
	_spawned.rpc(id, kind, actor.global_position, actor.rotation.y, actor.call("net_state"))


## Guest: we did to the copy what the host must decide (`what`: milk, tap, catch).
func request(copy: Node, what: StringName) -> void:
	_ask.rpc_id(1, id_of(copy), what)


## Host: `peer` gets the reward of `actor` (the Tourist hands his Eisstöcke to whoever is nearest).
func grant(actor: Node, peer: int, what: StringName) -> void:
	if peer == Net.my_id():
		actor.call("net_granted", what, Coop.node_of(peer))
	else:
		_granted.rpc_id(peer, id_of(actor), what)


## Host: a banner for the guests too (Coop.announce), translated on each screen.
func say(key: String, args: Array, except_peer: int = 0) -> void:
	_said.rpc(key, args, except_peer)


func _physics_process(delta: float) -> void:
	if not Net.in_match():
		return
	if Net.is_host():
		_send_left -= delta
		if _send_left <= 0.0 and not _actors.is_empty():
			_send_left = maxf(_send_left + Constants.NET_POSE_INTERVAL, 0.0)
			var list: Array = []
			for id: int in _actors:
				var actor: Node3D = _actors[id]
				list.append([id, actor.global_position, actor.rotation.y, actor.call("net_state")])
			_snapshot.rpc(Time.get_ticks_msec(), list)
		return
	var now: int = Time.get_ticks_msec()
	for id: int in _buffers:
		var buffer: PoseBuffer = _buffers[id]
		var copy: Node3D = _actors.get(id)
		if buffer.is_empty() or not is_instance_valid(copy):
			continue
		var pose: Array = buffer.sample(now)
		copy.global_position = pose[0]
		copy.rotation.y = pose[1]


func _on_actor_gone(id: int) -> void:
	_actors.erase(id)
	if Net.in_match():
		_gone.rpc(id)


func _scene(kind: StringName) -> PackedScene:
	match kind:
		&"resi":
			return _director.resi_scene
		&"fassl":
			return _director.fassl_scene
		&"murmeltier":
			return _director.murmel_scene
		&"guest":
			return _director.guest_scene
	return null


@rpc("authority", "call_remote", "reliable")
func _spawned(id: int, kind: StringName, at: Vector3, yaw: float, state: Array) -> void:
	var scene: PackedScene = _scene(kind)
	if scene == null or _actors.has(id):
		return
	var copy := scene.instantiate() as Node3D
	copy.set("copy", true)
	copy.set_meta(&"net_id", id)
	_director.stage_node().add_child(copy)
	copy.global_position = at
	copy.rotation.y = yaw
	_actors[id] = copy
	_buffers[id] = PoseBuffer.new()
	copy.call("start_copy")
	copy.call("net_apply", state)
	Sound.play(&"event_call")


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(sent: int, list: Array) -> void:
	var now: int = Time.get_ticks_msec()
	for entry: Array in list:
		if entry.size() != 4:
			continue
		var id: int = entry[0]
		var copy: Node3D = _actors.get(id)
		var buffer: PoseBuffer = _buffers.get(id)
		if not is_instance_valid(copy) or buffer == null:
			continue
		var at: Vector3 = entry[1]
		if copy.global_position.distance_to(at) > SNAP_DISTANCE:
			buffer.clear()
			copy.global_position = at
		buffer.add(now, sent, at, entry[2])
		copy.call("net_apply", entry[3])


@rpc("authority", "call_remote", "reliable")
func _gone(id: int) -> void:
	var copy: Node = _actors.get(id)
	_actors.erase(id)
	_buffers.erase(id)
	if is_instance_valid(copy):
		copy.queue_free()


@rpc("any_peer", "call_remote", "reliable")
func _ask(id: int, what: StringName) -> void:
	var actor: Node = _actors.get(id)
	if Net.is_host() and is_instance_valid(actor) and actor.call("net_request", what, multiplayer.get_remote_sender_id()):
		_granted.rpc_id(multiplayer.get_remote_sender_id(), id, what)


@rpc("authority", "call_remote", "reliable")
func _granted(id: int, what: StringName) -> void:
	var copy: Node = _actors.get(id)
	var player := Coop.node_of(Net.my_id()) as Player
	if is_instance_valid(copy) and player:
		copy.call("net_granted", what, player)


@rpc("authority", "call_remote", "reliable")
func _said(key: String, args: Array, except_peer: int) -> void:
	if except_peer == Net.my_id():
		return
	var text: String = tr(key)
	Events.event_announced.emit(text % args if not args.is_empty() else text)
