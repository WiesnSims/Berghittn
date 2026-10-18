extends WeaponBehavior
## Rodelkanone (section 6a): shoots a wooden Rodel in an arc where the player aims; where it comes
## down it races along the ground in a straight line for 15 m, over steps and down slopes, knocking every enemy
## in its lane aside for 300. At the end, or at the first wall, it breaks apart with a crash.
## Right click, the Kehre: a sled shot with more powder (two rounds) that banks off walls up to
## three times and runs 25 m, for rooms and corridors where a straight 15 m never fit.

const SLED := preload("res://scripts/weapons/behaviors/rodel_sled.gd")
# Walls the Kehre's sled banks off before it breaks on the next one.
const KEHRE_BANKS: int = 3
# Where the sled leaves the barrel, from the eye: ahead along the aim and down.
const MUZZLE_AHEAD: float = 0.8
const MUZZLE_DROP: float = 0.2

var _sleds: Array[Node3D] = []
var _next: int = 0


func fire(_rounds: int) -> void:
	_launch(data.damage, data.range, 0)
	holder.shake_view(data.shake)


func fire_secondary() -> void:
	_launch(data.secondary_damage, data.secondary_range, KEHRE_BANKS)
	holder.shake_view(data.secondary_shake)


func _launch(damage: int, distance: float, banks: int) -> void:
	var look: Vector3 = -holder.global_basis.z
	var start: Vector3 = holder.global_position + look * MUZZLE_AHEAD - holder.global_basis.y * MUZZLE_DROP
	# Against a wall it leaves the barrel right at the wall, not on its far side.
	var blocked := PhysicsRayQueryParameters3D.create(holder.global_position, start, Constants.LAYER_WORLD, holder.shooter_exclude())
	var hit: Dictionary = holder.get_world_3d().direct_space_state.intersect_ray(blocked)
	if not hit.is_empty():
		start = hit.position - look * 0.1
	var flat := Vector3(look.x, 0.0, look.z)
	# Straight up or down there is no lane to run in; take the way the body faces.
	if flat.length() < 0.1:
		var body: Vector3 = -holder.shooter().global_basis.z
		flat = Vector3(body.x, 0.0, body.z)
	var sled: Node3D = _free_sled()
	sled.call("launch", self, start, look * data.projectile_speed, flat.normalized(), damage, distance, banks)


## Called by a sled for every body it runs into.
func strike(hurtbox: Hurtbox, damage: int, push: Vector3) -> void:
	if holder.strike(hurtbox, damage, push) != Hurtbox.Result.IGNORED:
		Sound.play_at(data.hit_sound, hurtbox.global_position)


## Called by a sled where it breaks apart.
func crash(at: Vector3) -> void:
	Sound.play_at(data.hit_sound, at, Constants.SLED_CRASH_LOUDER)


func _free_sled() -> Node3D:
	for sled: Node3D in _sleds:
		if not sled.call("is_busy"):
			return sled
	if _sleds.size() < Constants.RODEL_POOL:
		var sled := Node3D.new()
		sled.set_script(SLED)
		holder.world_root().add_child(sled)
		_sleds.append(sled)
		return sled
	_next = (_next + 1) % Constants.RODEL_POOL
	return _sleds[_next]
