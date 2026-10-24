class_name Dengelstock
extends Node3D
## Da Dengelstock (M9 part 4, GAME_DESIGN section 12): the Schmied's corner up in the Holzschuppen's
## hay loft, a forge on a stone slab under a sheet-metal hood, an anvil on its stump and a grindstone.
## Cold until wave DENGEL_WAVE ("Da Schmied is wieder nüchtern!"), then open for the rest of the match.
## At the anvil a player hands over the gun in their hand, at the grindstone their melee weapon; the
## hammer works it for DENGEL_TIME, then the forged weapon floats over the anvil for DENGEL_WAIT for
## them to take, or it is gone. One weapon at a time.
## Local -Z faces the player; the origin sits on the loft floor in front of the forge.
## Co-op (M7): the host's word on who is at the anvil, as with the Hüttentruhe (CoopWorld).

enum State { COLD, OPEN, FORGING, READY }

## A weapon went on the anvil for `owner` (our Player or another player's hiker), to become `result`.
signal started(owner: Node3D, result: WeaponData)
## The forged weapon is ready to take.
signal forged(result: WeaponData)

const WEAPONS: String = "res://data/weapons/%s.tres"
const STONE: Material = preload("res://assets/materials/stone.tres")
const METAL: Material = preload("res://assets/materials/metal.tres")
const WOOD: Material = preload("res://assets/materials/wood_dark.tres")
const ROCK: Material = preload("res://assets/materials/rock.tres")
const EMBERS: Material = preload("res://assets/materials/fire.tres")
const FIRE_FLICKER: Script = preload("res://scripts/zones/fire_flicker.gd")

## Bought with one press, not held.
var interact_repeat: float = 0.0
var state: State = State.COLD
## What is being forged, and for whom; `melee` when it goes into the melee slot.
var result: WeaponData
var melee: bool = false
var _owner: Node3D
var _time_left: float = 0.0
var _blow_left: float = 0.0
var _spin: float = 0.0
var _coals: Array[MeshInstance3D] = []
var _fire: OmniLight3D
var _hammer: Node3D
var _on_anvil: Node3D
var _display: Node3D
var _glow: OmniLight3D
var _sparks: DengelSparks
var _marker: MapMarker
var _tween: Tween


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("dengelstocks")
	_build()
	var spot := GrindstoneSpot.new()
	spot.stock = self
	spot.position = Vector3(Constants.DENGEL_GRINDSTONE_AT.x, 0.0, Constants.DENGEL_GRINDSTONE_AT.z)
	add_child(spot)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(func(_wave: int) -> void:
		if is_instance_valid(_marker):
			_marker.queue_free())


func _on_wave_started(wave: int, _is_boss_wave: bool) -> void:
	if wave >= Constants.DENGEL_WAVE and state == State.COLD:
		# Once the wave's own banner is gone, so its news is seen.
		get_tree().create_timer(Constants.DENGEL_OPEN_DELAY, false).timeout.connect(open)


## The forge is lit: open from now on, announced with a banner and a light column for the wave.
func open() -> void:
	if state != State.COLD:
		return
	state = State.OPEN
	for coal: MeshInstance3D in _coals:
		coal.material_override = EMBERS
	_fire = OmniLight3D.new()
	_fire.set_script(FIRE_FLICKER)
	_fire.set("base_energy", 1.6)
	_fire.light_color = Color(1.0, 0.5, 0.2)
	_fire.omni_range = 5.0
	_fire.position = Vector3(0.0, 1.2, 0.95)
	add_child(_fire)
	Sound.play_at(&"flame_start", global_position + Vector3.UP)
	Events.event_announced.emit(tr("EVENT_DENGEL_OPEN"))
	_marker = MapMarker.new()
	_marker.text = "MARKER_DENGEL"
	_marker.color = Color(1.0, 0.6, 0.25)
	add_child(_marker)


## Points to dengel `data` once more (DENGEL_COST by the level it gets to).
static func cost_of(data: WeaponData) -> int:
	return Constants.DENGEL_COST[clampi(data.level, 0, Constants.DENGEL_COST.size() - 1)]


# Interactable interface (see Interactor); the grindstone asks with `for_melee`.

func get_interact_position() -> Vector3:
	return to_global(Vector3(0.0, 0.6, -0.75))


func get_interact_prompt(player: Node3D) -> String:
	return prompt_for(player as Player, false)


