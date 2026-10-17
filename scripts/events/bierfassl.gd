class_name Bierfassl
extends Node3D
## "Bierfassl kert onzapft!" (section 8a): a beer barrel that broke loose up on the alm rolls down the
## slope, in through the beer garden's west gate and across the garden, flattening every enemy in its
## way, until it hits something or a player stops it by walking into it. Then hold E to tap it:
## Freibier, a random Schnaps that player does not have yet.

enum State { ROLLING, RESTING, TAPPED }

const RADIUS: float = 0.42
## Ground under the barrel: the walkable disc of the alm, the generated mountain beyond it.
const DISC_CENTER: Vector2 = Vector2(7.0, 2.0)
const DISC_RADIUS: float = 36.5
const DISC_HEIGHT: float = -0.3

var interact_repeat: float = 0.1
var _state: State = State.ROLLING
var _route: Array[Vector3] = []
var _direction: Vector3 = Vector3.RIGHT
var _speed: float = 0.0
var _bounce: float = 0.0
var _bounce_speed: float = 0.0
var _tap: float = 0.0
var _tap_since: float = INF
var _rest_left: float = 0.0
var _terrain: AlmTerrain
@onready var _roll: Node3D = $Roll
@onready var _marker: MapMarker = $Marker
@onready var _foam: CPUParticles3D = $Foam


func _ready() -> void:
	add_to_group("interactables")
	_terrain = get_tree().get_first_node_in_group("alm_terrain") as AlmTerrain


## Rolls along `route` (flat points; the height comes from the ground), then straight on along the
## last leg until it hits something.
func start(route: Array[Vector3]) -> void:
	_route = route.duplicate()
	global_position = _ground_point(_route.pop_front())
	if not _route.is_empty():
		_direction = _flat(_route[0] - global_position).normalized()
	_speed = Constants.FASSL_SPEED
	_state = State.ROLLING
	Events.event_announced.emit(tr("EVENT_FASSL_LOOSE"))


func is_rolling() -> bool:
	return _state == State.ROLLING


func is_resting() -> bool:
	return _state == State.RESTING


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return global_position


func get_interact_prompt(_player: Node3D) -> String:
	if _state != State.RESTING:
		return ""
	if _tap > 0.0:
		return tr("UI_TAPPING") % roundi(_tap / Constants.FASSL_TAP_TIME * 100.0)
	return tr("UI_TAP")


func interact(player: Node3D) -> void:
	if _state != State.RESTING:
		return
	_tap += interact_repeat
	_tap_since = 0.0
	if _tap >= Constants.FASSL_TAP_TIME:
		_freibier(player as Player)


func _physics_process(delta: float) -> void:
	match _state:
		State.ROLLING:
			_rolling(delta)
		State.RESTING:
			_tap_since += delta
			if _tap_since > interact_repeat * 3.0:
				_tap = 0.0
			_rest_left -= delta
			if _rest_left <= 0.0:
				queue_free()
		State.TAPPED:
			_rest_left -= delta
			if _rest_left <= 0.0:
				queue_free()


func _rolling(delta: float) -> void:
	if not _route.is_empty():
		var to: Vector3 = _route[0] - global_position
		to.y = 0.0
		if to.length() < 1.0:
			_route.pop_front()
		else:
			# Barrels do not turn on a coin: it curves into the new way.
			_direction = _direction.slerp(to.normalized(), minf(3.0 * delta, 1.0)).normalized()
	var step: Vector3 = _direction * _speed * delta
	# Hits a wall, a fence or a table: comes to a stop with a thud.
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ahead := PhysicsRayQueryParameters3D.create(global_position, global_position + _direction * (RADIUS + step.length() + 0.1), Constants.LAYER_WORLD)
	if not space.intersect_ray(ahead).is_empty():
		_come_to_rest()
		return
	# Or a player steps in its way and stops it.
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if _flat(player.global_position - global_position).length() < Constants.FASSL_STOP_REACH and absf(player.global_position.y - global_position.y) < 2.0:
			_come_to_rest()
			return
	var next: Vector3 = global_position + step
	var ground: float = _ground_height(next.x, next.z)
	# Little hops where the slope is bumpy.
	_bounce_speed -= 14.0 * delta
	_bounce = maxf(_bounce + _bounce_speed * delta, 0.0)
	if _bounce <= 0.0 and _speed > 3.0 and randf() < 0.02:
		_bounce_speed = randf_range(1.5, 3.0)
	global_position = Vector3(next.x, ground + RADIUS + _bounce, next.z)
	# Rolls about its own axis, which lies across the way it goes.
	look_at(global_position + _direction, Vector3.UP)
	_roll.rotate_object_local(Vector3.RIGHT, -_speed * delta / RADIUS)
	_flatten()


func _flatten() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var offset: Vector3 = enemy.global_position - global_position
		if _flat(offset).length() > Constants.FASSL_HIT_REACH or absf(offset.y + RADIUS) > 1.5:
			continue
		if enemy.data.is_boss:
			enemy.receive_hit(Constants.FASSL_BOSS_DAMAGE, false, false, null)
			enemy.apply_knockback(_direction * 8.0)
		else:
			enemy.receive_hit(100000, false, false, null)


func _come_to_rest() -> void:
	_state = State.RESTING
	_rest_left = Constants.FASSL_REST_TIME
	global_position.y = _ground_height(global_position.x, global_position.z) + RADIUS


func _freibier(player: Player) -> void:
	_state = State.TAPPED
	_rest_left = 4.0
	_foam.emitting = true
	if is_instance_valid(_marker):
		_marker.queue_free()
	var missing: Array[PerkData] = []
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		var bottle := node as PerkBottle
		if bottle and not player.perks.has(bottle.perk) and not missing.has(bottle.perk):
			missing.append(bottle.perk)
	if missing.is_empty():
		player.points.add(Constants.FASSL_POINTS_IF_FULL)
		Events.event_announced.emit(tr("EVENT_FASSL_POINTS") % Constants.FASSL_POINTS_IF_FULL)
		return
	var perk: PerkData = missing[randi() % missing.size()]
	player.perks.add(perk)
	Events.event_announced.emit(tr("EVENT_FASSL_FREIBIER") % [tr(perk.display_name), tr(perk.title)])


func _ground_point(flat: Vector3) -> Vector3:
	return Vector3(flat.x, _ground_height(flat.x, flat.z) + RADIUS, flat.z)


func _ground_height(x: float, z: float) -> float:
	if Vector2(x, z).distance_to(DISC_CENTER) < DISC_RADIUS or _terrain == null:
		return DISC_HEIGHT
	return maxf(_terrain.height_at(x, z), DISC_HEIGHT)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
