class_name EventDirector
extends Node
## Decides when the events of section 8a happen. Die Resi comes every 3 to 5 waves from wave 3, but only
## while the Terrasse is open (she waits for it) and never on a boss wave. On top of that, now and then a
## random event: at most one a wave, never on a boss wave or a wave Resi comes, not the same one twice
## in a row when another could come.
## Co-op (M7): only the host's director sends events; CoopEvents gives every guest a copy of each.

@export var zones: ZoneMap
@export var resi_scene: PackedScene
@export var fassl_scene: PackedScene
@export var murmel_scene: PackedScene
@export var guest_scene: PackedScene
## Where the actors appear; defaults to the parent.
@export var stage: Node3D
## Off: no random events are rolled (Resi still comes). For tests that start events themselves.
@export var random_events: bool = true

var _rng := RandomNumberGenerator.new()
var _next_resi: int = Constants.RESI_FIRST_WAVE
var _resi: Resi
var _fassl: Bierfassl
var _murmel: Murmeltier
var _guest: TouristGuest
var _last_random: StringName = &""


func _ready() -> void:
	_rng.randomize()
	Events.wave_started.connect(_on_wave_started)


func _on_wave_started(wave: int, is_boss_wave: bool) -> void:
	if is_boss_wave or Coop.is_guest():
		# The Krampus has the stage to himself; Resi comes the wave after.
		return
	if wave >= _next_resi and not is_instance_valid(_resi) and zones.is_unlocked(&"terrasse"):
		_next_resi = wave + _rng.randi_range(Constants.RESI_EVERY_MIN, Constants.RESI_EVERY_MAX)
		# A little into the wave, so she walks into the fight rather than an empty garden.
		get_tree().create_timer(Constants.RESI_DELAY).timeout.connect(send_resi)
		return
	if random_events and wave >= Constants.RANDOM_EVENT_FIRST_WAVE and _rng.randf() < Constants.RANDOM_EVENT_CHANCE:
		var event: StringName = pick_random_event()
		if event != &"":
			var delay: float = _rng.randf_range(Constants.RANDOM_EVENT_DELAY_MIN, Constants.RANDOM_EVENT_DELAY_MAX)
			get_tree().create_timer(delay).timeout.connect(start_event.bind(event))


## The random events that could happen right now, minus the last one if there is a choice.
func available_random_events() -> Array[StringName]:
	var events: Array[StringName] = []
	# The barrel ends up in the beer garden: only worth it with the Terrasse open.
	if zones.is_unlocked(&"terrasse") and not is_instance_valid(_fassl):
		events.append(&"fassl")
	# Pops up anywhere players can walk to.
	if not is_instance_valid(_murmel):
		events.append(&"murmeltier")
	# He gets off at the Seilbahn and must be able to walk to the Stube through open zones.
	if not is_instance_valid(_guest) and zones.is_unlocked(&"seilbahn") and _guest_route_open():
		events.append(&"guest")
	if events.size() > 1:
		events.erase(_last_random)
	return events


func pick_random_event() -> StringName:
	var events: Array[StringName] = available_random_events()
	return events[_rng.randi() % events.size()] if not events.is_empty() else &""


func start_event(event: StringName) -> Node:
	_last_random = event
	match event:
		&"fassl":
			return send_fassl()
		&"murmeltier":
			return send_murmeltier()
		&"guest":
			return send_guest()
	return null


## Sends die Resi in now (also used by tests). Her way in is the ResiSpots markers in the Terrasse.
func send_resi() -> Resi:
	if is_instance_valid(_resi):
		return _resi
	var spots: Node3D = get_tree().get_first_node_in_group("resi_spots") as Node3D
	if spots == null:
		return null
	var wander: Array[Vector3] = []
	for child: Node in spots.get_children():
		if child.name.begins_with("Spot"):
			wander.append((child as Node3D).global_position)
	_resi = resi_scene.instantiate() as Resi
	_stage().add_child(_resi)
	_resi.start((spots.get_node("Gate") as Node3D).global_position, (spots.get_node("Ramp") as Node3D).global_position,
		(spots.get_node("Hub") as Node3D).global_position, wander)
	_share(_resi, &"resi")
	Sound.play(&"event_call")
	return _resi


## Lets the Bierfassl loose (also used by tests). Its way down is the FasslRoute markers, in order.
func send_fassl() -> Bierfassl:
	if is_instance_valid(_fassl):
		return _fassl
	var route_node: Node3D = get_tree().get_first_node_in_group("fassl_route") as Node3D
	if route_node == null:
		return null
	var route: Array[Vector3] = []
	for child: Node in route_node.get_children():
		route.append((child as Node3D).global_position)
	_fassl = fassl_scene.instantiate() as Bierfassl
	_stage().add_child(_fassl)
	_fassl.start(route)
	_share(_fassl, &"fassl")
	Sound.play(&"event_call")
	return _fassl


