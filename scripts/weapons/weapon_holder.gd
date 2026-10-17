class_name WeaponHolder
extends Node3D
## Holds the guns (two slots, section 6: firing, hitscan, ammo, reload, switching) and the melee weapon
## for quick melee on V. Sits under the camera so shots follow the view.

signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
## A shot went off; `rounds` > 1 when several went at once (both barrels).
signal fired(rounds: int)
## The gun in hand changed (switch, buy, replace).
signal weapon_changed(data: WeaponData)
## Emitted when a shot hit an enemy, for the hit marker.
signal hit_confirmed(is_headshot: bool, killed: bool)

## One carried gun and the ammo it had when it was put away.
class GunSlot:
	var data: WeaponData
	var mag: int
	var reserve: int
	var viewmodel: Viewmodel
	## What a shot does for a special weapon (section 6a); null for plain hitscan.
	var behavior: WeaponBehavior

@export var starting_weapon: WeaponData
## Always carried (section 6: the shovel until the melee slot gets replaced).
@export var melee_weapon: WeaponData

@onready var _impact_marks: ImpactMarks = $ImpactMarks
@onready var _impact_puffs: EffectPool = $ImpactPuffs
@onready var _hit_puffs: EffectPool = $HitPuffs
# Every viewmodel hangs under this, so walking, sprinting and looking move them all.
@onready var _motion: WeaponMotion = $Motion

## The gun in hand and its ammo; written back to its slot when it is put away.
var weapon: WeaponData
## Extra spread (degrees) from shots fired in quick succession; see WeaponData bloom_*.
var bloom: float = 0.0
## 0 = hip fire, 1 = fully aimed (down the sights or through the scope).
var aim_amount: float = 0.0
## Holds right click without a mouse, for tests and capture tools.
var force_aim: bool = false
var mag: int = 0
var reserve: int = 0
var _slots: Array[GunSlot] = []
var _current: int = -1
var _cooldown: float = 0.0
# How long the current cooldown and reload are in all, for the ready ring at the crosshair.
var _cooldown_total: float = 0.0
var _reload_total: float = 0.0
# A click that came in while the gun was still cycling; it fires as soon as it can, so fast clicking
# is never swallowed.
var _fire_buffer_left: float = 0.0
var _reload_left: float = 0.0
# What the running reload fills the gun to.
var _reload_target: int = 0
var _switch_left: float = 0.0
# Seconds until the gun is back up after a sprint and may fire.
var _sprint_left: float = 0.0
var _aiming: bool = false
# Right click held on a gun that fans its action (FAN secondary).
var _fanning: bool = false
var _viewmodel: Viewmodel
var _behavior: WeaponBehavior
var _melee_viewmodel: MeleeViewmodel
# Seconds left of the current swing, and until its blow lands (negative once it has).
var _melee_left: float = 0.0
# Holding the melee weapon up as a guard (BLOCK secondary), and a hold of V without a keyboard for tests.
var _blocking: bool = false
var force_melee_hold: bool = false
var _melee_hit_in: float = -1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# The shooter's own body, so rays never hit it, and who gets the points.
var _exclude: Array[RID] = []
var _shooter: Node3D


func _ready() -> void:
	_rng.randomize()
	if starting_weapon:
		give_weapon(starting_weapon)
		# Already in hand at the start, not drawn.
		_switch_left = 0.0
	if melee_weapon and melee_weapon.viewmodel:
		_melee_viewmodel = melee_weapon.viewmodel.instantiate() as MeleeViewmodel
		_motion.add_child(_melee_viewmodel)


func set_owner_body(body: CollisionObject3D) -> void:
	_exclude = [body.get_rid()]
	_shooter = body


