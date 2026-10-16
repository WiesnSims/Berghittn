class_name WeaponHolder
extends Node3D
## Holds the equipped gun: firing, hitscan, ammo and reload. Sits under the camera so shots follow the view.

signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal fired
## Emitted when a shot hit an enemy, for the hit marker.
signal hit_confirmed(is_headshot: bool, killed: bool)

@export var starting_weapon: WeaponData

@onready var _impact_marks: ImpactMarks = $ImpactMarks

var weapon: WeaponData
var mag: int = 0
var reserve: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _viewmodel: Viewmodel
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# The shooter's own body, so rays never hit it.
var _exclude: Array[RID] = []


func _ready() -> void:
	_rng.randomize()
	if starting_weapon:
		equip(starting_weapon)


func set_owner_body(body: CollisionObject3D) -> void:
	_exclude = [body.get_rid()]


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


func _fire_ray() -> void:
	var from: Vector3 = global_position
	var to: Vector3 = from + _spread_direction() * weapon.range
	var query := PhysicsRayQueryParameters3D.create(from, to, Constants.LAYER_WORLD | Constants.LAYER_HITBOX, _exclude)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hurtbox := hit.collider as Hurtbox
	if hurtbox:
		var result: Hurtbox.Result = hurtbox.take_hit(weapon.damage, weapon.headshot_multiplier)
		if result != Hurtbox.Result.IGNORED:
			hit_confirmed.emit(hurtbox.is_head, result == Hurtbox.Result.KILLED)
	else:
		_impact_marks.place(hit.position, hit.normal)


func _spread_direction() -> Vector3:
	var basis: Basis = global_basis
	var forward: Vector3 = -basis.z
	if weapon.spread <= 0.0:
		return forward
	# Uniform over the cone's disc, so shots do not cluster in the middle.
	var radius: float = tan(deg_to_rad(weapon.spread)) * sqrt(_rng.randf())
	var angle: float = _rng.randf() * TAU
	return (forward + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()
