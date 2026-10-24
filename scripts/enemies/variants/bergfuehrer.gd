extends EnemyVariant
## Da Bergführer (Die Bsundan, 1.2): comes with a Seilschaft, SEIL_FOLLOWERS plain Wanderers roped on
## behind him in a line (Enemy.roped_to), a rope drawn between them. A rope stretched past SEIL_SNAP
## snaps and those behind go free; his death trips everyone still roped on.

const SEGMENTS: int = 5

## The ones roped on behind him, in order (every screen: puppets get it by cue).
var chain: Array[Enemy] = []
# Seconds until the rope goes out to co-op guests (once the Seilschaft has been announced to them).
var _sync_left: float = -1.0
var _rope: Array[MeshInstance3D] = []
static var _rope_mesh: CylinderMesh


func activated() -> void:
	super()
	chain.clear()
	_sync_left = -1.0


func followers() -> int:
	return Constants.SEIL_FOLLOWERS


func escort(with: Array[Enemy]) -> void:
	chain = with.duplicate()
	_relink()
	_sync_left = 0.3


func tick(delta: float) -> void:
	if _sync_left > 0.0:
		_sync_left -= delta
		if _sync_left <= 0.0:
			signal_cue(&"rope", chain.duplicate())
	var kept: Array[Enemy] = []
	var before: Node3D = enemy
	for follower: Enemy in chain:
		if not is_instance_valid(follower) or not follower.is_alive():
			continue
		if follower.global_position.distance_to(before.global_position) > Constants.SEIL_SNAP:
			# Snapped: this one and all behind go free.
			for loose: Enemy in chain.slice(chain.find(follower)):
				if is_instance_valid(loose):
					loose.roped_to = null
			break
		kept.append(follower)
		before = follower
	if kept != chain:
		chain = kept
		_relink()
		signal_cue(&"rope", chain.duplicate())


func died(_source: Node3D) -> void:
	if deciding():
		for follower: Enemy in chain:
			if is_instance_valid(follower) and follower.is_alive():
				follower.roped_to = null
				follower.stun(Constants.SEIL_TRIP_TIME)
	chain.clear()
	_draw()


func show_cue(cue: StringName, arg: Variant) -> void:
	if cue != &"rope":
		return
	chain.clear()
	# The host has the enemies themselves; a guest their net ids.
	for item: Variant in arg:
		var follower: Enemy = item as Enemy if item is Enemy else (Coop.enemies.by_id(item) if Coop.enemies else null)
		if follower:
			chain.append(follower)


func _relink() -> void:
	var before: Enemy = enemy
	for follower: Enemy in chain:
		follower.roped_to = before
		before = follower


func _process(_delta: float) -> void:
	_draw()


## The rope: sagging between each two of them, at their waists.
func _draw() -> void:
	var knots: Array[Vector3] = []
	if enemy.is_alive() and not chain.is_empty():
		knots.append(enemy.global_position + Vector3.UP * Constants.SEIL_HEIGHT)
		for follower: Enemy in chain:
			if is_instance_valid(follower) and follower.is_alive():
				knots.append(follower.global_position + Vector3.UP * Constants.SEIL_HEIGHT)
	var used: int = 0
	for k: int in range(1, knots.size()):
		for s: int in SEGMENTS:
			var from: Vector3 = _sagged(knots[k - 1], knots[k], float(s) / SEGMENTS)
			var to: Vector3 = _sagged(knots[k - 1], knots[k], float(s + 1) / SEGMENTS)
			_segment(used, from, to)
			used += 1
	for i: int in range(used, _rope.size()):
		_rope[i].visible = false


static func _sagged(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * Constants.SEIL_SAG * 4.0 * t * (1.0 - t)


func _segment(index: int, from: Vector3, to: Vector3) -> void:
	while _rope.size() <= index:
		var piece := MeshInstance3D.new()
		piece.mesh = rope_mesh()
		piece.top_level = true
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		_rope.append(piece)
	var piece: MeshInstance3D = _rope[index]
	var along: Vector3 = to - from
	var length: float = along.length()
	if length < 0.001:
		piece.visible = false
		return
	var y: Vector3 = along / length
	var x: Vector3 = y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y)
	piece.global_transform = Transform3D(Basis(x, y * length, z), (from + to) * 0.5)
	piece.visible = true


## A piece of rope one metre long (also drawn by the shader warm-up).
static func rope_mesh() -> CylinderMesh:
	if _rope_mesh == null:
		_rope_mesh = CylinderMesh.new()
		_rope_mesh.top_radius = 0.022
		_rope_mesh.bottom_radius = 0.022
		_rope_mesh.height = 1.0
		_rope_mesh.radial_segments = 5
		_rope_mesh.rings = 1
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.35, 0.1)
		material.roughness = 0.9
		_rope_mesh.material = material
	return _rope_mesh


## How many rope pieces show now (tests).
func rope_shown() -> int:
	return _rope.filter(func(p: MeshInstance3D) -> bool: return p.visible).size()