func interact(player: Node3D) -> void:
	use(player as Player, false)


func prompt_for(player: Player, for_melee: bool) -> String:
	match state:
		State.COLD:
			# Said once, at the anvil.
			return "" if for_melee else tr("UI_DENGEL_COLD") % Constants.DENGEL_WAVE
		State.OPEN:
			var data: WeaponData = _held(player, for_melee)
			if data == null or data.upgrade == null:
				return ""
			var cost: int = cost_of(data)
			if not player.points.can_afford(cost):
				return tr("UI_DENGEL_NEED") % [tr(data.display_name), cost]
			return tr("UI_DENGEL_TWICE" if data.level > 0 else "UI_DENGEL") % [tr(data.display_name), cost]
		State.FORGING:
			if for_melee:
				return ""
			return tr("UI_DENGEL_WORKING") if player == _owner else tr("UI_DENGEL_BUSY")
		State.READY:
			if player != _owner or for_melee != melee:
				return ""
			# A gun comes back into a free slot, or in place of the one in hand.
			var key: String = "UI_CHEST_TAKE" if melee or player.weapons.has_free_slot() else "UI_CHEST_SWAP"
			return tr(key) % tr(result.display_name)
	return ""


func use(player: Player, for_melee: bool) -> void:
	if state == State.READY and player == _owner and for_melee == melee:
		take(player)
		return
	if state != State.OPEN:
		return
	var data: WeaponData = _held(player, for_melee)
	if data == null or data.upgrade == null or not player.points.spend(cost_of(data)):
		return
	Sound.play(&"buy")
	# Co-op: the host says whether the anvil is still free (and pays back if it was not).
	if Coop.is_guest():
		Coop.world.request_dengel(self, data.upgrade, for_melee, cost_of(data))
		return
	start(player, data.upgrade, for_melee)


func _held(player: Player, for_melee: bool) -> WeaponData:
	return player.weapons.melee_weapon if for_melee else player.weapons.weapon


## The weapon goes on the anvil for `owner`, to become `forged_into`. False if the anvil is busy.
## Our own Player hands it over here (the hands hold only the melee weapon for a while).
func start(owner: Node3D, forged_into: WeaponData, for_melee: bool) -> bool:
	if state != State.OPEN or owner == null or forged_into == null:
		return false
	state = State.FORGING
	_owner = owner
	result = forged_into
	melee = for_melee
	var player := owner as Player
	if player:
		if for_melee:
			player.weapons.hand_over_melee()
		else:
			player.weapons.hand_over(forged_into)
	_time_left = Constants.DENGEL_TIME
	_blow_left = Constants.DENGEL_BLOW_TIME * 0.5
	_show_on_anvil(_before(forged_into))
	started.emit(owner, forged_into)
	return true


## Co-op: a start for `owner` by weapon id, as the host decided.
func start_for(owner: Node3D, weapon_id: StringName, for_melee: bool) -> bool:
	var data := load(WEAPONS % weapon_id) as WeaponData if String(weapon_id).is_valid_identifier() and ResourceLoader.exists(WEAPONS % weapon_id) else null
	return data != null and data.level > 0 and start(owner, data, for_melee)


## The owner takes the forged weapon back.
func take(player: Player) -> void:
	if state != State.READY or player != _owner:
		return
	if melee:
		player.weapons.set_melee(result)
	else:
		player.weapons.give_weapon(result)
	if Coop.world:
		Coop.world.dengel_taken(self)
	_close()


## Co-op: the owner took it in their game.
func taken() -> void:
	if state == State.READY:
		_close()


## Who the anvil works for right now (null when it is free).
func owner_of_work() -> Node3D:
	return _owner if state == State.FORGING or state == State.READY else null


func _process(delta: float) -> void:
	_spin += delta
	match state:
		State.FORGING:
			_time_left -= delta
			_blow_left -= delta
			if _blow_left <= 0.0:
				_blow_left += Constants.DENGEL_BLOW_TIME
				_blow()
			if _time_left <= 0.0:
				_finish()
		State.READY:
			_time_left -= delta
			_display.rotation.y = _spin * 1.2
			_display.position.y = Constants.DENGEL_FLOAT_HEIGHT + sin(_spin * 2.5) * 0.04
			if _time_left <= 0.0:
				_gone()


