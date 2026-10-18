class_name Kuhfladen
extends Node3D
## A Kuhfladen-Mine (section 6a): placed on the floor a step ahead of the player. Every enemy that
## steps in it takes KUHFLADEN_DAMAGE and is slowed for KUHFLADEN_SLOW_TIME (once per enemy, with a
## squelch); after KUHFLADEN_CATCHES of them, or KUHFLADEN_LIFETIME, it is trodden flat and gone.
## At most KUHFLADEN_MAX_ACTIVE lie about at once: placing another removes the oldest. Flies circle it.

const GROUP: String = "kuhfladen"
const FADE_TIME: float = 0.6

## Co-op (M7): another player's, as we see it. It is trodden flat like theirs, but hurts nobody here:
## their own game deals the damage.
var harmless: bool = false

var _thrower: Node3D
var _left: float = Constants.KUHFLADEN_LIFETIME
var _catches: int = 0
var _caught: Dictionary = {}
var _time: float = 0.0
@onready var _model: Node3D = $Model
@onready var _flies: Array[Node] = $Flies.get_children()


func _ready() -> void:
	# The oldest one goes once too many lie about.
	var placed: Array[Node] = get_tree().get_nodes_in_group(GROUP)
	if placed.size() >= Constants.KUHFLADEN_MAX_ACTIVE:
		placed[0].queue_free()
	add_to_group(GROUP)


## Placed, not thrown: on the floor a step ahead, or at the player's feet if a wall is in the way.
func launch(from: Vector3, direction: Vector3, thrower: Node3D) -> void:
	_thrower = thrower
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if thrower is CollisionObject3D:
		exclude.append((thrower as CollisionObject3D).get_rid())
	var spot: Vector3 = from + direction * Constants.KUHFLADEN_PLACE_DISTANCE
	var ahead := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.3, spot + Vector3.UP * 0.3, Constants.LAYER_WORLD, exclude)
	if not space.intersect_ray(ahead).is_empty():
		spot = from
	var down := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.6, spot + Vector3.DOWN * 3.0, Constants.LAYER_WORLD, exclude)
	var floor_hit: Dictionary = space.intersect_ray(down)
	global_position = floor_hit.position if not floor_hit.is_empty() else spot
	rotation.y = randf() * TAU
	Sound.play_at(&"kuhfladen_splat", global_position)


func catches() -> int:
	return _catches


func _physics_process(delta: float) -> void:
	_time += delta
	_left -= delta
	for i: int in _flies.size():
		var fly := _flies[i] as Node3D
		var phase: float = _time * (2.5 + i * 0.7) + i * 2.1
		fly.position = Vector3(cos(phase) * 0.35, 0.35 + sin(phase * 1.7) * 0.12, sin(phase) * 0.35)
	if _left <= 0.0:
		_model.scale = Vector3(1.0, maxf(1.0 + _left / FADE_TIME, 0.01), 1.0)
		if _left <= -FADE_TIME:
			queue_free()
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive() or _caught.has(enemy.get_instance_id()):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		if Vector2(offset.x, offset.z).length() > Constants.KUHFLADEN_RADIUS or absf(offset.y) > 0.8:
			continue
		_caught[enemy.get_instance_id()] = true
		_catches += 1
		if not harmless:
			enemy.apply_slow(Constants.KUHFLADEN_SLOW_FACTOR, Constants.KUHFLADEN_SLOW_TIME)
			enemy.receive_hit(Constants.KUHFLADEN_DAMAGE, false, false, _thrower)
		Sound.play_at(&"kuhfladen_squelch", global_position)
		if _catches >= Constants.KUHFLADEN_CATCHES:
			_left = 0.0
			break
