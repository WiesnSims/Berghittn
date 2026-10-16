class_name WeaponHolder
extends Node3D
## Holds the guns (two slots, section 6: firing, hitscan, ammo, reload, switching) and the melee weapon
## for quick melee on V. Sits under the camera so shots follow the view.

signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal fired
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
var mag: int = 0
var reserve: int = 0
var _slots: Array[GunSlot] = []
var _current: int = -1
var _cooldown: float = 0.0
var _reload_left: float = 0.0
# What the running reload fills the gun to.
var _reload_target: int = 0
var _switch_left: float = 0.0
# Seconds until the gun is back up after a sprint and may fire.
var _sprint_left: float = 0.0
var _viewmodel: Viewmodel
var _melee_viewmodel: MeleeViewmodel
# Seconds left of the current swing, and until its blow lands (negative once it has).
var _melee_left: float = 0.0
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
	return _slot_of(data) >= 0


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


func gun_count() -> int:
	return _slots.size()


func is_reloading() -> bool:
	return _reload_left > 0.0


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
	# Reloading on the run is fine, shooting is not: the gun is lowered until the sprint ends.
	var player := _shooter as Player
	if player and player.is_sprinting():
		_sprint_left = Constants.SPRINT_TO_FIRE_TIME
	else:
		_sprint_left = maxf(_sprint_left - delta, 0.0)
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
	var wants_fire: bool = Input.is_action_pressed("fire") if weapon.is_auto else Input.is_action_just_pressed("fire")
	if wants_fire and _cooldown <= 0.0:
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
	# Empty mag means the slide is locked back: chamber a round after the new mag is in.
	var chamber: float = weapon.chamber_time if mag == 0 else 0.0
	_reload_left = weapon.reload_time + chamber
	reload_started.emit(_reload_left)
	if _viewmodel:
		_viewmodel.play_reload(weapon.reload_time, chamber)


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
	mag = slot.mag
	reserve = slot.reserve
	_viewmodel = slot.viewmodel
	_cooldown = 0.0
	_switch_left = Constants.WEAPON_SWITCH_TIME
	if _viewmodel:
		_viewmodel.visible = true
		_viewmodel.play_raise(Constants.WEAPON_SWITCH_TIME)
	weapon_changed.emit(weapon)
	ammo_changed.emit(mag, reserve)


func _fire() -> void:
	mag -= 1
	_cooldown = 1.0 / weapon.fire_rate
	# Pellets that hit the same enemy land as one hit: one flinch, one hit marker and one set of
	# points per shot, not one per pellet.
	var hits: Dictionary = {}
	for i: int in weapon.pellets:
		_fire_ray(hits)
	for receiver: Node in hits:
		var hit: Dictionary = hits[receiver]
		var result: Hurtbox.Result = receiver.receive_hit(hit.amount, hit.head, false, _shooter)
		if result != Hurtbox.Result.IGNORED:
			_hit_puffs.play(hit.position, hit.normal)
			hit_confirmed.emit(hit.head, result == Hurtbox.Result.KILLED)
	fired.emit()
	ammo_changed.emit(mag, reserve)
	if _viewmodel:
		_viewmodel.play_fire()


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
		var result: Hurtbox.Result = hurtbox.take_hit(melee_weapon.damage, melee_weapon.headshot_multiplier, true, _shooter)
		if result != Hurtbox.Result.IGNORED:
			_hit_puffs.play(target, -to_target.normalized())
			hit_confirmed.emit(false, result == Hurtbox.Result.KILLED)


func _cast(offset: Vector3, mask: int = Constants.LAYER_WORLD | Constants.LAYER_HITBOX) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + offset, mask, _exclude)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() else {"collider": null}


func _fire_ray(hits: Dictionary) -> void:
	var hit: Dictionary = _cast(_spread_direction() * weapon.range)
	if hit.collider == null:
		return
	var hurtbox := hit.collider as Hurtbox
	if hurtbox == null:
		_impact_marks.place(hit.position, hit.normal)
		_impact_puffs.play(hit.position, hit.normal)
		return
	var amount: int = hurtbox.damage_for(weapon.damage, weapon.headshot_multiplier)
	var total: Dictionary = hits.get(hurtbox.receiver, {"amount": 0, "head": false})
	total.amount += amount
	total.head = total.head or hurtbox.is_head
	total.position = hit.position
	total.normal = hit.normal
	hits[hurtbox.receiver] = total


func _spread_direction() -> Vector3:
	var basis: Basis = global_basis
	var forward: Vector3 = -basis.z
	if weapon.spread <= 0.0:
		return forward
	# Uniform over the cone's disc, so shots do not cluster in the middle.
	var radius: float = tan(deg_to_rad(weapon.spread)) * sqrt(_rng.randf())
	var angle: float = _rng.randf() * TAU
	return (forward + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()