func _blow() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var lift: float = deg_to_rad(70.0)
	var swing: float = Constants.DENGEL_BLOW_TIME
	_tween.tween_property(_hammer, "rotation:x", lift, swing * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hammer, "rotation:x", 0.0, swing * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		_sparks.burst()
		Sound.play_at(&"anvil_clang", _sparks.global_position, 0.0, randf_range(0.95, 1.05)))


func _finish() -> void:
	state = State.READY
	_time_left = Constants.DENGEL_WAIT
	if _tween:
		_tween.kill()
	_hammer.rotation.x = 0.0
	_clear(_on_anvil)
	_clear(_display)
	var model: Node3D = _model(result)
	_display.add_child(model)
	_display.position.y = Constants.DENGEL_FLOAT_HEIGHT - 0.3
	_glow.visible = true
	Sound.play_at(&"dengel_quench", global_position + Vector3.UP * 0.8)
	forged.emit(result)


## Not taken in time: it is gone. Without a gun left, the owner gets the one a match starts with, and
## the melee slot is never left empty (the shovel again).
func _gone() -> void:
	var player := _owner as Player
	if player and is_instance_valid(player):
		if melee:
			player.weapons.restore_melee()
		elif player.weapons.gun_count() == 0 and player.weapons.starting_weapon:
			player.weapons.give_weapon(player.weapons.starting_weapon)
	_close()


func _close() -> void:
	state = State.OPEN
	_owner = null
	result = null
	_glow.visible = false
	_clear(_on_anvil)
	_clear(_display)


## The weapon one level below `data` (what was handed over), from its family's base.
func _before(data: WeaponData) -> WeaponData:
	var base := load(WEAPONS % data.family_id()) as WeaponData
	var level: WeaponData = base
	while level and level.upgrade and level.upgrade != data:
		level = level.upgrade
	return level if level else data


func _show_on_anvil(data: WeaponData) -> void:
	_clear(_on_anvil)
	var model: Node3D = _model(data)
	# Lying across the anvil.
	model.rotation.y = PI * 0.5
	_on_anvil.add_child(model)


## The weapon's meshes, standing on its own origin and centred over it, larger than in hand so it
## reads from the Schuppen floor (a long one, the shovel, made to fit the anvil).
func _model(data: WeaponData) -> Node3D:
	var model: Node3D = WeaponPickup.model_of(data)
	var flash: Node = model.get_node_or_null("MuzzleFlash")
	if flash:
		model.remove_child(flash)
		flash.free()
	var bounds := AABB()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		bounds = bounds.merge(_transform_in(mesh, model) * mesh.get_aabb())
	var holder := Node3D.new()
	var length: float = bounds.get_longest_axis_size() * Constants.DENGEL_SHOW_SCALE
	var fit: float = minf(1.0, Constants.DENGEL_SHOW_MAX_LENGTH / length) if length > 0.0 else 1.0
	holder.scale = Vector3.ONE * Constants.DENGEL_SHOW_SCALE * fit
	holder.add_child(model)
	model.position = -bounds.get_center() + Vector3.UP * bounds.size.y * 0.5
	return holder


# Where `node` sits within `root` (neither is in the tree yet).
func _transform_in(node: Node3D, root: Node3D) -> Transform3D:
	var xf: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent and parent != root:
		xf = (parent as Node3D).transform * xf
		parent = parent.get_parent()
	return xf


func _clear(node: Node3D) -> void:
	for child: Node in node.get_children():
		child.queue_free()


# --- the Schmied's corner ---------------------------------------------------------------------------