## Puts a gun in hand: into a free slot if there is one, otherwise in place of the gun in hand.
## Handed over ready to fire, chambered and with full reserve.
func give_weapon(data: WeaponData) -> void:
	if data.is_melee:
		set_melee(data)
		return
	var owned: int = _slot_of(data)
	if owned >= 0:
		_select(owned)
		return
	var slot := GunSlot.new()
	slot.data = data
	slot.mag = data.loaded_capacity(true)
	slot.reserve = data.reserve_ammo
	if data.viewmodel:
		# Built once per gun and kept: instancing on every switch would hitch in the middle of a fight.
		slot.viewmodel = data.viewmodel.instantiate() as Viewmodel
		slot.viewmodel.visible = false
		_motion.add_child(slot.viewmodel)
	slot.behavior = WeaponBehavior.create(data, self)
	if _slots.size() < Constants.GUN_SLOTS:
		_slots.append(slot)
		_select(_slots.size() - 1)
		return
	var old: GunSlot = _slots[_current]
	if old.viewmodel:
		old.viewmodel.queue_free()
	_slots[_current] = slot
	_current = -1
	_select(_slots.find(slot))


func has_weapon(data: WeaponData) -> bool:
	if data.is_melee:
		return melee_weapon != null and melee_weapon.id == data.id
	return _slot_of(data) >= 0


## Puts a melee weapon in the melee slot (section 6), in place of the one carried (the shovel).
func set_melee(data: WeaponData) -> void:
	_end_block()
	_melee_left = 0.0
	_melee_hit_in = -1.0
	if _melee_viewmodel:
		_melee_viewmodel.queue_free()
		_melee_viewmodel = null
	melee_weapon = data
	if data.viewmodel:
		_melee_viewmodel = data.viewmodel.instantiate() as MeleeViewmodel
		_motion.add_child(_melee_viewmodel)


## Holding the melee weapon up as a guard right now. Walking slows down; guns cannot fire.
func is_blocking() -> bool:
	return _blocking


## A hit is coming in from `attacker`: true when the guard is up and faces it, so the hit is caught
## (block_share of it still gets through) and the attacker is bonked back.
func block(attacker: Node3D) -> bool:
	if not _blocking or attacker == null:
		return false
	var to: Vector3 = attacker.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var forward := Vector3(-global_basis.z.x, 0.0, -global_basis.z.z).normalized()
	if flat.length() > 0.05 and flat.normalized().dot(forward) < cos(deg_to_rad(melee_weapon.block_angle)):
		return false
	var enemy := attacker as Enemy
	if enemy and enemy.is_alive():
		enemy.apply_knockback(flat.normalized() * melee_weapon.secondary_knockback * sqrt(enemy.data.flinch_multiplier))
	_hit_puffs.play(global_position + forward * 0.5 + Vector3.DOWN * 0.3, -forward)
	_show_hit_text(global_position + forward * 0.8)
	if _melee_viewmodel:
		_melee_viewmodel.play_bonk()
	var player := _shooter as Player
	if player:
		player.kick_view(3.0, 1.5)
	return true


## True when the gun is carried and its reserve is not full, so buying ammo would do something.
func needs_ammo(data: WeaponData) -> bool:
	var index: int = _slot_of(data)
	if index < 0:
		return false
	var spare: int = reserve if index == _current else _slots[index].reserve
	return spare < data.reserve_ammo


func refill_ammo(data: WeaponData) -> void:
	var index: int = _slot_of(data)
	if index < 0:
		return
	_slots[index].reserve = data.reserve_ammo
	if index == _current:
		reserve = data.reserve_ammo
		ammo_changed.emit(mag, reserve)


## The gun in hand topped up completely, magazine and reserve (the Murmeltier's reward).
func refill_current() -> void:
	if weapon == null:
		return
	_cancel_reload()
	mag = maxi(mag, weapon.mag_size)
	refill_ammo(weapon)
	ammo_changed.emit(mag, reserve)


## True when any carried gun is short of reserve ammo (the Lager's ammo crate).
func needs_any_ammo() -> bool:
	return _slots.any(func(slot: GunSlot) -> bool: return needs_ammo(slot.data))


