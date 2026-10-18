extends WeaponBehavior
## Steirische Harmonika (section 6a): a squeezebox polka. Every enemy within 8 m (walls shield) dances
## on the spot for 4 s: it cannot walk or attack, takes 20 a second, and every other hit on it lands
## twice as hard. Bosses do not dance but take the damage.
## Right click, the Tanzboden (play-test 2026-10-18): two rounds lay a round dance floor where the
## player aims (up to TANZBODEN_REACH away). For TANZBODEN_TIME the Landler plays from it and whoever
## steps on it dances like at a polka (bosses take the damage only), so a doorway or window becomes a
## trap while the player fights elsewhere.

const NOTES := preload("res://scripts/weapons/behaviors/harmonika_notes.gd")
const FLOOR := preload("res://scripts/weapons/behaviors/tanzboden.gd")

var _floors: Array[Node3D] = []
var _next_floor: int = 0


func fire(_rounds: int) -> void:
	holder.dance_around(data.range, Constants.DANCE_TIME, data.damage)
	_show_notes(data.range, 1.0)
	holder.shake_view(data.shake)


func fire_secondary() -> void:
	var space: PhysicsDirectSpaceState3D = holder.get_world_3d().direct_space_state
	var from: Vector3 = holder.global_position
	var aim: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - holder.global_basis.z * Constants.TANZBODEN_REACH, Constants.LAYER_WORLD, holder.shooter_exclude()))
	# Short of a wall it hit, or as far as it reaches; then down onto the floor there.
	var spot: Vector3 = aim.position + aim.normal * 0.3 if not aim.is_empty() else from - holder.global_basis.z * Constants.TANZBODEN_REACH
	var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.3, spot + Vector3.DOWN * 6.0, Constants.LAYER_WORLD))
	var at: Vector3 = down.position if not down.is_empty() else holder.shooter().global_position
	_free_floor().call("lay", self, at, data.secondary_range)


## Called by a Tanzboden every TANZBODEN_SCAN: whoever is on it dances.
func dance_floor(center: Vector3, radius: float) -> void:
	holder.dance_at(center + Vector3.UP * 0.8, radius, Constants.DANCE_LINGER, data.secondary_damage)


func _show_notes(reach: float, amount: float) -> void:
	var notes := Node3D.new()
	notes.set_script(NOTES)
	notes.set("reach", reach)
	notes.set("amount", amount)
	holder.add_effect(notes)


# A free floor from the pool, building it on first use; with all of them out, the oldest is reused.
func _free_floor() -> Node3D:
	for node: Node3D in _floors:
		if not node.call("is_busy"):
			return node
	if _floors.size() < Constants.TANZBODEN_POOL:
		var node := Node3D.new()
		node.set_script(FLOOR)
		holder.world_root().add_child(node)
		_floors.append(node)
		return node
	var oldest: Node3D = _floors[_next_floor]
	_next_floor = (_next_floor + 1) % _floors.size()
	return oldest
