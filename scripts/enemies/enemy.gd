class_name Enemy
extends CharacterBody3D
## Shared enemy body: chase the nearest player on the navmesh, hop through windows, melee in range.
## Configured by an EnemyData resource and reused from a pool, so activate() must reset everything.

signal died(enemy: Enemy)
## Corpse gone; the enemy can go back to the pool.
signal despawned(enemy: Enemy)
## Co-op (M7): it started an action (a swing, a board pulled, a climb), for the host to pass on.
signal posed(enemy: Enemy, action: EnemyRig.Action, length: float)
## It said Gredn line `line` (M9 part 3; solo and host), for co-op to pass on.
signal said(enemy: Enemy, line: int)
## It vanished alive (the Venedigermandl, M9 part 5a; solo and host), for co-op to pass on.
signal vanished(enemy: Enemy)

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
## Co-op (M7): on a guest this enemy is a copy of the host's (a puppet). CoopEnemies moves it, and
## what hits it goes to the host through hit_relay instead of being applied here.
var puppet: bool = false
## Co-op: the id host and guests know it by while it lives (0: none).
var net_id: int = 0
## The last hit's damage, so the host can tell guests how hard the killing blow was (ragdoll, head).
var last_damage: int = 0
## The wave it came in (the Venedigermandl's pay goes by it).
var wave: int = 0
## Co-op guests: (enemy, method, args) -> void, sends a hit on a puppet to the host.
static var hit_relay: Callable
var _state: State = State.INACTIVE
## A player or an escort (group "escorts"): anything with is_targetable() and take_damage(amount, attacker).
var _target: Node3D
var _model: Node3D
# The model's skeleton (M6 part 4): limb poses and the ragdoll.
var _rig: EnemyRig
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _repath_left: float = 0.0
var _attack_time: float = 0.0
var _has_swung: bool = false
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
# Thrown back (Böllerschuss): the push that is left, flat.
var _knock: Vector3
# Stunned by the Goaßl (standing dazed), or fleeing from the Krampus-Rute: seconds left, and where
# from.
var _stun_left: float = 0.0
var _flee_left: float = 0.0
var _flee_from: Vector3
# Lifted on the Mistgabel (carried, no will of its own), then hurled: flying until it lands, when
# _on_land is called with it. Its collision is off meanwhile, so it cannot shove the player.
var _lifted: bool = false
var _hurled: bool = false
var _hurl_time: float = 0.0
var _on_land: Callable
# Co-op guest: when the carried puppet's position, and a slow on it, last went to the host (ms).
var _carry_sent_ms: int = 0
var _slow_sent_ms: int = -100000
var _body_layer: int = 0
var _body_mask: int = 0
# Dancing to the Harmonika: seconds left.
var _dance_left: float = 0.0
var _dance_phase: float = 0.0
# Damage paid out once a second for a while, by kind (&"polka", &"burn"); bosses take it too.
var _dots: Dictionary = {}
# Seconds until a scorch (the flame's ticks) pays hit points again.
var _scorch_paid_left: float = 0.0
# Flames on the body while it burns; built the first time it catches fire.
var _burn_fx: CPUParticles3D
# Came in through a window: lures outside (die Resi) no longer pull it back out.
var _inside: bool = false
var _lure: Node3D
# Seconds until the next groan.
var _groan_left: float = 0.0
## Seconds until it may say another line (Gredn).
var talk_left: float = 0.0
# It has seen a player this life (the SPOT line comes once), and seconds left of a line it is saying
# (no groans or death cry over it).
var _spotted: bool = false
var _speaking_left: float = 0.0
# Seconds its corpse has been a ragdoll.
var _ragdoll_time: float = 0.0
# The Venedigermandl (EnemyData.treasure): seconds before he vanishes, whether a player set him
# running and where he runs to, the dart's phase, seconds to his next giggle, whether he has said
# he is here, his glow, his marker and his gold.
var _life_left: float = 0.0
var _running: bool = false
var _escape: Vector3
var _dart_phase: float = 0.0
var _giggle_left: float = 0.0
var _announced: bool = false
var _glow: OmniLight3D
var _marker: MapMarker
var _gold: MandlGold
## The corpses being simulated now, oldest first (at most Constants.RAGDOLL_MAX).
static var _ragdolls: Array[Enemy] = []


func _ready() -> void:
	_agent.link_reached.connect(_on_link_reached)
	# Another enemy is never a moving platform: two bodies stacked in a crowd fed each other's
	# velocity and shot into the sky (stuck_hunt test).
	platform_floor_layers = Constants.LAYER_WORLD
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0)