func refill_all() -> void:
	for slot: GunSlot in _slots:
		refill_ammo(slot.data)


func gun_count() -> int:
	return _slots.size()


func is_reloading() -> bool:
	return _reload_left > 0.0


## Share of the running reload done (0..1), or -1 when not reloading.
func reload_progress() -> float:
	return 1.0 - _reload_left / _reload_total if is_reloading() and _reload_total > 0.0 else -1.0


## Share of the gun's cycle after a shot done (0..1), or -1 when it is ready to fire again.
func cycle_progress() -> float:
	return 1.0 - _cooldown / _cooldown_total if _cooldown > 0.0 and _cooldown_total > 0.0 else -1.0


## Aiming right now (right click held on a gun that aims). Movement slows down and sprint is off.
func is_aiming() -> bool:
	return _aiming


## Looking through the scope: the overlay is up and the gun model is out of the way.
func is_scoped() -> bool:
	return weapon != null and weapon.secondary == WeaponData.Secondary.SCOPE and aim_amount >= Constants.SCOPE_SHOW_AT


## Fanning the action right now (FAN secondary): faster, wilder shots that kick harder.
func is_fanning() -> bool:
	return _fanning


## Cone half-angle in degrees the next shot can stray: base spread plus bloom, tightened by aiming.
func current_spread() -> float:
	return (weapon.spread + bloom + _fan_spread()) * lerpf(1.0, weapon.aim_spread_multiplier, aim_amount)


## Bloom as it would widen the next shot (aiming tightens it like the base spread), for the crosshair.
## Fanning counts as bloom, so the crosshair shows how wild it gets.
func current_bloom() -> float:
	return (bloom + _fan_spread()) * lerpf(1.0, weapon.aim_spread_multiplier, aim_amount)


func _fan_spread() -> float:
	return weapon.rapid_spread if _fanning else 0.0


## Aim blend eased, for the camera zoom and the gun pose.
func aim_eased() -> float:
	return smoothstep(0.0, 1.0, aim_amount)


func _unhandled_input(event: InputEvent) -> void:
	# Here and not in _physics_process: wheel "presses" are released in the same frame and would be missed.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _melee_left > 0.0 or _slots.size() < 2:
		return
	if event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_previous"):
		_select((_current + 1) % _slots.size())
	elif event.is_action_pressed("weapon_slot_1"):
		_select(0)
	elif event.is_action_pressed("weapon_slot_2"):
		_select(1)


func _physics_process(delta: float) -> void:
	if weapon == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	bloom = move_toward(bloom, 0.0, weapon.bloom_recover * delta)
	# Set again below once the hands are free to work the action.
	_fanning = false
	# Reloading on the run is fine, shooting is not: the gun is lowered until the sprint ends.
	var player := _shooter as Player
	if player and player.is_sprinting():
		_sprint_left = Constants.SPRINT_TO_FIRE_TIME
	else:
		_sprint_left = maxf(_sprint_left - delta, 0.0)
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_update_aim(delta, force_aim or (captured and Input.is_action_pressed("secondary")))
	if _blocking:
		if not _melee_held():
			_end_block()
		return
	if _melee_left > 0.0:
		_update_melee(delta)
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("melee") and melee_weapon:
		_start_melee()
		return
	if _switch_left > 0.0:
		_switch_left -= delta
		return
	if is_reloading():
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed("reload"):
		start_reload()
		return
	if _sprint_left > 0.0:
		return
	_fanning = weapon.secondary == WeaponData.Secondary.FAN and (force_aim or Input.is_action_pressed("secondary"))
	if _fanning:
		if _cooldown <= 0.0:
			if mag > 0:
				_fire()
			else:
				start_reload()
		return
	if weapon.secondary == WeaponData.Secondary.ALL_BARRELS and Input.is_action_just_pressed("secondary") and _cooldown <= 0.0:
		if mag > 0:
			fire_all()
		else:
			start_reload()
		return
	if weapon.secondary == WeaponData.Secondary.BEHAVIOR and Input.is_action_just_pressed("secondary") and _cooldown <= 0.0:
		if mag >= weapon.secondary_rounds:
			fire_secondary()
		else:
			start_reload()
		return
	if Input.is_action_just_pressed("fire"):
		_fire_buffer_left = Constants.FIRE_BUFFER_TIME
	else:
		_fire_buffer_left = maxf(_fire_buffer_left - delta, 0.0)
	# Semi-auto fires once per click, as fast as the clicks come (up to fire_rate).
	var wants_fire: bool = Input.is_action_pressed("fire") if weapon.is_auto else _fire_buffer_left > 0.0
	if wants_fire and _cooldown <= 0.0:
		_fire_buffer_left = 0.0
		if mag > 0:
			_fire()
		else:
			# Pulling the trigger on an empty mag is the most common way players "ask" for a reload.
			start_reload()