## Sends the Murmeltier to a spot near a player (also used by tests).
func send_murmeltier() -> Murmeltier:
	if is_instance_valid(_murmel):
		return _murmel
	var player: Node3D = random_player(get_tree())
	if player == null:
		return null
	var spot: Vector3 = reachable_spot(player.get_world_3d(), player.global_position, Constants.MURMEL_FIRST_MIN, Constants.MURMEL_FIRST_MAX)
	if spot == Vector3.INF:
		return null
	_murmel = murmel_scene.instantiate() as Murmeltier
	_stage().add_child(_murmel)
	_murmel.start(spot, player.global_position)
	_share(_murmel, &"murmeltier")
	Sound.play(&"event_call")
	return _murmel


## Sends the Deitscha Tourist off the gondola (also used by tests).
func send_guest() -> TouristGuest:
	if is_instance_valid(_guest):
		return _guest
	var arrival := get_tree().get_first_node_in_group("guest_arrival") as Node3D
	var goal := get_tree().get_first_node_in_group("guest_goal") as Node3D
	if arrival == null or goal == null:
		return null
	_guest = guest_scene.instantiate() as TouristGuest
	_stage().add_child(_guest)
	_guest.start(arrival.global_position, goal.global_position, guest_way(arrival.global_position, goal.global_position))
	_share(_guest, &"guest")
	Sound.play(&"event_call")
	return _guest


## The Tourist's long way round the door ring (Seilbahn, Schuppen, Terrasse, Stube): the GuestWay
## markers in name order, or none (the direct way) while a zone on it is still shut.
func guest_way(from: Vector3, to: Vector3) -> Array[Vector3]:
	var markers: Array[Node] = get_tree().get_nodes_in_group("guest_waypoints")
	markers.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	var way: Array[Vector3] = []
	for marker: Node in markers:
		way.append((marker as Node3D).global_position)
	var legs: Array[Vector3] = [from]
	legs.append_array(way)
	legs.append(to)
	var world: World3D = get_viewport().world_3d
	for i: int in legs.size() - 1:
		if not walkable(world, legs[i], legs[i + 1]):
			return []
	return way


func _guest_route_open() -> bool:
	var arrival := get_tree().get_first_node_in_group("guest_arrival") as Node3D
	var goal := get_tree().get_first_node_in_group("guest_goal") as Node3D
	if arrival == null or goal == null:
		return false
	return walkable(arrival.get_world_3d(), arrival.global_position, goal.global_position)


## True if a player could walk from `from` to `to`: a navmesh path without windows or player blockers.
static func walkable(world: World3D, from: Vector3, to: Vector3) -> bool:
	var query := NavigationPathQueryParameters3D.new()
	query.map = world.navigation_map
	query.start_position = from
	query.target_position = to
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(query, result)
	var path: PackedVector3Array = result.path
	var end: Vector3 = NavigationServer3D.map_get_closest_point(world.navigation_map, to)
	if path.is_empty() or path[path.size() - 1].distance_to(end) > 0.5:
		return false
	return not result.path_types.has(NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK) and not _crosses_blocker(world, path)


## A random navmesh point `min_distance` to `max_distance` from `from` that can be walked to without
## climbing through a window or passing a player blocker (the beer garden gates are open to enemies
## only): the open part of the map, never outside a closed zone or on a roof.
## Vector3.INF if none turns up.
static func reachable_spot(world: World3D, from: Vector3, min_distance: float, max_distance: float) -> Vector3:
	var map: RID = world.navigation_map
	var query := NavigationPathQueryParameters3D.new()
	query.map = map
	query.start_position = from
	var result := NavigationPathQueryResult3D.new()
	for i: int in 400:
		var spot: Vector3 = NavigationServer3D.map_get_random_point(map, 1, true)
		var distance: float = spot.distance_to(from)
		if distance < min_distance or distance > max_distance:
			continue
		query.target_position = spot
		NavigationServer3D.query_path(query, result)
		var path: PackedVector3Array = result.path
		if path.is_empty() or path[path.size() - 1].distance_to(spot) > 0.3:
			continue
		if result.path_types.has(NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK) or _crosses_blocker(world, path):
			continue
		return spot
	return Vector3.INF


static func _crosses_blocker(world: World3D, path: PackedVector3Array) -> bool:
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	for i: int in range(1, path.size()):
		var up := Vector3.UP * 1.0
		var leg := PhysicsRayQueryParameters3D.create(path[i - 1] + up, path[i] + up, Constants.LAYER_PLAYER_BLOCKER)
		if not space.intersect_ray(leg).is_empty():
			return true
	return false


## A player still on their feet (in co-op any of them, as the host sees them: our Player or a
## hiker), or null.
static func random_player(tree: SceneTree) -> Node3D:
	var up: Array[Node3D] = []
	for node: Node in tree.get_nodes_in_group("player"):
		if node.has_method("is_targetable") and node.call("is_targetable"):
			up.append(node as Node3D)
	return up.pick_random() if not up.is_empty() else tree.get_first_node_in_group("player") as Node3D


## Where the actors appear.
func stage_node() -> Node:
	return _stage()


func _share(actor: Node3D, kind: StringName) -> void:
	if Coop.is_host() and Coop.events:
		Coop.events.share(actor, kind)


func _stage() -> Node:
	return stage if stage else get_parent()