func _build() -> void:
	# A stone slab under it all, so a fire in a hay loft reads as safe.
	_box(Vector3(2.2, 0.06, 2.2), Vector3(0.25, 0.03, 0.45), STONE, false)
	# The forge: a stone hearth against the wall, coals on top, a sheet-metal hood and its pipe.
	_box(Vector3(1.5, 0.8, 0.8), Vector3(0.0, 0.4, 1.0), STONE)
	# A rim round the fire bed, and the coals in it (cold grey until the forge is lit).
	for side: float in [-1.0, 1.0]:
		_box(Vector3(1.5, 0.12, 0.1), Vector3(0.0, 0.86, 1.0 + side * 0.35), STONE, false)
		_box(Vector3(0.1, 0.12, 0.6), Vector3(side * 0.7, 0.86, 1.0), STONE, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1848
	for i: int in 14:
		var lump := _box(Vector3.ONE * rng.randf_range(0.1, 0.17), Vector3(rng.randf_range(-0.55, 0.55), 0.83, rng.randf_range(0.78, 1.22)), ROCK, false)
		lump.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		_coals.append(lump)
	_box(Vector3(1.6, 0.06, 0.95), Vector3(0.0, 1.85, 0.95), METAL, false).rotation.x = deg_to_rad(-12.0)
	_box(Vector3(1.6, 0.4, 0.04), Vector3(0.0, 1.66, 0.48), METAL, false)
	var pipe := _cylinder(0.13, 0.65, Vector3(0.0, 2.2, 1.1), METAL)
	pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The anvil on its stump.
	_cylinder(0.24, 0.5, Vector3(0.0, 0.25, 0.0), WOOD, true)
	_box(Vector3(0.62, 0.2, 0.2), Vector3(0.0, 0.6, 0.0), METAL, true)
	_box(Vector3(0.34, 0.08, 0.26), Vector3(0.0, 0.54, 0.0), METAL, false)
	var horn := _cylinder(0.07, 0.24, Vector3(-0.42, 0.64, 0.0), METAL)
	horn.rotation.z = PI * 0.5
	(horn.mesh as CylinderMesh).top_radius = 0.01
	_on_anvil = Node3D.new()
	_on_anvil.position = Vector3(0.0, 0.73, 0.0)
	add_child(_on_anvil)
	# The hammer works by itself (the Schmied is no longer quite of this world): it pivots on the far
	# side of the anvil and comes down on its face.
	_hammer = Node3D.new()
	_hammer.position = Vector3(0.0, 0.78, 0.42)
	add_child(_hammer)
	var handle := _cylinder(0.022, 0.46, Vector3(0.0, 0.0, -0.23), WOOD, false, _hammer)
	handle.rotation.x = PI * 0.5
	_box(Vector3(0.1, 0.1, 0.22), Vector3(0.0, 0.0, -0.42), METAL, false, _hammer).rotation.x = PI * 0.5
	_sparks = DengelSparks.new()
	_sparks.position = Vector3(0.0, 0.76, 0.0)
	add_child(_sparks)
	# The forged weapon floats here, lit gold.
	_display = Node3D.new()
	_display.position = Vector3(0.0, Constants.DENGEL_FLOAT_HEIGHT, 0.0)
	add_child(_display)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.75, 0.35)
	_glow.light_energy = 2.5
	_glow.omni_range = 3.0
	_glow.position = Vector3(0.0, Constants.DENGEL_FLOAT_HEIGHT + 0.3, -0.3)
	_glow.visible = false
	add_child(_glow)
	# The grindstone, for the melee weapon: a wheel in a wooden frame.
	var at: Vector3 = Constants.DENGEL_GRINDSTONE_AT
	_box(Vector3(0.1, 0.5, 0.5), at + Vector3(-0.12, 0.25, 0.0), WOOD, true)
	_box(Vector3(0.1, 0.5, 0.5), at + Vector3(0.12, 0.25, 0.0), WOOD, true)
	var wheel := _cylinder(0.3, 0.1, at + Vector3(0.0, 0.62, 0.0), STONE)
	wheel.rotation.z = PI * 0.5


func _box(size: Vector3, at: Vector3, material: Material, solid: bool = true, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(mesh, at, material, solid, parent, BoxShape3D.new(), size)


func _cylinder(radius: float, height: float, at: Vector3, material: Material, solid: bool = false, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _part(mesh, at, material, solid, parent, shape)


func _part(mesh: Mesh, at: Vector3, material: Material, solid: bool, parent: Node3D, shape: Shape3D, size: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = Constants.LAYER_WORLD
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var box := shape as BoxShape3D
		if box:
			box.size = size
		collision.shape = shape
		body.add_child(collision)
		part.add_child(body)
	return part


## The grindstone beside the anvil: the same Dengelstock, for the melee weapon.
class GrindstoneSpot:
	extends Node3D

	var stock: Dengelstock
	var interact_repeat: float = 0.0

	func _ready() -> void:
		add_to_group("interactables")

	func get_interact_position() -> Vector3:
		return to_global(Vector3(0.0, 0.6, -0.5))

	func get_interact_prompt(player: Node3D) -> String:
		return stock.prompt_for(player as Player, true)

	func interact(player: Node3D) -> void:
		stock.use(player as Player, true)