func start_reload() -> void:
	# With rounds left, one stays in the chamber on top of the new mag.
	var target: int = weapon.loaded_capacity(mag > 0)
	if is_reloading() or mag >= target or reserve <= 0:
		return
	_reload_target = target
	if mag == 0 and _perks():
		_perks().on_empty_reload()
	# Empty mag means the slide is locked back: chamber a round after the new mag is in.
	var speed: float = _perks().reload_time_multiplier() if _perks() else 1.0
	var chamber: float = weapon.chamber_time * speed if mag == 0 else 0.0
	_reload_left = weapon.reload_time * speed + chamber
	_reload_total = _reload_left
	reload_started.emit(_reload_left)
	if _viewmodel:
		_viewmodel.play_reload(weapon.reload_time * speed, chamber)


func _finish_reload() -> void:
	_reload_left = 0.0
	var moved: int = mini(_reload_target - mag, reserve)
	mag += moved
	reserve -= moved
	reload_finished.emit()
	ammo_changed.emit(mag, reserve)


func _cancel_reload() -> void:
	if is_reloading():
		_reload_left = 0.0
		reload_finished.emit()


func _perks() -> PlayerPerks:
	var player := _shooter as Player
	return player.perks if player else null


## Damage after perks and the Brettljause.
func _damage(base: int) -> int:
	return roundi(base * _perks().damage_multiplier()) if _perks() else base


func _slot_of(data: WeaponData) -> int:
	for i: int in _slots.size():
		if _slots[i].data.id == data.id:
			return i
	return -1


func _select(index: int) -> void:
	if index == _current or index < 0 or index >= _slots.size():
		return
	# A switch drops a running reload, like in every shooter: the mag swap starts over next time.
	_cancel_reload()
	if _current >= 0 and _current < _slots.size():
		var old: GunSlot = _slots[_current]
		old.mag = mag
		old.reserve = reserve
		if old.viewmodel:
			old.viewmodel.visible = false
	_current = index
	var slot: GunSlot = _slots[index]
	weapon = slot.data
	bloom = 0.0
	mag = slot.mag
	reserve = slot.reserve
	_viewmodel = slot.viewmodel
	_behavior = slot.behavior
	_cooldown = 0.0
	_switch_left = Constants.WEAPON_SWITCH_TIME
	if _viewmodel:
		_viewmodel.visible = true
		_viewmodel.play_raise(Constants.WEAPON_SWITCH_TIME)
	weapon_changed.emit(weapon)
	ammo_changed.emit(mag, reserve)


## Both barrels (ALL_BARRELS secondary): every loaded round in one blast.
func fire_all() -> void:
	_fire(mag)


## A special weapon's own second shot (BEHAVIOR secondary), using secondary_rounds at once.
func fire_secondary() -> void:
	var rounds: int = weapon.secondary_rounds
	if _behavior == null or mag < rounds:
		return
	mag -= rounds
	_set_cooldown(1.0 / weapon.fire_rate)
	_behavior.fire_secondary()
	fired.emit(rounds)
	ammo_changed.emit(mag, reserve)
	if _viewmodel:
		_viewmodel.play_secondary(rounds)


