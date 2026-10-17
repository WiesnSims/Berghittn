class_name EventDirector
extends Node
## Decides when the events of section 8a happen. Die Resi comes every 3 to 5 waves from wave 3, but only
## while the Terrasse is open (she waits for it) and never on a boss wave. On top of that, now and then a
## random event: at most one a wave, never on a boss wave or a wave Resi comes, not the same one twice
## in a row when another could come.

@export var zones: ZoneMap
@export var resi_scene: PackedScene
@export var fassl_scene: PackedScene
## Where the actors appear; defaults to the parent.
@export var stage: Node3D

var _rng := RandomNumberGenerator.new()
var _next_resi: int = Constants.RESI_FIRST_WAVE
var _resi: Resi
var _fassl: Bierfassl
var _last_random: StringName = &""


func _ready() -> void:
	_rng.randomize()
	Events.wave_started.connect(_on_wave_started)


func _on_wave_started(wave: int, is_boss_wave: bool) -> void:
	if is_boss_wave:
		# The Krampus has the stage to himself; Resi comes the wave after.
		return
	if wave >= _next_resi and not is_instance_valid(_resi) and zones.is_unlocked(&"terrasse"):
		_next_resi = wave + _rng.randi_range(Constants.RESI_EVERY_MIN, Constants.RESI_EVERY_MAX)
		# A little into the wave, so she walks into the fight rather than an empty garden.
		get_tree().create_timer(Constants.RESI_DELAY).timeout.connect(send_resi)
		return
	if wave >= Constants.RANDOM_EVENT_FIRST_WAVE and _rng.randf() < Constants.RANDOM_EVENT_CHANCE:
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
	return _fassl


func _stage() -> Node:
	return stage if stage else get_parent()