func activate(enemy_data: EnemyData, for_wave: int, at: Transform3D) -> void:
	if data != enemy_data:
		if _model:
			_model.queue_free()
		_model = enemy_data.model.instantiate() as Node3D
		_visual.add_child(_model)
		# Built at its size (tools/models): physics bodies are never scaled.
		_rig = _model as EnemyRig
		for hurtbox: Hurtbox in _hurtboxes:
			hurtbox.scale = Vector3.ONE * enemy_data.model_scale
		_meshes.assign(_model.find_children("*", "MeshInstance3D", true, false))
		_head_parts.assign(_model.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("head_part")))
	data = enemy_data
	wave = for_wave
	health = data.health_for_wave(wave)
	max_health = health
	_lunge_cooldown_left = 0.0
	_dance_left = 0.0
	_stun_left = 0.0
	_flee_left = 0.0
	if _lifted or _hurled:
		_lifted = false
		_hurled = false
		collision_layer = _body_layer
		collision_mask = _body_mask
	for dot: Dot in _dots.values():
		dot.left = 0.0
	_scorch_paid_left = 0.0
	if _burn_fx:
		_burn_fx.emitting = false
	_slow_left = 0.0
	_slow_factor = 1.0
	global_transform = at
	velocity = Vector3.ZERO
	_visual.transform = Transform3D.IDENTITY
	_repath_left = 0.0
	_reset_stuck()
	_knock = Vector3.ZERO
	_inside = false
	_lure = null
	_window = null
	_kill_tween()
	_reset_hit_reaction()
	_ragdolls.erase(self)
	if _rig:
		_rig.reset()
	for part: Node3D in _head_parts:
		part.visible = true
	_set_active(true)
	_state = State.CHASING
	talk_left = 0.0
	_spotted = false
	_speaking_left = 0.0
	# A boss roars as it arrives; the rest start groaning a while after they appear.
	_groan_left = 0.3 if data.is_boss else randf_range(0.5, Constants.GROAN_MAX)
	if data.is_boss:
		Events.boss_spawned.emit(self)
	if data.treasure:
		_appear()


func is_alive() -> bool:
	return _state != State.INACTIVE and _state != State.DEAD


func receive_hit(amount: int, is_headshot: bool, is_melee: bool, source: Node3D) -> Hurtbox.Result:
	if puppet:
		return _relay(&"receive_hit", [amount, is_headshot, is_melee], amount, is_headshot)
	# A dancer has its guard down: every other hit lands harder.
	if is_dancing():
		amount *= Constants.DANCE_DAMAGE_MULTIPLIER
	return _take_hit(amount, is_headshot, is_melee, source)


## A tick of the Brennkessel's flame: like a hit (twice as hard on a dancer), but it pays hit points
## only once per SCORCH_PAY_INTERVAL, not eight times a second.
func scorch(amount: int, source: Node3D) -> Hurtbox.Result:
	if puppet:
		return _relay(&"scorch", [amount], amount, false)
	if is_dancing():
		amount *= Constants.DANCE_DAMAGE_MULTIPLIER
	var pays: bool = _scorch_paid_left <= 0.0
	if pays:
		_scorch_paid_left = Constants.SCORCH_PAY_INTERVAL
	return _take_hit(amount, false, false, source, pays)


## Sets the enemy on fire: `dps` a second from `source` for `duration` (catching fire again while
## burning starts the time over), with flames on the body. Bosses burn too.
func ignite(duration: float, dps: int, source: Node3D) -> void:
	if not is_alive():
		return
	if puppet:
		_relay(&"ignite", [duration, dps])
		return
	_add_dot(&"burn", duration, dps, source)
	if _burn_fx == null:
		_burn_fx = _build_burn_fx()
	_burn_fx.emitting = true


func is_burning() -> bool:
	return is_alive() and _dots.has(&"burn") and (_dots[&"burn"] as Dot).left > 0.0


func _take_hit(amount: int, is_headshot: bool, is_melee: bool, source: Node3D, pays: bool = true) -> Hurtbox.Result:
	if not is_alive():
		return Hurtbox.Result.IGNORED
	last_damage = amount
	health -= amount
	_hit_flash()
	if health > 0:
		_flinch(is_headshot)
		if data.treasure and pays:
			_gold_fx().coins(_chest())
		if pays:
			Events.enemy_damaged.emit(self, amount, is_headshot, source)
		if amount >= max_health * Constants.GREDN_HARD_HIT:
			Gredn.moment(self, Gredn.Moment.HIT)
		return Hurtbox.Result.HIT
	if is_headshot and amount >= data.head_pop_damage:
		_pop_head()
	_die(is_headshot, is_melee, source, amount)
	return Hurtbox.Result.KILLED


## Slows the enemy to `factor` of its speed for `duration` seconds; the stronger slow wins. Bosses
## shrug it off (immune to crowd control, section 6a).
func apply_slow(factor: float, duration: float) -> void:
	if data.is_boss:
		return
	if puppet:
		# A heap slows whoever stands in it every frame; the host needs only a few of those.
		if Time.get_ticks_msec() - _slow_sent_ms >= Constants.NET_SLOW_RELAY_INTERVAL * 1000.0:
			_slow_sent_ms = Time.get_ticks_msec()
			_relay(&"apply_slow", [factor, duration])
		return
	if _slow_left <= 0.0 or factor <= _slow_factor:
		_slow_factor = factor
	_slow_left = maxf(_slow_left, duration)