## Area hit for behaviors (section 6a): every enemy (or other hit receiver) whose body is within
## `reach` metres and `half_angle` degrees of the aim, with a clear line from the muzzle, takes `amount`
## (before perks), and enemies that survive are thrown back; 180 degrees is all around. Returns how
## many were hit.
func blast(half_angle: float, reach: float, amount: int, push: float) -> int:
	var sphere := SphereShape3D.new()
	sphere.radius = reach + Constants.AREA_BODY_MARGIN
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = Constants.LAYER_HITBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var forward: Vector3 = -global_basis.z
	var min_dot: float = cos(deg_to_rad(half_angle))
	var struck: Dictionary = {}
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, Constants.AREA_MAX_TARGETS):
		var hurtbox := found.collider as Hurtbox
		# Body boxes: one hit per receiver, and a sound wave has no headshots.
		if hurtbox == null or hurtbox.is_head or struck.has(hurtbox.receiver):
			continue
		var target: Vector3 = hurtbox.global_position + Vector3.UP * Constants.AREA_AIM_HEIGHT * hurtbox.scale.y
		var to_target: Vector3 = target - global_position
		var distance: float = to_target.length()
		if distance > reach + Constants.AREA_BODY_MARGIN:
			continue
		# A body right next to the muzzle counts even if its middle is just outside the cone.
		var off_axis: float = (to_target - forward * to_target.dot(forward)).length()
		if half_angle < 180.0 and to_target.normalized().dot(forward) < min_dot and not (to_target.dot(forward) > 0.0 and off_axis < Constants.AREA_BODY_MARGIN):
			continue
		# Walls stop it; the window openings themselves do not.
		if _cast(to_target, Constants.LAYER_WORLD).collider != null:
			continue
		struck[hurtbox.receiver] = true
		var result: Hurtbox.Result = hurtbox.take_hit(_damage(amount), 1.0, false, _shooter)
		if result == Hurtbox.Result.IGNORED:
			continue
		_hit_puffs.play(target, -to_target.normalized())
		hit_confirmed.emit(false, result == Hurtbox.Result.KILLED)
		var enemy := hurtbox.receiver as Enemy
		if enemy and enemy.is_alive():
			var flat := Vector3(to_target.x, 0.0, to_target.z)
			var away: Vector3 = flat.normalized() if flat.length() > 0.05 else Vector3(forward.x, 0.0, forward.z).normalized()
			var falloff: float = lerpf(1.0, 0.5, clampf(distance / reach, 0.0, 1.0))
			# Heavy bodies are shoved less, but still visibly: by the root of how much they flinch.
			enemy.apply_knockback(away * push * falloff * sqrt(enemy.data.flinch_multiplier))
	return struck.size()


## A jolt of the shooter's view that is not recoil (a blast going off).
func shake_view(degrees: float) -> void:
	var player := _shooter as Player
	if player and degrees > 0.0:
		player.shake_view(degrees)


## Puts a short-lived effect into the world where the camera is, looking along the aim.
func add_effect(effect: Node3D) -> void:
	effect.transform = global_transform
	_shooter.get_parent().add_child(effect)


func _update_aim(delta: float, held: bool) -> void:
	# Reloading, switching or swinging the shovel drops the aim; it comes back once the hands are free.
	_aiming = held and weapon != null and weapon.can_aim() and not is_reloading() and _switch_left <= 0.0 and _melee_left <= 0.0 and not _blocking
	var speed: float = 1.0 / weapon.aim_time if weapon and weapon.aim_time > 0.0 else 1.0 / Constants.WEAPON_SWITCH_TIME
	aim_amount = move_toward(aim_amount, 1.0 if _aiming else 0.0, speed * delta)
	if _viewmodel:
		_viewmodel.set_aim(aim_eased())
		# Out of the way behind the scope, and down while a melee guard is up.
		_viewmodel.visible = not is_scoped() and not _blocking


