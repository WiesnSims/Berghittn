class_name TouristGuest
extends CharacterBody3D
## "Deitscha Tourist" (section 8a): a lost, living German tourist gets off the gondola at the Seilbahn
## and heads for the Stube on the navmesh. He only walks while a player is near him (he would never find
## the way alone), and enemies go for him like for a player (group "escorts", see Enemy). Escorted there
## alive, he hands the nearest player the Eisstöcke, the only ones in the game.

enum State { WAITING, WALKING, ARRIVED, DEAD, GONE }

const EISSTOCK: EquipmentData = preload("res://data/equipment/eisstock.tres")
const HIP: float = 0.86
const SHOULDER: float = 1.4

var health: int = 0
var _state: State = State.WAITING
var _goal: Vector3
var _time_left: float = 0.0
var _leave_left: float = 0.0
var _walk_phase: float = 0.0
var _moving: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rest: Dictionary = {}
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: Node3D = $Model
@onready var _bar: Label3D = $HealthBar
@onready var _bubble: Label3D = $Bubble
@onready var _marker: MapMarker = $Marker


func _ready() -> void:
	add_to_group("escorts")
	for child: Node in _model.get_children():
		_rest[child] = (child as Node3D).transform


func start(at: Vector3, goal: Vector3) -> void:
	global_position = at
	_goal = goal
	_agent.target_position = goal
	health = Constants.GUEST_HEALTH
	_time_left = Constants.GUEST_TIME
	_state = State.WAITING
	_update_bar()
	Events.event_announced.emit(tr("EVENT_GUEST_ARRIVES"))


func is_alive() -> bool:
	return _state == State.WAITING or _state == State.WALKING


func has_arrived() -> bool:
	return _state == State.ARRIVED


# Target interface (what enemies need from whatever they chase, see Enemy._nearest_target).

func is_targetable() -> bool:
	return is_alive()


func take_damage(amount: int, _attacker: Node3D = null) -> void:
	if not is_alive():
		return
	health -= amount
	_update_bar()
	_bubble.text = tr("GUEST_OUCH")
	_bubble.visible = true
	if health <= 0:
		_die()


func _physics_process(delta: float) -> void:
	match _state:
		State.WAITING, State.WALKING:
			_time_left -= delta
			if _time_left <= 0.0:
				_give_up()
				return
			var escorted: bool = _nearest_player(Constants.GUEST_ESCORT_RANGE) != null
			_state = State.WALKING if escorted else State.WAITING
			if _flat(_goal - global_position).length() < Constants.GUEST_ARRIVE_REACH:
				_arrive()
				return
			if escorted:
				_walk(delta)
			else:
				_stand(delta)
				_bubble.text = tr("GUEST_LOST")
				_bubble.visible = true
		State.ARRIVED, State.DEAD:
			_stand(delta)
			_leave_left -= delta
			if _leave_left <= 0.0:
				_state = State.GONE
				queue_free()
	_animate(delta)


func _walk(delta: float) -> void:
	var next: Vector3 = _agent.get_next_path_position()
	var direction: Vector3 = _flat(next - global_position)
	if direction.length_squared() < 0.0001:
		direction = _flat(_goal - global_position)
	direction = direction.normalized()
	velocity.x = direction.x * Constants.GUEST_SPEED
	velocity.z = direction.z * Constants.GUEST_SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(6.0 * delta, 1.0))
	_moving = move_toward(_moving, 1.0, delta * 4.0)
	_walk_phase += delta * Constants.GUEST_SPEED * 5.0
	if _bubble.text == tr("GUEST_LOST"):
		_bubble.visible = false


func _stand(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_moving = move_toward(_moving, 0.0, delta * 4.0)


func _arrive() -> void:
	_state = State.ARRIVED
	_leave_left = 4.0
	_bubble.text = tr("GUEST_URIG")
	_bubble.visible = true
	# A souvenir photo of the Stube.
	Sound.play_at(&"camera", global_position + Vector3.UP * 1.5)
	Events.event_announced.emit(tr("GUEST_URIG"))
	_drop_marker()
	var player := _nearest_player(INF)
	if player:
		player.equipment.give(EISSTOCK, EISSTOCK.max_carry)
		# After his line, so both banners are seen.
		get_tree().create_timer(2.0).timeout.connect(func() -> void: Events.event_announced.emit(tr("EVENT_GUEST_REWARD")))


func _die() -> void:
	_state = State.DEAD
	_leave_left = 5.0
	collision_layer = 0
	_bar.visible = false
	_bubble.visible = false
	_drop_marker()
	Events.event_announced.emit(tr("EVENT_GUEST_DIED"))
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _give_up() -> void:
	_state = State.DEAD
	_leave_left = 0.5
	_drop_marker()
	Events.event_announced.emit(tr("EVENT_GUEST_GAVE_UP"))


func _drop_marker() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()


func _update_bar() -> void:
	var share: float = clampf(float(health) / Constants.GUEST_HEALTH, 0.0, 1.0)
	# Plain digits: the web build has no font with block characters for a drawn bar.
	_bar.text = "%d%%" % ceili(share * 100.0)
	_bar.modulate = Color(1.0 - share, 0.4 + 0.5 * share, 0.3)


func _nearest_player(within: float) -> Player:
	var best: Player = null
	var best_distance: float = within
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.health.is_dead():
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance <= best_distance:
			best = player
			best_distance = distance
	return best


func _animate(_delta: float) -> void:
	var swing: float = sin(_walk_phase) * 0.5 * _moving
	var t: float = Time.get_ticks_msec() / 1000.0
	for child: Node3D in _rest:
		var rest: Transform3D = _rest[child]
		var name: String = child.name
		if name.begins_with("Leg"):
			var angle: float = swing if name.ends_with("L") else -swing
			var hip := Vector3(rest.origin.x, HIP, 0.0)
			child.transform = Transform3D(Basis(Vector3.RIGHT, angle), hip) * Transform3D(Basis.IDENTITY, -hip) * rest
		elif name.begins_with("Arm"):
			# The map bobs as he walks and turns as he looks around when lost.
			var look: float = sin(t * 1.3) * 0.25 * (1.0 - _moving)
			var bob: float = sin(_walk_phase * 2.0) * 0.03 * _moving
			child.transform = Transform3D(Basis(Vector3.UP, look), Vector3(0.0, bob, 0.0)) * rest


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
