class_name Enemy
extends CharacterBody3D
## Shared enemy body: chase the nearest player on the navmesh, hop through windows, melee in range.
## Configured by an EnemyData resource and reused from a pool, so activate() must reset everything.

signal died(enemy: Enemy)
## Corpse gone; the enemy can go back to the pool.
signal despawned(enemy: Enemy)

## QUEUED: waiting at a window another enemy is working. BREAKING: tearing boards off a barricade.
## LUNGING: crouching for and then flying through a leap at the player (Perchte).
enum State { INACTIVE, CHASING, QUEUED, BREAKING, CLIMBING, ATTACKING, LUNGING, DEAD }

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _visual: Node3D = $Visual
# Under Visual so they follow the climb and bob animations: you hit what you see.
@onready var _hurtboxes: Array[Hurtbox] = [$Visual/BodyHurtbox as Hurtbox, $Visual/HeadHurtbox as Hurtbox]
@onready var _head_shape: Node3D = $Visual/HeadHurtbox/Shape
@onready var _head_pop: EffectPool = $HeadPop

var data: EnemyData
var health: int = 0
## Health at spawn, for the boss bar.
var max_health: int = 0
var _state: State = State.INACTIVE
var _target: Player
var _model: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _repath_left: float = 0.0
var _attack_time: float = 0.0
var _has_swung: bool = false
var _walk_phase: float = 0.0
var _tween: Tween
# Hit reaction runs on the model, not on Visual, so it never fights the climb, attack or death tweens.
var _flinch_tween: Tween
var _flash_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _head_parts: Array[Node3D] = []
# The window being entered, from the navigation link: wall centre, inward direction, landing point inside.
var _window: Barricade
var _window_wall: Vector3
var _window_forward: Vector3
var _window_exit: Vector3
var _lunge_cooldown_left: float = 0.0
# Slowed (later dumplings and cow pats): speed factor and seconds left.
var _slow_factor: float = 1.0
var _slow_left: float = 0.0
# Seconds into the current lunge (windup first, then the leap), its direction, and whether it struck.
var _lunge_time: float = 0.0
var _lunge_direction: Vector3
var _lunge_struck: bool = false
# Unsticking: where the enemy was when the stuck timer last restarted, how long it has been there,
# and the sidestep it is taking (direction, seconds left, and which side to try next time).
var _stuck_anchor: Vector3
var _stuck_time: float = 0.0
var _sidestep: Vector3
var _sidestep_left: float = 0.0
var _sidestep_side: float = 1.0


func _ready() -> void:
	_agent.link_reached.connect(_on_link_reached)
	# Another enemy is never a moving platform: two bodies stacked in a crowd fed each other's
	# velocity and shot into the sky (stuck_hunt test).
	platform_floor_layers = Constants.LAYER_WORLD
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0)


func activate(enemy_data: EnemyData, wave: int, at: Transform3D) -> void:
	if data != enemy_data:
		if _model:
			_model.queue_free()
		_model = enemy_data.model.instantiate() as Node3D
		_visual.add_child(_model)
		_model.scale = Vector3.ONE * enemy_data.model_scale
		for hurtbox: Hurtbox in _hurtboxes:
			hurtbox.scale = Vector3.ONE * enemy_data.model_scale
		_meshes.assign(_model.find_children("*", "MeshInstance3D", true, false))
		_head_parts.assign(_model.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("head_part")))
	data = enemy_data
	health = data.health_for_wave(wave)
	max_health = health
	_lunge_cooldown_left = 0.0
	_slow_left = 0.0
	_slow_factor = 1.0
	global_transform = at
	velocity = Vector3.ZERO
	_visual.transform = Transform3D.IDENTITY
	_repath_left = 0.0
	_reset_stuck()
	_window = null
	_kill_tween()
	_reset_hit_reaction()
	for part: Node3D in _head_parts:
		part.visible = true
	_set_active(true)
	_state = State.CHASING
	if data.is_boss:
		Events.boss_spawned.emit(self)


func is_alive() -> bool:
	return _state != State.INACTIVE and _state != State.DEAD


func receive_hit(amount: int, is_headshot: bool, is_melee: bool, source: Node3D) -> Hurtbox.Result:
	if not is_alive():
		return Hurtbox.Result.IGNORED
	health -= amount
	_hit_flash()
	if health > 0:
		_flinch(is_headshot)
		Events.enemy_damaged.emit(self, amount, is_headshot, source)
		return Hurtbox.Result.HIT
	if is_headshot and amount >= data.head_pop_damage:
		_pop_head()
	_die(is_headshot, is_melee, source)
	return Hurtbox.Result.KILLED


