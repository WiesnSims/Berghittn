class_name Huettentruhe
extends Node3D
## The mystery chest (section 6): pay, the lid flies open, the guns inside spin past faster than the
## eye can follow, one stays and floats; the buyer must take it before it sinks back in.
## Local -Z faces the player; the origin sits on the floor against the wall.

enum State { CLOSED, ROLLING, OFFERING, CLOSING }

## Emitted when a roll settles on a weapon, for tests and the HUD.
signal offered(weapon: WeaponData)

@export var pool: ChestPool
## Degrees the lid swings open.
@export var lid_open_angle: float = 105.0
## Where the weapon floats when offered, and how far below it the roll starts (local, metres).
@export var float_height: float = 1.05
@export var rise: float = 0.5
## Shown size of the guns (their viewmodels are built a little small, for the camera).
@export var display_scale: float = 1.4

## Bought with one press, not held.
var interact_repeat: float = 0.0
var state: State = State.CLOSED
## The weapon floating in the chest while OFFERING.
var offer: WeaponData
var _buyer: Player
var _time_left: float = 0.0
var _flip_left: float = 0.0
var _shown: int = -1
var _spin: float = 0.0
var _displays: Array[Node3D] = []
var _weapons: Array[WeaponData] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tween: Tween

@onready var _lid: Node3D = $LidPivot
@onready var _display: Node3D = $Display
@onready var _glow: OmniLight3D = $Glow


func _ready() -> void:
	add_to_group("interactables")
	_rng.randomize()
	_glow.visible = false
	for entry: ChestEntry in pool.entries:
		_add_display(entry.weapon)


func _add_display(weapon: WeaponData) -> void:
	# Only the gun's meshes: its viewmodel script, flash light and casings stay behind.
	var viewmodel: Node = weapon.viewmodel.instantiate()
	var model: Node3D = viewmodel.get_node("Model")
	viewmodel.remove_child(model)
	viewmodel.free()
	var flash: Node = model.get_node_or_null("MuzzleFlash")
	if flash:
		model.remove_child(flash)
		flash.free()
	model.transform = Transform3D.IDENTITY
	# Side-on to the player, muzzle to the right.
	model.rotation.y = -PI * 0.5
	# A long one (the Alphorn) is shrunk to fit the chest and centred on it.
	var bounds: AABB = _mesh_bounds(model, Transform3D.IDENTITY)
	var length: float = bounds.get_longest_axis_size() * display_scale
	var fit: float = minf(1.0, Constants.CHEST_DISPLAY_MAX_LENGTH / length) if length > 0.0 else 1.0
	model.scale = Vector3.ONE * display_scale * fit
	if fit < 1.0:
		model.position = -(model.basis * bounds.get_center())
	model.visible = false
	_display.add_child(model)
	_displays.append(model)
	_weapons.append(weapon)


## Bounds of every mesh under `node`, in the space `xf` maps it into (the node is not in the tree yet).
func _mesh_bounds(node: Node3D, xf: Transform3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for child: Node in node.get_children():
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var child_xf: Transform3D = xf * child_3d.transform
		var part := AABB()
		var mesh := child_3d as MeshInstance3D
		if mesh and mesh.mesh:
			part = child_xf * mesh.mesh.get_aabb()
			bounds = part if first else bounds.merge(part)
			first = false
		var inner: AABB = _mesh_bounds(child_3d, child_xf)
		if inner.size != Vector3.ZERO:
			bounds = inner if first else bounds.merge(inner)
			first = false
	return bounds


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return to_global(Vector3(0.0, 0.6, -1.0))


func get_interact_prompt(player: Node3D) -> String:
	var buyer := player as Player
	match state:
		State.CLOSED:
			var key: String = "UI_CHEST_BUY" if buyer.points.can_afford(pool.cost) else "UI_CHEST_NEED"
			return tr(key) % pool.cost
		State.OFFERING:
			if buyer != _buyer:
				return ""
			# A melee weapon goes into the melee slot, in place of the shovel: never a gun swap.
			var key: String = "UI_CHEST_TAKE"
			if offer.is_melee:
				key = "UI_CHEST_TAKE_MELEE"
			elif buyer.weapons.gun_count() >= Constants.GUN_SLOTS:
				key = "UI_CHEST_SWAP"
			return tr(key) % tr(offer.display_name)
	return ""


func interact(player: Node3D) -> void:
	var buyer := player as Player
	if state == State.CLOSED:
		_open(buyer)
	elif state == State.OFFERING and buyer == _buyer:
		buyer.weapons.give_weapon(offer)
		_close()


func _open(buyer: Player) -> void:
	offer = pool.pick(buyer.weapons.has_weapon, _rng)
	if offer == null or not buyer.points.spend(pool.cost):
		return
	_buyer = buyer
	state = State.ROLLING
	_time_left = pool.roll_time
	_flip_left = 0.0
	_glow.visible = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation:x", deg_to_rad(lid_open_angle), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_display, "position:y", float_height, pool.roll_time * 0.8).from(float_height - rise).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if state == State.CLOSED:
		return
	_spin += delta
	_display.rotation.y = sin(_spin * 1.6) * 0.5
	match state:
		State.ROLLING:
			_time_left -= delta
			_flip_left -= delta
			if _time_left <= 0.0:
				_settle()
			elif _flip_left <= 0.0:
				# Flips slow down towards the end, like a wheel running out.
				var progress: float = 1.0 - _time_left / pool.roll_time
				_flip_left = lerpf(0.06, 0.32, progress * progress)
				_show((_shown + 1 + _rng.randi() % maxi(_displays.size() - 1, 1)) % _displays.size())
		State.OFFERING:
			_time_left -= delta
			_display.position.y = float_height + sin(_spin * 3.0) * 0.03
			if _time_left <= 0.0:
				# Not taken: it sinks back in and is gone.
				_close()


func _settle() -> void:
	state = State.OFFERING
	_time_left = pool.offer_time
	_show(_weapons.find(offer))
	offered.emit(offer)


func _close() -> void:
	state = State.CLOSING
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_display, "position:y", float_height - rise, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_show.bind(-1))
	_tween.tween_property(_lid, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_closed)


func _closed() -> void:
	state = State.CLOSED
	offer = null
	_buyer = null
	_glow.visible = false


func _show(index: int) -> void:
	for i: int in _displays.size():
		_displays[i].visible = i == index
	_shown = index


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
