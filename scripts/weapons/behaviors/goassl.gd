extends WeaponBehavior
## Goaßl (section 6a), a long whip on V in place of the shovel: the crack hits everything in a short
## cone (3.5 m, 30° either side) for 40 and stuns it for 1.5 s; bosses take the blow but are not
## stunned. Hold V past the crack, the lash: the whip wraps round the first body along the aim within
## 7 m and drags it to the player for as long as V is held (3 s at most), dazed; let go and it stays
## stunned for 1.5 s. Pulls a Perchte out of a crowd, or one off a window. Bosses are too heavy.

var _caught: Enemy
var _held: float = 0.0


func melee_hit() -> bool:
	for body: Dictionary in holder.bodies_ahead(data.range, data.area_angle):
		var hurtbox: Hurtbox = body.hurtbox
		var enemy := hurtbox.receiver as Enemy
		holder.strike(hurtbox, data.damage, Vector3.ZERO, true)
		if enemy and enemy.is_alive():
			enemy.stun(Constants.GOASSL_STUN_TIME)
	# One crack, out at the tip of the whip, hit or miss.
	Sound.play_at(data.hit_sound, holder.global_position - holder.global_basis.z * data.range)
	return true


func hold_start() -> bool:
	var hurtbox: Hurtbox = holder.body_in_line(data.secondary_range)
	var enemy: Enemy = hurtbox.receiver as Enemy if hurtbox else null
	if enemy == null or not enemy.is_alive() or enemy.data.is_boss:
		return false
	_caught = enemy
	_held = 0.0
	return true


func hold(delta: float) -> bool:
	_held += delta
	if _caught == null or not _caught.is_alive() or _held > Constants.GOASSL_HOLD_MAX:
		return false
	var to_player: Vector3 = holder.shooter().global_position - _caught.global_position
	to_player.y = 0.0
	if to_player.length() > Constants.GOASSL_PULL_STOP:
		_caught.apply_knockback(to_player.normalized() * data.secondary_knockback)
	_caught.stun(0.2)
	var whip: MeleeViewmodel = holder.melee_viewmodel()
	if whip:
		whip.call("lash_to", _caught.global_position + Vector3.UP * Constants.MELEE_AIM_HEIGHT)
	return true


func hold_end() -> void:
	if _caught and _caught.is_alive():
		_caught.stun(Constants.GOASSL_STUN_TIME)
	_caught = null
