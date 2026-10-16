class_name WeaponHolder
extends Node3D
## Holds the equipped gun (firing, hitscan, ammo, reload) and the melee weapon for quick melee on V.
## Sits under the camera so shots follow the view.

signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal fired
## Emitted when a shot hit an enemy, for the hit marker.
signal hit_confirmed(is_headshot: bool, killed: bool)

@export var starting_weapon: WeaponData
## Always carried (section 6: the shovel until the melee slot gets replaced).
@export var melee_weapon: WeaponData

@onready var _impact_marks: ImpactMarks = $ImpactMarks
@onready var _impact_puffs: EffectPool = $ImpactPuffs
@onready var _hit_puffs: EffectPool = $HitPuffs

var weapon: WeaponData
var mag: int = 0
var reserve: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
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
		equip(starting_weapon)
	if melee_weapon and melee_weapon.viewmodel:
		_melee_viewmodel = melee_weapon.viewmodel.instantiate() as MeleeViewmodel
		add_child(_melee_viewmodel)


func set_owner_body(body: CollisionObject3D) -> void:
	_exclude = [body.get_rid()]
	_shooter = body


func equip(data: WeaponData) -> void:
	if _viewmodel:
		_viewmodel.queue_free()
		_viewmodel = null
	weapon = data
	mag = data.mag_size
	reserve = data.reserve_ammo
	_cooldown = 0.0
	_reload_left = 0.0
	if data.viewmodel:
		_viewmodel = data.viewmodel.instantiate() as Viewmodel
		add_child(_viewmodel)
	ammo_changed.emit(mag, reserve)


func is_reloading() -> bool:
	return _reload_left > 0.0


func _physics_process(delta: float) -> void:
	if weapon == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _melee_left > 0.0:
		_update_melee(delta)
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("melee") and melee_weapon:
		_start_melee()
		return
	if is_reloading():
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var wants_fire: bool = Input.is_action_pressed("fire") if weapon.is_auto else Input.is_action_just_pressed("fire")
	if Input.is_action_just_pressed("reload"):
		start_reload()
	elif wants_fire and _cooldown <= 0.0:
		if mag > 0:
			_fire()
		else:
			# Pulling the trigger on an empty mag is the most common way players "ask" for a reload.
			start_reload()


func start_reload() -> void:
	if is_reloading() or mag >= weapon.mag_size or reserve <= 0:
		return
	# Empty mag means the slide is locked back: chamber a round after the new mag is in.
	var chamber: float = weapon.chamber_time if mag == 0 else 0.0
	_reload_left = weapon.reload_time + chamber
	reload_started.emit(_reload_left)
	if _viewmodel:
		_viewmodel.play_reload(weapon.reload_time, chamber)


func _finish_reload() -> void:
	_reload_left = 0.0
	var moved: int = mini(weapon.mag_size - mag, reserve)
	mag += moved
	reserve -= moved
	reload_finished.emit()
	ammo_changed.emit(mag, reserve)


func _fire() -> void:
	mag -= 1
	_cooldown = 1.0 / weapon.fire_rate
	for i: int in weapon.pellets:
		_fire_ray()
	fired.emit()
	ammo_changed.emit(mag, reserve)
	if _viewmodel:
		_viewmodel.play_fire()


func _start_melee() -> void:
	# A swing cancels a running reload: in a panic the shovel must always come out.
	if is_reloading():
		_reload_left = 0.0
		reload_finished.emit()
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


func _fire_ray() -> void:
	var hit: Dictionary = _cast(_spread_direction() * weapon.range)
	if hit.collider == null:
		return
	var hurtbox := hit.collider as Hurtbox
	if hurtbox:
		var result: Hurtbox.Result = hurtbox.take_hit(weapon.damage, weapon.headshot_multiplier, false, _shooter)
		if result != Hurtbox.Result.IGNORED:
			_hit_puffs.play(hit.position, hit.normal)
			hit_confirmed.emit(hurtbox.is_head, result == Hurtbox.Result.KILLED)
	else:
		_impact_marks.place(hit.position, hit.normal)
		_impact_puffs.play(hit.position, hit.normal)


func _spread_direction() -> Vector3:
	var basis: Basis = global_basis
	var forward: Vector3 = -basis.z
	if weapon.spread <= 0.0:
		return forward
	# Uniform over the cone's disc, so shots do not cluster in the middle.
	var radius: float = tan(deg_to_rad(weapon.spread)) * sqrt(_rng.randf())
	var angle: float = _rng.randf() * TAU
	return (forward + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()