## The Harmonika's polka: for `duration` seconds the enemy dances on the spot (no walking, no
## attacks; a swing in progress is dropped) and takes `dps` a second from `source`. Bosses take the
## damage but do not dance (immune to crowd control, section 6a).
func dance(duration: float, dps: int, source: Node3D) -> void:
	if not is_alive():
		return
	if puppet:
		_relay(&"dance", [duration, dps])
		return
	_add_dot(&"polka", duration, dps, source)
	if data.is_boss:
		return
	if _dance_left <= 0.0:
		_dance_phase = 0.0
		_pose(EnemyRig.Action.DANCE)
	_dance_left = maxf(_dance_left, duration)
	_drop_swing()


## The Goaßl's crack: dazed on the spot for `duration` (no walking, no attacks; a swing in progress
## is dropped). Bosses shrug it off.
func stun(duration: float) -> void:
	if not is_alive() or data.is_boss:
		return
	if puppet:
		_relay(&"stun", [duration])
		return
	_stun_left = maxf(_stun_left, duration)
	_drop_swing()
	_pose(EnemyRig.Action.DAZED)


func is_stunned() -> bool:
	return _stun_left > 0.0 and is_alive() and _can_dance()


## The Krampus-Rute: runs away from `from` for `duration`, attacking nobody. Bosses shrug it off.
func flee(from: Vector3, duration: float) -> void:
	if not is_alive() or data.is_boss:
		return
	if puppet:
		_relay(&"flee", [from, duration])
		return
	_flee_from = from
	if _flee_left <= 0.0:
		_repath_left = 0.0
	_flee_left = maxf(_flee_left, duration)
	_drop_swing()


func is_fleeing() -> bool:
	return _flee_left > 0.0 and is_alive() and _can_dance()


## The Mistgabel: lifted up on the fork. Its holder moves it (carry_to) until it is hurled or let go.
## Bosses are too heavy: false.
func lift() -> bool:
	if not is_alive() or data.is_boss or _lifted or _hurled or not _can_dance():
		return false
	# Co-op: a guest's fork lifts its puppet here, at once, and the host's enemy with it; the guest
	# carries and hurls the puppet itself and the host moves its enemy along (carry_to, hurl).
	if puppet:
		_relay(&"lift", [])
	_lifted = true
	_knock = Vector3.ZERO
	_drop_swing()
	_body_layer = collision_layer
	_body_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_pose(EnemyRig.Action.CARRIED)
	return true


func is_lifted() -> bool:
	return _lifted and is_alive()


## Where a lifted enemy is carried to (its feet), facing `facing`.
func carry_to(at: Vector3, facing: Vector3) -> void:
	if not _lifted:
		return
	global_position = at
	_face(facing, 1.0 / Engine.physics_ticks_per_second)
	_visual.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.3
	if puppet and Time.get_ticks_msec() - _carry_sent_ms >= Constants.NET_POSE_INTERVAL * 1000.0:
		_carry_sent_ms = Time.get_ticks_msec()
		_relay(&"carry_to", [at, facing])


## Throws a lifted enemy along `launch` (m/s); `landed` is called with it where it comes down.
func hurl(launch: Vector3, landed: Callable = Callable()) -> void:
	if not _lifted:
		return
	if puppet:
		_relay(&"hurl", [launch])
	_lifted = false
	_hurled = true
	_hurl_time = 0.0
	_on_land = landed
	velocity = launch
	# It lands on the world, but still passes through the player.
	collision_mask = Constants.LAYER_WORLD


func _hurling(delta: float) -> void:
	_hurl_time += delta
	velocity.y -= _gravity * delta
	move_and_slide()
	_visual.rotation.x += 8.0 * delta
	if _hurl_time > 0.15 and (is_on_floor() or is_on_wall()) or _hurl_time > Constants.LOBBED_MAX_FLIGHT:
		_hurled = false
		_visual.rotation.x = 0.0
		_visual.rotation.z = 0.0
		velocity = Vector3.ZERO
		collision_layer = _body_layer
		collision_mask = _body_mask
		_pose(EnemyRig.Action.NONE)
		if _on_land.is_valid():
			_on_land.call(self)


func _drop_swing() -> void:
	if _state == State.ATTACKING:
		_kill_tween()
		_visual.rotation.x = 0.0
		_state = State.CHASING
		_pose(EnemyRig.Action.NONE)


func is_dancing() -> bool:
	return _dance_left > 0.0 and is_alive() and _can_dance()


func _can_dance() -> bool:
	return _state == State.CHASING or _state == State.ATTACKING or _state == State.QUEUED


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
	if puppet and is_alive():
		_puppet_step(delta)
	else:
		_step(delta)
	if _rig == null:
		return
	if is_alive():
		_rig.update(delta, Vector2(velocity.x, velocity.z).length())
		# You hit what you see: the head hurtbox stays on the head as it hunches, swings and dives.
		_head_shape.global_position = _rig.head_position()
	elif _rig.is_ragdoll():
		_ragdoll_time += delta


