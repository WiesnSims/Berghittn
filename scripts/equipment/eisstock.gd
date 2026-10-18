class_name Eisstock
extends Node3D
## A thrown Eisstock (section 6a): slides along the floor like a curling stone, bounces off walls up to
## EISSTOCK_BOUNCES times and goes straight through every enemy in its way, which it hits very hard.
## Deliberately overpowered; it only comes from the Deitscha Tourist. Comes to a stop and is gone.

const RADIUS: float = 0.16

var velocity: Vector3
var _bounces_left: int = Constants.EISSTOCK_BOUNCES
var _thrower: Node3D
var _hit: Dictionary = {}
var _resting: bool = false
var _rest_left: float = 0.0
var _fall_speed: float = 0.0
var _slide: AudioStreamPlayer3D
@onready var _model: Node3D = $Model


func launch(from: Vector3, direction: Vector3, thrower: Node3D) -> void:
	global_position = from
	velocity = direction * Constants.EISSTOCK_SPEED
	_thrower = thrower
	_slide = Sound.attach(&"eisstock_slide", self)


func is_sliding() -> bool:
	return not _resting


func bounces_left() -> int:
	return _bounces_left


func _physics_process(delta: float) -> void:
	if _resting:
		_rest_left -= delta
		_model.scale = Vector3.ONE * clampf(_rest_left / 0.5, 0.0, 1.0)
		if _rest_left <= 0.0:
			queue_free()
		return
	var speed: float = move_toward(velocity.length(), 0.0, Constants.EISSTOCK_FRICTION * delta)
	if speed < 0.5:
		_stop()
		return
	velocity = velocity.normalized() * speed
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var step: Vector3 = velocity * delta
	var low := Vector3.UP * 0.12
	var ahead := PhysicsRayQueryParameters3D.create(global_position + low, global_position + low + velocity.normalized() * (step.length() + RADIUS), Constants.LAYER_WORLD)
	var wall: Dictionary = space.intersect_ray(ahead)
	var normal := Vector3(wall.normal.x, 0.0, wall.normal.z) if not wall.is_empty() else Vector3.ZERO
	# A ramp ahead is floor, not wall: it slides up or down it.
	if normal.length_squared() >= 0.25:
		if _bounces_left <= 0:
			_stop()
			return
		_bounces_left -= 1
		Sound.play_at(&"eisstock_hit", global_position)
		velocity = velocity.bounce(normal.normalized()) * Constants.EISSTOCK_BOUNCE_KEEP
		global_position = Vector3(wall.position.x, global_position.y, wall.position.z) + normal.normalized() * (RADIUS + 0.02)
		return
	global_position += step
	_follow_floor(space, delta)
	_model.rotate_y(speed * delta * 1.5)
	_strike()


func _follow_floor(space: PhysicsDirectSpaceState3D, delta: float) -> void:
	# Down a ramp or off a step it drops; never up a wall.
	var down := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.4, global_position + Vector3.DOWN * 0.6, Constants.LAYER_WORLD)
	var floor_hit: Dictionary = space.intersect_ray(down)
	if not floor_hit.is_empty() and floor_hit.position.y >= global_position.y - 0.05 - _fall_speed * delta:
		global_position.y = floor_hit.position.y
		_fall_speed = 0.0
	else:
		_fall_speed += 9.8 * delta
		global_position.y -= _fall_speed * delta
		if global_position.y < -30.0:
			queue_free()


func _strike() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var offset: Vector3 = enemy.global_position - global_position
		if Vector2(offset.x, offset.z).length() > Constants.EISSTOCK_HIT_REACH or absf(offset.y) > 1.2:
			continue
		var id: int = enemy.get_instance_id()
		if now - _hit.get(id, -10.0) < 0.4:
			continue
		_hit[id] = now
		Sound.play_at(&"eisstock_hit", global_position)
		if enemy.data.is_boss:
			enemy.receive_hit(Constants.EISSTOCK_BOSS_DAMAGE, false, false, _thrower)
			if enemy.is_alive():
				enemy.apply_knockback(velocity.normalized() * 7.0)
		else:
			enemy.receive_hit(Constants.EISSTOCK_DAMAGE, false, false, _thrower)
		# Each body it ploughs through costs it a little speed.
		velocity *= 0.94


func _stop() -> void:
	_resting = true
	if _slide:
		_slide.queue_free()
		_slide = null
	_rest_left = 3.0
