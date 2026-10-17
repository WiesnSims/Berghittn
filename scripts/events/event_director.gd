class_name EventDirector
extends Node
## Decides when the events of section 8a happen. Die Resi comes every 3 to 5 waves from wave 3, but only
## while the Terrasse is open (she waits for it) and never on a boss wave. The random events come later.

@export var zones: ZoneMap
@export var resi_scene: PackedScene
## Where the actors appear; defaults to the parent.
@export var stage: Node3D

var _rng := RandomNumberGenerator.new()
var _next_resi: int = Constants.RESI_FIRST_WAVE
var _resi: Resi


func _ready() -> void:
	_rng.randomize()
	Events.wave_started.connect(_on_wave_started)


func _on_wave_started(wave: int, is_boss_wave: bool) -> void:
	# The Krampus has the stage to himself; she comes the wave after.
	if wave >= _next_resi and not is_boss_wave and not is_instance_valid(_resi) and zones.is_unlocked(&"terrasse"):
		_next_resi = wave + _rng.randi_range(Constants.RESI_EVERY_MIN, Constants.RESI_EVERY_MAX)
		# A little into the wave, so she walks into the fight rather than an empty garden.
		get_tree().create_timer(Constants.RESI_DELAY).timeout.connect(send_resi)


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
	(stage if stage else get_parent()).add_child(_resi)
	_resi.start((spots.get_node("Gate") as Node3D).global_position, (spots.get_node("Ramp") as Node3D).global_position,
		(spots.get_node("Hub") as Node3D).global_position, wander)
	return _resi
