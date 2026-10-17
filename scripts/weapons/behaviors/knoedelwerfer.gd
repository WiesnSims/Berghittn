extends WeaponBehavior
## Knödelwerfer (section 6a): lobs a giant Semmelknödel in a ball arc. Where it lands it bursts for
## area damage and leaves a sticky pile that slows enemies. Right click, the Knödeltris: three smaller
## dumplings in a fan for three rounds, to cover a doorway or a crowd's width.

const KNOEDEL := preload("res://scripts/weapons/behaviors/knoedel.gd")
const PILE := preload("res://scripts/weapons/behaviors/knoedel_pile.gd")
# The trio's dumplings are drawn this much smaller than the big one.
const TRIO_SIZE: float = 0.7

var _knoedel: Array[Node3D] = []
var _piles: Array[Node3D] = []
var _next_knoedel: int = 0
var _next_pile: int = 0


func fire(_rounds: int) -> void:
	_launch(-holder.global_basis.z, data.damage, data.area_radius, 1.0)


func fire_secondary() -> void:
	var up: Vector3 = holder.global_basis.y
	for side: float in [-1.0, 0.0, 1.0]:
		var direction: Vector3 = (-holder.global_basis.z).rotated(up, deg_to_rad(data.area_angle * side))
		_launch(direction, data.secondary_damage, data.secondary_range, TRIO_SIZE)


func _launch(direction: Vector3, damage: int, radius: float, size: float) -> void:
	var knoedel: Node3D = _pooled(_knoedel, Constants.KNOEDEL_POOL, KNOEDEL, true)
	# Out of the barrel, a little below the eye, and flying where the player looks.
	var start: Vector3 = holder.global_position + direction * 0.6 + holder.global_basis.y * -0.12
	knoedel.call("launch", self, start, direction * data.projectile_speed, damage, radius, size)


## Called by a dumpling where it bursts: the blast, then a pile on the floor below.
func burst(at: Vector3, damage: int, radius: float, size: float) -> void:
	# Measured from a little above the splat, so a bump in the alm between it and a body cannot hide it.
	holder.area_hit(at + Vector3.UP * 0.5, Vector3.FORWARD, 180.0, radius, damage, data.knockback)
	holder.show_word(at + Vector3.UP * 0.5, data.hit_text)
	var space: PhysicsDirectSpaceState3D = holder.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var floor_hit: Dictionary = space.intersect_ray(down)
	if floor_hit.is_empty():
		return
	var pile: Node3D = _pooled(_piles, Constants.KNOEDEL_PILE_POOL, PILE, false)
	pile.call("lay", floor_hit.position, data.pile_radius * radius / data.area_radius, data.pile_time, data.slow_factor, data.slow_time)


## A free node from the pool, building it on first use; with all of them out, the oldest is reused.
func _pooled(pool: Array[Node3D], size: int, script: GDScript, is_knoedel: bool) -> Node3D:
	for node: Node3D in pool:
		if not node.call("is_busy"):
			return node
	if pool.size() < size:
		var node := Node3D.new()
		node.set_script(script)
		holder.world_root().add_child(node)
		pool.append(node)
		return node
	var index: int = _next_knoedel if is_knoedel else _next_pile
	if is_knoedel:
		_next_knoedel = (_next_knoedel + 1) % size
	else:
		_next_pile = (_next_pile + 1) % size
	return pool[index]
