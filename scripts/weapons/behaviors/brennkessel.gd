extends WeaponBehavior
## Brennkessel-Werfer (section 6a): a copper schnaps still on the back feeds a brass lance by a hose.
## Held down, it throws a flame 8 m ahead in a narrow cone, 8 ticks a second, one unit of fuel each:
## every body in it (walls shield) takes 15 a tick and catches fire, burning for 10 a second until
## 3 s after it last stood in the flame. Bosses burn too.
## Right click, the Brennlacke: a gulp of 20 fuel squirted in an arc; where it comes down it spreads
## into a burning puddle 4 m across that sets alight whatever walks through it for 6 s.
## Dengelt (M9 part 4b): the fire jumps from every body the flame catches to those within data.twist
## metres of it (the Feuerwasser-Kessel: 1.5 m, doppelt 3 m).

const BLOB := preload("res://scripts/weapons/behaviors/schnaps_blob.gd")
const LACKE := preload("res://scripts/weapons/behaviors/brennlacke.gd")

var _blobs: Array[Node3D] = []
var _lacken: Array[Node3D] = []
var _next_blob: int = 0
var _next_lacke: int = 0


func fire(_rounds: int) -> void:
	holder.scorch(data.area_angle, data.range, data.damage, Constants.BURN_DPS, Constants.BURN_TIME, data.twist)


func fire_secondary() -> void:
	var direction: Vector3 = -holder.global_basis.z
	var blob: Node3D = _pooled(_blobs, Constants.LACKE_POOL, BLOB, true)
	# Out of the lance, a little below the eye, where the player looks.
	var start: Vector3 = holder.global_position + direction * 0.6 + holder.global_basis.y * -0.15
	blob.call("launch", self, start, direction * data.projectile_speed, data.secondary_damage, data.secondary_range, 1.0)
	holder.shake_view(data.secondary_shake)


## Called by a blob where it splashes: a burning puddle on the floor below.
func burst(at: Vector3, _damage: int, radius: float, _size: float) -> void:
	var space: PhysicsDirectSpaceState3D = holder.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var floor_hit: Dictionary = space.intersect_ray(down)
	if floor_hit.is_empty():
		return
	var lacke: Node3D = _pooled(_lacken, Constants.LACKE_POOL, LACKE, false)
	lacke.call("lay", self, floor_hit.position, radius)
	Sound.play_at(data.hit_sound, floor_hit.position)


## Called by a burning puddle every LACKE_INTERVAL: whoever stands in it catches fire.
func burn_lacke(center: Vector3, radius: float) -> void:
	# Measured from a little above the puddle, so a bump in the floor cannot hide a body.
	holder.ignite_around(center + Vector3.UP * 0.5, radius, data.secondary_damage, Constants.BURN_TIME)


## A free node from the pool, building it on first use; with all of them out, the oldest is reused.
func _pooled(pool: Array[Node3D], size: int, script: GDScript, is_blob: bool) -> Node3D:
	for node: Node3D in pool:
		if not node.call("is_busy"):
			return node
	if pool.size() < size:
		var node := Node3D.new()
		node.set_script(script)
		holder.world_root().add_child(node)
		pool.append(node)
		return node
	var index: int = _next_blob if is_blob else _next_lacke
	if is_blob:
		_next_blob = (_next_blob + 1) % size
	else:
		_next_lacke = (_next_lacke + 1) % size
	return pool[index]
