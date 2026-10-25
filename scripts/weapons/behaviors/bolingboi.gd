extends WeaponBehavior
## Da Bolingboi (1.2, the Kegelbahn's prize): rolls a bowling ball from the hand along the floor,
## straight where the player looks, over steps and down slopes (a KegelBall, the Rodelkanone's sled
## riding). Every enemy in its way is bowled over (damage, thrown aside); at the first wall, or at the
## end of its range, it explodes (data.secondary_damage within data.area_radius, the Böller's blast).
## Right click, "Hoch damit!": the newest ball still rolling goes off where it is, for no round.

const BALL := preload("res://scripts/weapons/behaviors/kegel_ball.gd")
const BLAST: Script = preload("res://scripts/perks/boeller_blast.gd")
# Where the ball leaves the hand, from the eye: ahead along the look and down towards the floor.
const HAND_AHEAD: float = 0.6
const HAND_DROP: float = 0.9

var _balls: Array[Node3D] = []
# The balls in the order they were rolled (the newest last), for Hoch damit!.
var _rolled: Array[Node3D] = []
var _next: int = 0


func fire(_rounds: int) -> void:
	var look: Vector3 = -holder.global_basis.z
	var flat := Vector3(look.x, 0.0, look.z)
	if flat.length() < 0.1:
		var body: Vector3 = -holder.shooter().global_basis.z
		flat = Vector3(body.x, 0.0, body.z)
	flat = flat.normalized()
	var start: Vector3 = holder.global_position + flat * HAND_AHEAD + Vector3.DOWN * HAND_DROP
	# Against a wall it is let go right at the wall, not on its far side.
	var blocked := PhysicsRayQueryParameters3D.create(holder.global_position, start, Constants.LAYER_WORLD, holder.shooter_exclude())
	var hit: Dictionary = holder.get_world_3d().direct_space_state.intersect_ray(blocked)
	if not hit.is_empty():
		start = hit.position - (start - holder.global_position).normalized() * 0.15
	var ball: Node3D = _free_ball()
	# Let go just over the floor: it lands at once and rolls.
	ball.call("launch", self, start, flat * data.projectile_speed + Vector3.DOWN * 2.0, flat, data.damage, data.range, 0)
	_rolled.erase(ball)
	_rolled.append(ball)


func fire_secondary() -> void:
	for i: int in range(_rolled.size() - 1, -1, -1):
		var ball: Node3D = _rolled[i]
		if ball.call("is_busy"):
			ball.call("detonate")
			return


## Called by a ball for every body it runs into.
func strike(hurtbox: Hurtbox, damage: int, push: Vector3) -> void:
	if holder.strike(hurtbox, damage, push) != Hurtbox.Result.IGNORED:
		Sound.play_at(data.hit_sound, hurtbox.global_position)


## Called by a ball where it goes off (a wall, the end of its range, Hoch damit!).
func crash(at: Vector3) -> void:
	_rolled = _rolled.filter(func(b: Node3D) -> bool: return b.call("is_busy"))
	holder.area_hit(at + Vector3.UP * 0.5, Vector3.FORWARD, 180.0, data.area_radius, data.secondary_damage, data.knockback)
	var blast := Node3D.new()
	blast.set_script(BLAST)
	blast.set("radius", data.area_radius)
	holder.world_root().add_child(blast)
	blast.global_position = at
	holder.shake_view(data.shake)


## Balls rolling now (tests).
func rolling() -> int:
	return _balls.filter(func(b: Node3D) -> bool: return b.call("is_busy")).size()


func _free_ball() -> Node3D:
	for ball: Node3D in _balls:
		if not ball.call("is_busy"):
			return ball
	if _balls.size() < Constants.BOLINGBOI_POOL:
		var ball := Node3D.new()
		ball.set_script(BALL)
		holder.world_root().add_child(ball)
		_balls.append(ball)
		return ball
	_next = (_next + 1) % Constants.BOLINGBOI_POOL
	return _balls[_next]