func _step(delta: float) -> void:
	_lunge_cooldown_left -= delta
	talk_left -= delta
	_speaking_left -= delta
	if data and data.treasure and is_alive():
		_life_left -= delta
		if _life_left <= 0.0:
			_vanish()
			return
		if not _announced and _life_left <= Constants.MANDL_LIFETIME - Constants.NET_POSE_INTERVAL * 2.0:
			# A moment after he appears, so co-op guests already have him and hear it too.
			_announced = true
			Gredn.moment(self, Gredn.Moment.APPEAR)
	if is_alive():
		_groan_left -= delta
		if _groan_left <= 0.0:
			_groan()
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
	_scorch_paid_left -= delta
	if not _dots.is_empty() and is_alive():
		_tick_dots(delta)
	if _knock != Vector3.ZERO and (_state == State.CHASING or _state == State.ATTACKING or _state == State.QUEUED):
		_knocked(delta)
		return
	if _lifted:
		return
	if _hurled:
		_hurling(delta)
		return
	if _dance_left > 0.0:
		_dance_left -= delta
		if _can_dance() and is_alive():
			_dancing(delta)
			if _dance_left <= 0.0:
				_visual.rotation.z = 0.0
				_visual.position.y = 0.0
				_pose(EnemyRig.Action.NONE)
			return
	if _stun_left > 0.0:
		_stun_left -= delta
		if _can_dance() and is_alive():
			_halt(delta)
			# Dazed: swaying on the spot.
			_visual.rotation.z = sin(_stun_left * 9.0) * 0.12
			if _stun_left <= 0.0:
				_visual.rotation.z = 0.0
				_pose(EnemyRig.Action.NONE)
			return
	if _flee_left > 0.0:
		_flee_left -= delta
		if _can_dance() and is_alive():
			_state = State.CHASING
			var away := _flat(global_position - _flee_from)
			if away.length() < 0.1:
				away = -global_basis.z
			_walk_towards(global_position + away.normalized() * Constants.FLEE_LOOKAHEAD, delta)
			if _flee_left <= 0.0:
				# Straight back on the chase, not on along the last run away.
				_repath_left = 0.0
			return
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


func _add_dot(kind: StringName, duration: float, dps: int, source: Node3D) -> void:
	var dot: Dot = _dots.get(kind)
	if dot == null:
		dot = Dot.new()
		_dots[kind] = dot
	if dot.left <= 0.0:
		dot.tick = 0.0
	dot.left = maxf(dot.left, duration)
	dot.dps = dps
	dot.source = source


func _tick_dots(delta: float) -> void:
	for kind: StringName in _dots:
		var dot: Dot = _dots[kind]
		if dot.left <= 0.0:
			continue
		dot.left -= delta
		dot.tick += delta
		# A second of it is paid as one hit (one flash, one set of points), not one per frame.
		if dot.tick >= 1.0:
			dot.tick -= 1.0
			_take_hit(dot.dps, false, false, dot.source)
			if not is_alive():
				return
		if kind == &"burn" and dot.left <= 0.0 and _burn_fx:
			_burn_fx.emitting = false


func _build_burn_fx() -> CPUParticles3D:
	var fx: CPUParticles3D = Flames.particles(24, 0.5, Vector2(0.22, 0.3))
	fx.position = Vector3(0.0, 1.0, 0.0)
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fx.emission_box_extents = Vector3(0.25, 0.6, 0.15)
	_visual.add_child(fx)
	return fx


func _dancing(delta: float) -> void:
	_halt(delta)
	_dance_phase += delta
	rotation.y += Constants.DANCE_SPIN * delta
	var hop: float = absf(sin(_dance_phase * PI * Constants.DANCE_HOP_RATE))
	_visual.position.y = hop * Constants.DANCE_HOP
	_visual.rotation.z = sin(_dance_phase * PI * Constants.DANCE_HOP_RATE * 0.5) * 0.25


## Throws the enemy back along `push` (m/s, flat), with a little hop; it chases again once it lands.
func apply_knockback(push: Vector3) -> void:
	# On the fork or flying off it, the Mistgabel moves it.
	if not is_alive() or _lifted or _hurled:
		return
	if puppet:
		_relay(&"apply_knockback", [push])
		return
	_knock = _flat(push)
	if is_on_floor():
		velocity.y = Constants.ENEMY_KNOCKBACK_HOP


func _knocked(delta: float) -> void:
	_state = State.CHASING
	velocity.x = _knock.x
	velocity.z = _knock.z
	# Not _apply_gravity: that zeroes the hop while the feet still touch the floor.
	if velocity.y > 0.0 or not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_knock = _knock.move_toward(Vector3.ZERO, Constants.ENEMY_KNOCKBACK_DECAY * delta)
	_reset_stuck()