func _fire(rounds: int = 1) -> void:
	rounds = mini(rounds, mag)
	mag -= rounds
	bloom = minf(bloom + weapon.bloom_per_shot * rounds, weapon.bloom_max)
	_set_cooldown(1.0 / (weapon.rapid_fire_rate if _fanning else weapon.fire_rate))
	# Pellets that hit the same enemy land as one hit: one flinch, one hit marker and one set of
	# points per shot, not one per pellet.
	if _behavior:
		_behavior.fire(rounds)
		_after_shot(rounds)
		return
	var hits: Dictionary = {}
	for i: int in weapon.pellets * rounds:
		_fire_ray(hits)
	for receiver: Node in hits:
		var hit: Dictionary = hits[receiver]
		var result: Hurtbox.Result = receiver.receive_hit(hit.amount, hit.head, false, _shooter)
		if result != Hurtbox.Result.IGNORED:
			_hit_puffs.play(hit.position, hit.normal)
			hit_confirmed.emit(hit.head, result == Hurtbox.Result.KILLED)
	_after_shot(rounds)


func _after_shot(rounds: int) -> void:
	fired.emit(rounds)
	ammo_changed.emit(mag, reserve)
	if _viewmodel:
		_viewmodel.play_fire(rounds)


func _set_cooldown(time: float) -> void:
	_cooldown = time
	_cooldown_total = time


func _start_melee() -> void:
	# A swing cancels a running reload: in a panic the shovel must always come out.
	_cancel_reload()
	_melee_left = 1.0 / melee_weapon.fire_rate
	_melee_hit_in = _melee_left * Constants.MELEE_HIT_FRACTION
	if _viewmodel:
		_viewmodel.play_lower(_melee_left)
	if _melee_viewmodel:
		_melee_viewmodel.play_swing(_melee_left, _melee_hit_in)


func _update_melee(delta: float) -> void:
	_melee_left -= delta
	if _melee_hit_in >= 0.0:
		_melee_hit_in -= delta
		if _melee_hit_in < 0.0:
			_melee_hit()
			# Still holding V after the blow: the weapon stays up as a guard.
			if melee_weapon.secondary == WeaponData.Secondary.BLOCK and _melee_held():
				_start_block()


func _melee_held() -> bool:
	return force_melee_hold or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("melee"))


func _start_block() -> void:
	_blocking = true
	_melee_left = 0.0
	# The gun stays down for as long as the guard is up.
	if _viewmodel:
		_viewmodel.visible = false
	if _melee_viewmodel:
		_melee_viewmodel.play_guard()


func _end_block() -> void:
	if not _blocking:
		return
	_blocking = false
	if _melee_viewmodel:
		_melee_viewmodel.end_guard()
	_switch_left = Constants.BLOCK_LOWER_TIME
	if _viewmodel:
		_viewmodel.visible = true
		_viewmodel.play_raise(Constants.BLOCK_LOWER_TIME)