## Slows the enemy to `factor` of its speed for `duration` seconds; the stronger slow wins.
func apply_slow(factor: float, duration: float) -> void:
	if _slow_left <= 0.0 or factor <= _slow_factor:
		_slow_factor = factor
	_slow_left = maxf(_slow_left, duration)


func _flinch(is_headshot: bool) -> void:
	if _flinch_tween:
		_flinch_tween.kill()
	# Lean back from the hit (the model faces -Z, so +X rotation tips it backwards); headshots snap harder.
	_model.rotation.x = (Constants.ENEMY_FLINCH_HEAD if is_headshot else Constants.ENEMY_FLINCH_BODY) * data.flinch_multiplier
	_flinch_tween = create_tween()
	_flinch_tween.tween_property(_model, "rotation:x", 0.0, Constants.ENEMY_FLINCH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hit_flash() -> void:
	# A white overlay pass, only on while it fades: an idle overlay would cost a draw per mesh.
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = _flash_material
	_flash_material.albedo_color.a = 0.7
	var tween: Tween = create_tween()
	tween.tween_property(_flash_material, "albedo_color:a", 0.0, Constants.ENEMY_HIT_FLASH_TIME)
	tween.tween_callback(_clear_flash)


func _clear_flash() -> void:
	if _flash_material.albedo_color.a > 0.0:
		return
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = null


func _reset_hit_reaction() -> void:
	if _flinch_tween:
		_flinch_tween.kill()
	if _model:
		_model.rotation = Vector3.ZERO
	_flash_material.albedo_color.a = 0.0
	_clear_flash()


func _pop_head() -> void:
	# Comic-horror, not gore: the head is gone in a red cloud, nothing anatomical (section 7).
	for part: Node3D in _head_parts:
		part.visible = false
	_head_pop.play(_head_shape.global_position, Vector3.UP)


func _physics_process(delta: float) -> void:
	_lunge_cooldown_left -= delta
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
	match _state:
		State.CHASING:
			_chase(delta)
		State.QUEUED:
			_wait_for_window(delta)
		State.BREAKING:
			_break_window(delta)
		State.ATTACKING:
			_attack(delta)
		State.LUNGING:
			_lunge(delta)
		State.DEAD:
			_fall(delta)


func _chase(delta: float) -> void:
	_target = _nearest_target()
	if _target == null:
		_halt(delta)
		return
	if _in_attack_range():
		_start_attack()
		return
	if _can_lunge():
		_start_lunge()
		return
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = Constants.ENEMY_REPATH_INTERVAL
		_agent.target_position = _target.global_position
	# Must be polled every frame: it advances the path and fires link_reached.
	var next: Vector3 = _agent.get_next_path_position()
	if _near_window_link():
		return
	var direction: Vector3 = _flat(next - global_position)
	if direction.length_squared() < 0.0001:
		direction = _flat(_target.global_position - global_position)
	direction = _unstick(direction.normalized(), delta)
	velocity.x = direction.x * data.speed * _slow_factor
	velocity.z = direction.z * data.speed * _slow_factor
	_apply_gravity(delta)
	_face(direction, delta)
	move_and_slide()
	_animate_walk(delta)


## Steering while chasing: the path direction, or a sidestep when the body has stopped making headway.
func _unstick(direction: Vector3, delta: float) -> Vector3:
	# Pushed up onto another enemy in a crowd: get off it first.
	var off: Vector3 = _off_enemy()
	if off != Vector3.ZERO:
		return off
	if _flat(global_position - _stuck_anchor).length() > Constants.ENEMY_STUCK_MOVE:
		_stuck_anchor = global_position
		_stuck_time = 0.0
	else:
		_stuck_time += delta
		if _stuck_time > Constants.ENEMY_STUCK_TIME:
			_start_sidestep(direction)
	if _sidestep_left <= 0.0:
		return direction
	_sidestep_left -= delta
	return _sidestep


func _start_sidestep(direction: Vector3) -> void:
	_stuck_time = 0.0
	_stuck_anchor = global_position
	_repath_left = 0.0
	# Along the wall it is pressed against, on the side nearer its way; if it is blocked by another
	# body (or nothing), step off at right angles, swapping sides each try.
	var side := Vector3(-direction.z, 0.0, direction.x) * _sidestep_side
	_sidestep_side = -_sidestep_side
	for i: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(i)
		var normal: Vector3 = _flat(hit.get_normal())
		if hit.get_collider() is Enemy or normal.length_squared() < 0.25:
			continue
		normal = normal.normalized()
		var along := Vector3(-normal.z, 0.0, normal.x)
		if along.dot(direction) < 0.0:
			along = -along
		side = (along + normal * 0.5).normalized()
		break
	_sidestep = (side + direction * 0.2).normalized()
	_sidestep_left = Constants.ENEMY_SIDESTEP_TIME


func _off_enemy() -> Vector3:
	for i: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(i)
		var below := hit.get_collider() as Enemy
		if below == null or hit.get_normal().y < 0.5:
			continue
		var away: Vector3 = _flat(global_position - below.global_position)
		if away.length_squared() < 0.0001:
			away = -global_basis.z
		return away.normalized()
	return Vector3.ZERO


func _reset_stuck() -> void:
	_stuck_anchor = global_position
	_stuck_time = 0.0
	_sidestep_left = 0.0


func _attack(delta: float) -> void:
	_halt(delta)
	if _target:
		_face(_flat(_target.global_position - global_position), delta)
	_attack_time += delta
	if not _has_swung and _attack_time >= data.attack_windup:
		_has_swung = true
		# Only lands if the player is still there: backing off during the windup is a real dodge.
		if _target and _target.is_targetable() and _in_attack_range():
			_target.take_damage(data.damage)
	if _attack_time >= data.attack_windup + data.attack_cooldown:
		_state = State.CHASING


func _start_attack() -> void:
	_state = State.ATTACKING
	_attack_time = 0.0
	_has_swung = false
	_kill_tween()
	_tween = create_tween()
	# Lean in during the windup, snap back as the hit lands.
	_tween.tween_property(_visual, "rotation:x", -0.45, data.attack_windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_visual, "rotation:x", 0.0, 0.25)


func _can_lunge() -> bool:
	if data.lunge_range <= 0.0 or _lunge_cooldown_left > 0.0 or not is_on_floor():
		return false
	var offset: Vector3 = _target.global_position - global_position
	return absf(offset.y) <= Constants.ENEMY_ATTACK_MAX_HEIGHT and _flat(offset).length() <= data.lunge_range and _clear_line_to_target()


func _start_lunge() -> void:
	_state = State.LUNGING
	_lunge_time = 0.0
	_lunge_struck = false
	_kill_tween()
	_visual.transform = Transform3D.IDENTITY
	_tween = create_tween()
	# Crouch and rear back, then throw the body forward for the leap.
	_tween.tween_property(_visual, "position:y", -0.25, data.lunge_windup * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_visual, "rotation:x", 0.3, data.lunge_windup * 0.8)
	_tween.tween_property(_visual, "position:y", 0.35, data.lunge_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_visual, "rotation:x", -0.7, data.lunge_time * 0.4)
	_tween.tween_property(_visual, "position:y", 0.0, data.lunge_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_visual, "rotation:x", 0.0, 0.25)


func _lunge(delta: float) -> void:
	_lunge_time += delta
	if _lunge_time < data.lunge_windup:
		# The direction locks at take-off, so side-stepping during the crouch dodges the leap.
		_halt(delta)
		if _target:
			_lunge_direction = _flat(_target.global_position - global_position).normalized()
			_face(_lunge_direction, delta)
		return
	velocity.x = _lunge_direction.x * data.lunge_speed
	velocity.z = _lunge_direction.z * data.lunge_speed
	_apply_gravity(delta)
	move_and_slide()
	if not _lunge_struck and _target and _target.is_targetable() and _in_attack_range():
		_lunge_struck = true
		_target.take_damage(data.damage)
	if _lunge_struck or _lunge_time >= data.lunge_windup + data.lunge_time:
		_end_lunge()


func _end_lunge() -> void:
	_lunge_cooldown_left = data.lunge_cooldown
	# Recover like after a swing: no second hit straight away.
	_state = State.ATTACKING
	_attack_time = data.attack_windup
	_has_swung = true


func _near_window_link() -> bool:
	# A crowd at a window shoves its front man around, so he may never get within the agent's
	# path_desired_distance of the link and link_reached never fires: the whole crowd stalls.
	# Close enough to the window the path goes through counts as there.
	var result: NavigationPathQueryResult3D = _agent.get_current_navigation_result()
	var path: PackedVector3Array = result.path
	var start: int = _agent.get_current_navigation_path_index()
	for i: int in range(start, mini(start + 2, path.size())):
		if result.path_types[i] != NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK:
			continue
		if _flat(path[i] - global_position).length() > Constants.ENEMY_LINK_REACH:
			return false
		var link := instance_from_id(result.path_owner_ids[i]) as NavigationLink3D
		if link == null:
			return false
		_on_link_reached({"link_entry_position": link.to_global(link.start_position), "link_exit_position": link.to_global(link.end_position)})
		return _state != State.CHASING
	return false


func _on_link_reached(details: Dictionary) -> void:
	if _state != State.CHASING:
		return
	# Window links are the only links.
	var entry: Vector3 = details.get("link_entry_position", global_position)
	_window_exit = details.get("link_exit_position", global_position)
	# Links are placed symmetrically across the wall, so their midpoint is the window.
	_window_forward = _flat(_window_exit - entry).normalized()
	_window_wall = _flat((entry + _window_exit) * 0.5)
	_window = _find_barricade(_window_wall)
	velocity = Vector3.ZERO
	if _window and not _window.claim(self):
		_state = State.QUEUED
		return
	_start_window()


func _wait_for_window(delta: float) -> void:
	# Stand behind the one in front; collision keeps the bodies apart.
	_halt(delta)
	_face(_window_forward, delta)
	if _window.claim(self):
		_start_window()


func _start_window() -> void:
	if _window == null or _window.is_open():
		_start_climb()
		return
	_state = State.BREAKING
	_kill_tween()
	_visual.transform = Transform3D.IDENTITY
	_tween = create_tween()
	var stand: Vector3 = _window_wall - _window_forward * Constants.ENEMY_WINDOW_STAND_OFF + Vector3.UP * global_position.y
	_tween.tween_property(self, "global_position", stand, Constants.ENEMY_WINDOW_APPROACH_TIME)


func _break_window(delta: float) -> void:
	_face(_window_forward, delta)
	if _tween and _tween.is_running():
		return
	if _window.is_open():
		_start_climb()
		return
	_pull_board()


func _pull_board() -> void:
	var time: float = data.board_break_time
	_kill_tween()
	_tween = create_tween()
	# Reach in, rip the board out, stagger back with it.
	_tween.tween_property(_visual, "rotation:x", -0.5, time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_window.remove_board)
	_tween.tween_property(_visual, "rotation:x", 0.2, time * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "rotation:x", 0.0, time * 0.25)


func _find_barricade(wall: Vector3) -> Barricade:
	for node: Node in get_tree().get_nodes_in_group("barricades"):
		var barricade := node as Barricade
		if _flat(barricade.global_position).distance_to(wall) < 1.0:
			return barricade
	return null


func _start_climb() -> void:
	# The opening is smaller than the body, so the enemy goes through lying flat, head first,
	# with collision off; every pose keeps the body inside the opening.
	_state = State.CLIMBING
	var forward: Vector3 = _window_forward
	var wall: Vector3 = _window_wall
	var exit: Vector3 = _window_exit
	var outside_y: float = global_position.y
	var dive_y: float = exit.y + Constants.ENEMY_WINDOW_DIVE_HEIGHT
	var at := func(along: float, height: float) -> Vector3: return wall + forward * along + Vector3.UP * height
	rotation.y = _yaw_towards(forward)
	collision_mask = 0
	velocity = Vector3.ZERO
	_visual.transform = Transform3D.IDENTITY
	_kill_tween()
	var time: float = data.climb_time
	var stand: float = Constants.ENEMY_WINDOW_STAND_OFF
	# Lean angle at which the body, feet still on the ground, points straight at the window centre.
	var lean: float = atan2(stand, dive_y - outside_y)
	_tween = create_tween()
	# Walk up to the wall and lean into the opening.
	_tween.tween_property(self, "global_position", at.call(-stand, outside_y), time * 0.15)
	_tween.parallel().tween_property(_visual, "rotation:x", -lean, time * 0.15)
	# Dive head first: the feet kick up while the body keeps pointing through the window centre.
	_tween.tween_method(_dive_pose.bind(at.call(-stand, 0.0), dive_y, stand), lean, PI * 0.5, time * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Wriggle through.
	_tween.tween_property(self, "global_position", at.call(stand * 0.6, dive_y), time * 0.25)
	_tween.parallel().tween_method(_wriggle, 0.0, 1.0, time * 0.25)
	# Belly flop onto the floor.
	_tween.tween_property(self, "global_position", at.call(stand, exit.y + Constants.ENEMY_LYING_HEIGHT), time * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_interval(time * 0.08)
	# Spring back up like a plank.
	_tween.tween_property(_visual, "rotation:x", 0.0, time * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "global_position", exit, time * 0.2)
	_tween.finished.connect(_end_climb)


func _dive_pose(angle: float, feet_base: Vector3, dive_y: float, stand: float) -> void:
	_visual.rotation.x = -angle
	# Feet height that keeps the body line crossing the wall plane at dive_y.
	global_position = feet_base + Vector3.UP * (dive_y - stand / tan(angle))


func _wriggle(t: float) -> void:
	_visual.rotation.z = sin(t * TAU * 3.0) * 0.35 * (1.0 - t)


func _end_climb() -> void:
	if _state != State.CLIMBING:
		return
	_visual.transform = Transform3D.IDENTITY
	collision_mask = _movement_mask()
	_repath_left = 0.0
	_reset_stuck()
	_leave_window()
	_state = State.CHASING


func _leave_window() -> void:
	if _window:
		_window.release(self)
		_window = null


func _die(is_headshot: bool, is_melee: bool, source: Node3D) -> void:
	_state = State.DEAD
	_leave_window()
	collision_layer = 0
	collision_mask = Constants.LAYER_WORLD
	for hurtbox: Hurtbox in _hurtboxes:
		hurtbox.collision_layer = 0
	# Points first, then the wave manager: the last kill of a wave is paid out before "wave cleared".
	Events.enemy_killed.emit(self, is_headshot, is_melee, source)
	died.emit(self)
	_kill_tween()
	_visual.rotation.z = 0.0
	# Fall backwards, unless already lying face down in a window: then just stay down.
	var fall_to: float = -PI * 0.5 if _visual.rotation.x < -PI * 0.25 else PI * 0.5
	_tween = create_tween()
	_tween.tween_property(_visual, "rotation:x", fall_to, Constants.ENEMY_DEATH_FALL_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(Constants.ENEMY_CORPSE_TIME)
	_tween.tween_callback(_despawn)


func _fall(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _despawn() -> void:
	_state = State.INACTIVE
	_set_active(false)
	despawned.emit(self)


func _set_active(active: bool) -> void:
	visible = active
	collision_layer = Constants.LAYER_ENEMY if active else 0
	collision_mask = _movement_mask() if active else 0
	for hurtbox: Hurtbox in _hurtboxes:
		hurtbox.collision_layer = Constants.LAYER_HITBOX if active else 0
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _movement_mask() -> int:
	# No player_blocker: window openings are how enemies get in.
	return Constants.LAYER_WORLD | Constants.LAYER_PLAYER | Constants.LAYER_ENEMY


func _nearest_target() -> Player:
	var best: Player = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or not player.is_targetable():
			continue
		var distance: float = global_position.distance_squared_to(player.global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


func _in_attack_range() -> bool:
	var offset: Vector3 = _target.global_position - global_position
	if absf(offset.y) > Constants.ENEMY_ATTACK_MAX_HEIGHT or _flat(offset).length() > data.attack_range:
		return false
	return _clear_line_to_target()


func _clear_line_to_target() -> bool:
	# Only in the same room: walls and window openings (player blockers) both stop the swing.
	var chest := Vector3.UP * Constants.ENEMY_ATTACK_CHEST_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(global_position + chest, _target.global_position + chest, Constants.LAYER_WORLD | Constants.LAYER_PLAYER_BLOCKER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _halt(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, _yaw_towards(direction), minf(Constants.ENEMY_TURN_SPEED * delta, 1.0))


func _animate_walk(delta: float) -> void:
	# Shambling bob and sway; enough to read as "walking" on a greybox model.
	_walk_phase += delta * data.speed * _slow_factor * 2.2
	_visual.position.y = absf(sin(_walk_phase)) * 0.06
	_visual.rotation.z = sin(_walk_phase) * 0.06


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _yaw_towards(direction: Vector3) -> float:
	# Godot models face -Z.
	return atan2(-direction.x, -direction.z)
