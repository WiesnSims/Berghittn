extends WeaponBehavior
## Mistgabel (section 6a), a pitchfork on V in place of the shovel: a long thrust straight along the
## aim (3 m) that goes through the first two bodies in the line, 100 each, pushing them back a little.
## Hold V past the thrust, Aufgabeln: the first body skewered is lifted up on the fork and carried
## over the player's head (3 s at most); let go and it is hurled where the player looks, and where it
## comes down it bowls over everything within 2 m (80, thrown back; itself included). Bosses are too
## heavy to lift.

var _skewered: Enemy
var _lifted: Enemy
var _held: float = 0.0


func melee_hit() -> bool:
	_skewered = null
	var forward: Vector3 = _flat_forward()
	var pierced: int = 0
	for body: Dictionary in holder.bodies_ahead(data.range, Constants.LINE_HALF_ANGLE):
		if pierced >= Constants.MISTGABEL_PIERCE:
			break
		var hurtbox: Hurtbox = body.hurtbox
		if holder.melee_strike(hurtbox, data.damage, forward * data.knockback) == Hurtbox.Result.IGNORED:
			continue
		pierced += 1
		var enemy := hurtbox.receiver as Enemy
		if _skewered == null and enemy and enemy.is_alive():
			_skewered = enemy
	return true


func hold_start() -> bool:
	if _skewered == null or not _skewered.lift():
		return false
	_lifted = _skewered
	_held = 0.0
	return true


func hold(delta: float) -> bool:
	_held += delta
	if _lifted == null or not _lifted.is_lifted() or _held > Constants.MISTGABEL_HOLD_MAX:
		return false
	var forward: Vector3 = _flat_forward()
	var carry: Vector3 = holder.global_position + forward * Constants.MISTGABEL_CARRY_AHEAD + Vector3.UP * Constants.MISTGABEL_CARRY_UP
	_lifted.carry_to(carry, -forward)
	return true


func hold_end() -> void:
	if _lifted and _lifted.is_lifted():
		var aim: Vector3 = -holder.global_basis.z
		_lifted.hurl(aim * data.projectile_speed + Vector3.UP * 3.0, _landed)
	_lifted = null
	_skewered = null


## Where a hurled body comes down: it bowls over everything around it, itself included.
func _landed(enemy: Enemy) -> void:
	var at: Vector3 = enemy.global_position + Vector3.UP * 0.5
	holder.area_hit(at, Vector3.FORWARD, 180.0, data.secondary_range, data.secondary_damage, data.secondary_knockback)
	Sound.play_at(&"land", at)


func _flat_forward() -> Vector3:
	var aim: Vector3 = -holder.global_basis.z
	var flat := Vector3(aim.x, 0.0, aim.z)
	return flat.normalized() if flat.length() > 0.05 else -holder.shooter().global_basis.z
