extends EnemyVariant
## Da Trailrunner (Die Bsundan, 1.2): his lunge is a long charge (his data file), started only from
## TRAIL_RANGE_MIN off. Straight ahead, unable to turn: a player in his way is hurt and thrown along
## his run (in their own game), other enemies are shoved aside, and into a wall he goes down, dazed.

## In the run of a charge now (every screen: puppets get it by cue, so a guest is thrown too).
var charging: bool = false


func activated() -> void:
	super()
	charging = false


func may_lunge(distance: float) -> bool:
	return distance >= Constants.TRAIL_RANGE_MIN


func tick(_delta: float) -> void:
	if enemy.leaping() != charging:
		signal_cue(&"charge", enemy.leaping())


func lunge_moved() -> void:
	var ahead: Vector3 = _ahead()
	for i: int in enemy.get_slide_collision_count():
		var hit: KinematicCollision3D = enemy.get_slide_collision(i)
		var other := hit.get_collider() as Enemy
		if other:
			var off: Vector3 = other.global_position - enemy.global_position
			off -= ahead * off.dot(ahead)
			off.y = 0.0
			if off.length_squared() < 0.0001:
				off = Vector3(-ahead.z, 0.0, ahead.x)
			other.apply_knockback(off.normalized() * Constants.TRAIL_SHOVE)
			continue
		if hit.get_collider() is Node and (hit.get_collider() as Node).has_method("is_targetable"):
			continue
		# Head on into something solid (not just brushing along it).
		if hit.get_normal().dot(ahead) < -0.5:
			signal_cue(&"charge", false)
			enemy.crash(Constants.TRAIL_CRASH_STUN)
			Gredn.now(enemy, Gredn.Moment.CRASH)
			signal_cue(&"crash")
			return


func struck(player: Player) -> void:
	if charging:
		player.push(_ahead() * Constants.TRAIL_THROW + Vector3.UP * Constants.TRAIL_THROW_UP)


func died(_source: Node3D) -> void:
	charging = false


func show_cue(cue: StringName, arg: Variant) -> void:
	if cue == &"charge":
		charging = arg
	elif cue == &"crash":
		Sound.play_at(&"pfanne_bonk", enemy.mouth())


## Where he runs: the way he faces (models face -Z), flat.
func _ahead() -> Vector3:
	var ahead: Vector3 = -enemy.global_basis.z
	ahead.y = 0.0
	return ahead.normalized()