func _chase(delta: float) -> void:
	if data.treasure:
		_treasure(delta)
		return
	var lure: Node3D = _find_lure()
	if lure != _lure:
		_lure = lure
		_repath_left = 0.0
	if lure:
		if _flat(lure.global_position - global_position).length() <= Constants.ENEMY_LURE_REACH:
			lure.lure_reached(self)
			_halt(delta)
		else:
			_walk_towards(lure.global_position, delta)
		return
	_target = _nearest_target()
	if _target == null:
		_halt(delta)
		return
	if not _spotted and _sees_target():
		_spotted = true
		Gredn.moment(self, Gredn.Moment.SPOT)
	if _in_attack_range():
		_start_attack()
		return
	if _can_lunge():
		_start_lunge()
		return
	_walk_towards(_target.global_position, delta)


func _walk_towards(goal: Vector3, delta: float) -> void:
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = Constants.ENEMY_REPATH_INTERVAL
		_agent.target_position = goal
	# Must be polled every frame: it advances the path and fires link_reached.
	var next: Vector3 = _agent.get_next_path_position()
	if _near_window_link():
		return
	var direction: Vector3 = _flat(next - global_position)
	if direction.length_squared() < 0.0001:
		direction = _flat(goal - global_position)
	direction = _unstick(direction.normalized(), delta)
	velocity.x = direction.x * data.speed * _slow_factor
	velocity.z = direction.z * data.speed * _slow_factor
	_apply_gravity(delta)
	_face(direction, delta)
	move_and_slide()


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
			_target.take_damage(data.damage, self)
	if _attack_time >= data.attack_windup + data.attack_cooldown:
		_state = State.CHASING


func _start_attack() -> void:
	_state = State.ATTACKING
	_attack_time = 0.0
	_has_swung = false
	_voice(&"enemy_attack")
	# Arms up through the windup and down as the hit lands (the rig's swing peaks at 65 %).
	_pose(EnemyRig.Action.STRIKE, data.attack_windup / 0.65)
	_kill_tween()
	_tween = create_tween()
	# Lean in during the windup, snap back as the hit lands.
	_tween.tween_property(_visual, "rotation:x", -0.2, data.attack_windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_visual, "rotation:x", 0.0, 0.25)


func _can_lunge() -> bool:
	if data.lunge_range <= 0.0 or _lunge_cooldown_left > 0.0 or not is_on_floor():
		return false
	var offset: Vector3 = _target.global_position - global_position
	return absf(offset.y) <= Constants.ENEMY_ATTACK_MAX_HEIGHT and _flat(offset).length() <= data.lunge_range and _clear_line_to_target()


func _start_lunge() -> void:
	_state = State.LUNGING
	_lunge_time = 0.0
	if Gredn.moment(self, Gredn.Moment.LUNGE) < 0:
		_voice(&"enemy_attack")
	_lunge_struck = false
	_pose(EnemyRig.Action.CROUCH, data.lunge_windup)
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
	if _lunge_time - delta < data.lunge_windup:
		_pose(EnemyRig.Action.LEAP, data.lunge_time)
	velocity.x = _lunge_direction.x * data.lunge_speed
	velocity.z = _lunge_direction.z * data.lunge_speed
	_apply_gravity(delta)
	move_and_slide()
	if not _lunge_struck and _target and _target.is_targetable() and _in_attack_range():
		_lunge_struck = true
		_target.take_damage(data.damage, self)
	if _lunge_struck or _lunge_time >= data.lunge_windup + data.lunge_time:
		_end_lunge()


func _end_lunge() -> void:
	_lunge_cooldown_left = data.lunge_cooldown
	_pose(EnemyRig.Action.NONE)
	# Recover like after a swing: no second hit straight away.
	_state = State.ATTACKING
	_attack_time = data.attack_windup
	_has_swung = true