## A comic word where a blow lands (WeaponData.hit_text), floating up and fading.
func _show_hit_text(at: Vector3) -> void:
	if melee_weapon.hit_text == "":
		return
	var label := Label3D.new()
	label.text = tr(melee_weapon.hit_text)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = 0.004
	label.modulate = Color(1.0, 0.85, 0.3)
	label.outline_modulate = Color(0.25, 0.1, 0.05)
	_shooter.get_parent().add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position", at + Vector3.UP * 0.6, Constants.HIT_TEXT_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, Constants.HIT_TEXT_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _melee_hit() -> void:
	# The swing sweeps an arc in front of the player and hits every enemy in it, once each.
	var sphere := SphereShape3D.new()
	sphere.radius = melee_weapon.range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = Constants.LAYER_HITBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var forward: Vector3 = -global_basis.z
	var min_dot: float = cos(deg_to_rad(Constants.MELEE_ARC_DEGREES * 0.5))
	var struck: Dictionary = {}
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, Constants.MELEE_MAX_TARGETS):
		var hurtbox := found.collider as Hurtbox
		# Body boxes only: one blow per enemy, and a shovel does not do headshots.
		if hurtbox == null or hurtbox.is_head or struck.has(hurtbox.receiver):
			continue
		var target: Vector3 = hurtbox.global_position + Vector3.UP * Constants.MELEE_AIM_HEIGHT
		var to_target: Vector3 = target - global_position
		# Flattened, so an enemy right in front still counts when the player looks down at it.
		var flat := Vector3(to_target.x, 0.0, to_target.z)
		var flat_forward := Vector3(forward.x, 0.0, forward.z)
		if flat.length() > 0.2 and flat.normalized().dot(flat_forward.normalized()) < min_dot:
			continue
		# No hitting through walls; the window openings themselves are fine.
		var line: Dictionary = _cast(to_target, Constants.LAYER_WORLD)
		if line.collider != null:
			continue
		struck[hurtbox.receiver] = true
		var result: Hurtbox.Result = hurtbox.take_hit(_damage(melee_weapon.damage), melee_weapon.headshot_multiplier, true, _shooter)
		if result != Hurtbox.Result.IGNORED:
			_hit_puffs.play(target, -to_target.normalized())
			hit_confirmed.emit(false, result == Hurtbox.Result.KILLED)
			_show_hit_text(target)
			var enemy := hurtbox.receiver as Enemy
			if enemy and enemy.is_alive() and melee_weapon.knockback > 0.0:
				enemy.apply_knockback(flat.normalized() * melee_weapon.knockback * sqrt(enemy.data.flinch_multiplier))


func _cast(offset: Vector3, mask: int = Constants.LAYER_WORLD | Constants.LAYER_HITBOX) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + offset, mask, _exclude)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() else {"collider": null}


func _fire_ray(hits: Dictionary) -> void:
	# One ray, re-cast past every enemy it goes through (penetration) until it stops in one or a wall.
	var offset: Vector3 = _spread_direction() * weapon.range
	var exclude: Array[RID] = _exclude.duplicate()
	var share: float = 1.0
	var pierced: int = 0
	var extra_pierce: int = _perks().extra_penetration() if _perks() else 0
	var last: Node = null
	for i: int in Constants.MAX_RAY_STEPS:
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + offset, Constants.LAYER_WORLD | Constants.LAYER_HITBOX, exclude)
		query.collide_with_areas = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return
		var hurtbox := hit.collider as Hurtbox
		if hurtbox == null:
			_impact_marks.place(hit.position, hit.normal)
			_impact_puffs.play(hit.position, hit.normal)
			return
		exclude.append(hurtbox.get_rid())
		# The ray can cross both boxes (head and body) of one enemy: that is still one body.
		if hurtbox.receiver == last:
			continue
		last = hurtbox.receiver
		var amount: int = roundi(hurtbox.damage_for(_damage(weapon.damage), weapon.headshot_multiplier) * share)
		var total: Dictionary = hits.get(hurtbox.receiver, {"amount": 0, "head": false})
		total.amount += amount
		total.head = total.head or hurtbox.is_head
		total.position = hit.position
		total.normal = hit.normal
		hits[hurtbox.receiver] = total
		pierced += 1
		if pierced > weapon.penetration + extra_pierce:
			return
		if weapon.penetration_range > 0.0 and global_position.distance_to(hit.position) > weapon.penetration_range:
			return
		share *= weapon.penetration_falloff


func _spread_direction() -> Vector3:
	var basis: Basis = global_basis
	var forward: Vector3 = -basis.z
	var spread: float = current_spread()
	if spread <= 0.0:
		return forward
	# Uniform over the cone's disc, so shots do not cluster in the middle.
	var radius: float = tan(deg_to_rad(spread)) * sqrt(_rng.randf())
	var angle: float = _rng.randf() * TAU
	return (forward + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()