func _near_window_link() -> bool:
	# The Venedigermandl never climbs through a window.
	if data.treasure:
		return false
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
	if _state != State.CHASING or data.treasure:
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
	Gredn.moment(self, Gredn.Moment.BARRICADE)
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
	_pose(EnemyRig.Action.PULL, time)
	_kill_tween()
	_tween = create_tween()
	# Reach in, rip the board out, stagger back with it.
	_tween.tween_property(_visual, "rotation:x", -0.3, time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
	_pose(EnemyRig.Action.CLIMB)
	Sound.play_at(&"window_climb", global_position)
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
	_pose(EnemyRig.Action.NONE)
	collision_mask = _movement_mask()
	_repath_left = 0.0
	_reset_stuck()
	_inside = true
	_leave_window()
	_state = State.CHASING


func _leave_window() -> void:
	if _window:
		_window.release(self)
		_window = null


func _die(is_headshot: bool, is_melee: bool, source: Node3D, amount: int = 100) -> void:
	_state = State.DEAD
	# Its last words, if any, instead of the cry (in co-op they came from the host just before).
	Gredn.moment(self, Gredn.Moment.DEATH)
	if _speaking_left <= 0.0:
		_voice(data.death_sound)
	if _lifted or _hurled:
		_lifted = false
		_hurled = false
		_visual.rotation.x = 0.0
	if _burn_fx:
		_burn_fx.emitting = false
	if data.treasure:
		_gold_fx().fountain(_chest())
		_treasure_gone()
	_leave_window()
	collision_layer = 0
	collision_mask = Constants.LAYER_WORLD
	for hurtbox: Hurtbox in _hurtboxes:
		hurtbox.collision_layer = 0
	# Co-op: the host's drop is the one everyone sees (CoopWorld); a puppet leaves none of its own.
	if data.drop and not puppet:
		WeaponPickup.spawn(data.drop, global_position, get_parent())
	# Points first, then the wave manager: the last kill of a wave is paid out before "wave cleared".
	Events.enemy_killed.emit(self, is_headshot, is_melee, source)
	died.emit(self)
	_kill_tween()
	_tween = create_tween()
	if _start_ragdoll(source, amount):
		_tween.tween_interval(Constants.RAGDOLL_TIME)
		_tween.tween_callback(_freeze_ragdoll)
		_tween.tween_interval(Constants.ENEMY_CORPSE_TIME + Constants.ENEMY_DEATH_FALL_TIME - Constants.RAGDOLL_TIME)
		_tween.tween_callback(_despawn)
		return
	_visual.rotation.z = 0.0
	# Fall backwards, unless already lying face down in a window: then just stay down.
	var fall_to: float = -PI * 0.5 if _visual.rotation.x < -PI * 0.25 else PI * 0.5
	_tween.tween_property(_visual, "rotation:x", fall_to, Constants.ENEMY_DEATH_FALL_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(Constants.ENEMY_CORPSE_TIME)
	_tween.tween_callback(_despawn)


## Goes limp (M6 part 4, #39), thrown away from whoever killed it, if a ragdoll is free: the oldest
## one that has had time to fall is frozen to make room. False: it falls the old way.
func _start_ragdoll(source: Node3D, amount: int) -> bool:
	if _rig == null:
		return false
	if _ragdolls.size() >= Constants.RAGDOLL_MAX:
		var oldest: Enemy = _ragdolls[0]
		if oldest._ragdoll_time < Constants.RAGDOLL_MIN_TIME:
			return false
		oldest._freeze_ragdoll()
	var away: Vector3 = _flat(global_position - source.global_position) if source else global_basis.z
	if away.length_squared() < 0.0001:
		away = global_basis.z
	var push: Vector3 = away.normalized() * Constants.RAGDOLL_PUSH * clampf(amount / 100.0, Constants.RAGDOLL_PUSH_SCALE.x, Constants.RAGDOLL_PUSH_SCALE.y)
	push += _knock + Vector3.UP * Constants.RAGDOLL_LIFT
	_knock = Vector3.ZERO
	if not _rig.start_ragdoll(push):
		return false
	_ragdoll_time = 0.0
	_ragdolls.append(self)
	return true


func _freeze_ragdoll() -> void:
	_ragdolls.erase(self)
	if _rig:
		_rig.freeze()


func _fall(delta: float) -> void:
	# A ragdoll lies where physics put it; the body would only carry its frozen pose off.
	if _rig and _rig.is_down():
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _despawn() -> void:
	_ragdolls.erase(self)
	if _rig:
		_rig.reset()
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


## The nearest lure whose pull reaches this enemy (die Resi's bell), or null. Enemies already inside the
## hut stay with the players.
func _find_lure() -> Node3D:
	# Bosses do not fall for decoys (crowd control, section 6a).
	if data.is_boss:
		return null
	var best: Node3D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("lures"):
		var lure := node as Node3D
		if lure == null or not lure.is_luring():
			continue
		# Once in through a window, a lure out in the garden (die Resi) no longer pulls it back out;
		# a cowbell thrown anywhere does.
		if _inside and not lure.pulls_inside():
			continue
		var distance: float = global_position.distance_to(lure.global_position)
		if distance <= lure.lure_radius() and distance < best_distance:
			best = lure
			best_distance = distance
	return best


func _nearest_target() -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("escorts"):
		var target := node as Node3D
		if target == null or not target.is_targetable():
			continue
		var distance: float = global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best = target
			best_distance = distance
	return best


## Its target within reach of a line (Gredn) and no wall between them: it has seen them.
func _sees_target() -> bool:
	var offset: Vector3 = _target.global_position - global_position
	if offset.length() > Constants.GREDN_REACH:
		return false
	var eyes := Vector3.UP * Constants.ENEMY_MOUTH_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(global_position + eyes, _target.global_position + eyes, Constants.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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


func _groan() -> void:
	_groan_left = randf_range(Constants.GROAN_MIN, Constants.GROAN_MAX)
	# Never a groan over a line; now and then a line instead (Gredn), if it is heard here (with the
	# chatter off the groan stays).
	if _speaking_left > 0.0:
		return
	Gredn.moment(self, Gredn.Moment.IDLE)
	if _speaking_left > 0.0:
		return
	if not data.groan_sounds.is_empty():
		Sound.play_at(data.groan_sounds.pick_random(), mouth())


## A sound from its mouth, at its voice's pitch.
func _voice(id: StringName) -> void:
	Sound.play_at(id, mouth(), 0.0, data.voice_pitch)


## It is saying a line `length` seconds long (Gredn): no groan or cry over it.
func speaking(length: float) -> void:
	_speaking_left = length
	_groan_left = maxf(_groan_left, length + Constants.GROAN_MIN)


## Where its voice comes from.
func mouth() -> Vector3:
	return global_position + Vector3.UP * Constants.ENEMY_MOUTH_HEIGHT * data.model_scale


## Hands an action to the rig (models without one, if any, just skip it).
func _pose(action: EnemyRig.Action, length: float = 1.0) -> void:
	if _rig:
		_rig.play(action, length)
	posed.emit(self, action, length)


# --- Co-op (M7): a puppet on a guest ------------------------------------------------------------

## Sends a hit on this puppet to the host. A damaging hit flashes and flinches here at once and is
## guessed against the health we know of, so the hit marker answers without waiting for the host.
func _relay(method: StringName, args: Array, damage: int = 0, is_headshot: bool = false) -> Hurtbox.Result:
	if not is_alive():
		return Hurtbox.Result.IGNORED
	if hit_relay.is_valid():
		hit_relay.call(self, method, args)
	if damage <= 0:
		return Hurtbox.Result.HIT
	_hit_flash()
	_flinch(is_headshot)
	health -= damage
	return Hurtbox.Result.KILLED if health <= 0 else Hurtbox.Result.HIT


## Where the host's enemy is now (interpolated by CoopEnemies): its feet, facing, and the lean,
## twist and hop of its Visual (x, z rotation, y offset), which carry the swings, climbs and leaps.
func puppet_move(at: Vector3, yaw: float, lean: Vector3, delta: float) -> void:
	var moved: Vector3 = _flat(at - global_position)
	velocity = moved / maxf(delta, 0.001)
	global_position = at
	rotation.y = yaw
	_visual.rotation.x = lean.x
	_visual.rotation.z = lean.y
	_visual.position.y = lean.z


## The lean, twist and hop of the Visual (x, z rotation, y offset) for the host's snapshots.
func puppet_lean() -> Vector3:
	return Vector3(_visual.rotation.x, _visual.rotation.z, _visual.position.y)


## The host's enemy started an action: the same pose here, with its sound.
func puppet_pose(action: EnemyRig.Action, length: float) -> void:
	_pose(action, length)
	match action:
		EnemyRig.Action.STRIKE, EnemyRig.Action.CROUCH:
			_voice(&"enemy_attack")
		EnemyRig.Action.CLIMB:
			Sound.play_at(&"window_climb", global_position)


## On our fork or flying off it: we move it, not the host's snapshots.
func puppet_driven() -> bool:
	return _lifted or _hurled


## Burning on the host: the flames on this puppet too.
func puppet_burn(on: bool) -> void:
	if on and _burn_fx == null:
		_burn_fx = _build_burn_fx()
	if _burn_fx and _burn_fx.emitting != on:
		_burn_fx.emitting = on


## The host's enemy was hurt by `source` (our Player, another player's hiker, or null). We already
## flashed for our own hits.
func puppet_damaged(amount: int, is_headshot: bool, source: Node3D, health_left: int, ours: bool) -> void:
	if not is_alive():
		return
	health = health_left
	if not ours:
		_hit_flash()
		_flinch(is_headshot)
	if data.treasure:
		_gold_fx().coins(_chest())
	Events.enemy_damaged.emit(self, amount, is_headshot, source)


## The host's enemy died: the same death here (ragdoll thrown away from `source`, the points event).
func puppet_killed(is_headshot: bool, is_melee: bool, source: Node3D, amount: int) -> void:
	if not is_alive():
		return
	health = 0
	if is_headshot and amount >= data.head_pop_damage:
		_pop_head()
	_die(is_headshot, is_melee, source, amount)


## The host's Venedigermandl vanished: here too.
func puppet_vanish() -> void:
	if is_alive():
		_vanish()


func _puppet_step(delta: float) -> void:
	if _hurled:
		_hurling(delta)
	_speaking_left -= delta
	_groan_left -= delta
	if _groan_left <= 0.0:
		_groan()


# --- Das Venedigermandl (M9 part 5a, EnemyData.treasure) ------------------------------------------

## He turns up: a gold spark in the air and a jingle, the banner, his glow and a marker, and he digs.
func _appear() -> void:
	_life_left = Constants.MANDL_LIFETIME
	_running = false
	_announced = false
	_giggle_left = 0.0
	if _glow == null:
		_glow = OmniLight3D.new()
		_glow.light_color = Constants.MANDL_GLOW_COLOR
		_glow.light_energy = Constants.MANDL_GLOW_ENERGY
		_glow.omni_range = Constants.MANDL_GLOW_RANGE
		_glow.position = Vector3.UP * 1.1 * data.model_scale
		_visual.add_child(_glow)
	_glow.visible = true
	if _marker:
		_marker.queue_free()
	_marker = MapMarker.new()
	_marker.text = "MARKER_MANDL"
	_marker.color = Constants.MANDL_GLOW_COLOR
	add_child(_marker)
	_gold_fx().spark(global_position + Vector3.UP * 2.0)
	Sound.play(&"mandl_jingle")
	Events.event_announced.emit(tr("EVENT_MANDL"))
	_pose(EnemyRig.Action.DIG)


## Digging until a player comes near, then off and away from the nearest, darting from side to side
## and giggling; never an attack. Only through open zones: a way with a window or a player blocker on
## it is never taken.
func _treasure(delta: float) -> void:
	_target = _nearest_target()
	var near: float = INF if _target == null else _flat(_target.global_position - global_position).length()
	if not _running and near <= Constants.MANDL_NOTICE:
		_running = true
		_repath_left = 0.0
		_giggle_left = 0.3
		_pose(EnemyRig.Action.NONE)
	elif _running and near > Constants.MANDL_CALM:
		_running = false
		_pose(EnemyRig.Action.DIG)
	if not _running:
		_halt(delta)
		return
	_giggle_left -= delta
	if _giggle_left <= 0.0:
		_giggle_left = randf_range(Constants.MANDL_GIGGLE_MIN, Constants.MANDL_GIGGLE_MAX)
		if Gredn.moment(self, Gredn.Moment.RUN) < 0 and _speaking_left <= 0.0:
			_voice(data.groan_sounds[0])
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = Constants.MANDL_REPATH
		_escape = _escape_spot()
		_agent.target_position = _escape
	var direction: Vector3 = _flat(_agent.get_next_path_position() - global_position)
	if direction.length_squared() < 0.0001:
		direction = _flat(global_position - _target.global_position)
	direction = direction.normalized()
	# Darting: mostly hard to one side, then quickly to the other.
	_dart_phase += delta * Constants.MANDL_DART_RATE * TAU
	var side := Vector3(-direction.z, 0.0, direction.x) * clampf(sin(_dart_phase) * 2.5, -1.0, 1.0)
	direction = _unstick((direction + side * Constants.MANDL_DART).normalized(), delta)
	velocity.x = direction.x * data.speed * _slow_factor
	velocity.z = direction.z * data.speed * _slow_factor
	_apply_gravity(delta)
	_face(direction, delta)
	move_and_slide()


## Where to run: of the spots a little way off in the directions away from the nearest player, the
## one farthest from every player that can be walked to without a window or a player blocker.
func _escape_spot() -> Vector3:
	var world: World3D = get_world_3d()
	var away: Vector3 = _flat(global_position - _target.global_position)
	away = away.normalized() if away.length_squared() > 0.0001 else global_basis.z
	var best: Vector3 = global_position + away * Constants.MANDL_FLEE_LOOKAHEAD
	var best_score: float = -INF
	for angle: float in Constants.MANDL_FLEE_ANGLES:
		var spot: Vector3 = NavigationServer3D.map_get_closest_point(world.navigation_map,
				global_position + away.rotated(Vector3.UP, deg_to_rad(angle)) * Constants.MANDL_FLEE_LOOKAHEAD)
		if _flat(spot - global_position).length() < Constants.MANDL_FLEE_LOOKAHEAD * 0.3:
			continue
		if not EventDirector.walkable(world, global_position, spot):
			continue
		var score: float = INF
		for node: Node in get_tree().get_nodes_in_group("player"):
			var player := node as Node3D
			if player and player.is_targetable():
				score = minf(score, player.global_position.distance_to(spot))
		score -= absf(angle) * 0.01
		if score > best_score:
			best_score = score
			best = spot
	return best


## Ten seconds are up: gone in a puff of gold dust, "Arrivederci!".
func _vanish() -> void:
	Gredn.moment(self, Gredn.Moment.VANISH)
	_gold_fx().puff(_chest())
	_treasure_gone()
	_kill_tween()
	_leave_window()
	vanished.emit(self)
	_despawn()


func _treasure_gone() -> void:
	if _glow:
		_glow.visible = false
	if _marker:
		_marker.queue_free()
		_marker = null


func _gold_fx() -> MandlGold:
	if _gold == null or not is_instance_valid(_gold):
		_gold = MandlGold.new()
		get_parent().add_child(_gold)
	return _gold


func _chest() -> Vector3:
	return global_position + Vector3.UP * 1.1 * data.model_scale


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _yaw_towards(direction: Vector3) -> float:
	# Godot models face -Z.
	return atan2(-direction.x, -direction.z)


## Damage paid out once a second for a while (the polka, burning).
class Dot:
	var left: float = 0.0
	var dps: int = 0
	var tick: float = 0.0
	var source: Node3D
