extends WeaponBehavior
## Krampus-Rute (section 6a), the birch rod the Krampus drops, on V in place of the shovel: a swat
## across the front (2 m) for 150, and panic: every body it strikes, and every enemy within 2.5 m of
## one, runs away from the player for 3 s, attacking nobody. Bosses shrug the panic off.
## Hold V past the swat, the Larve: the rod raised high, rattling, the Krampus face put on; every
## enemy within 8 m and 35° either side of the aim (walls shield) flees for as long as it is held and
## a second after. The player walks slowly and cannot shoot meanwhile.

var _scan_left: float = 0.0


func melee_hit() -> bool:
	var struck: Array[Enemy] = []
	for body: Dictionary in holder.bodies_ahead(data.range, Constants.MELEE_ARC_DEGREES * 0.5):
		var hurtbox: Hurtbox = body.hurtbox
		var to_target: Vector3 = body.to_target
		var away := Vector3(to_target.x, 0.0, to_target.z).normalized()
		if holder.melee_strike(hurtbox, data.damage, away * data.knockback) == Hurtbox.Result.IGNORED:
			continue
		var enemy := hurtbox.receiver as Enemy
		if enemy and enemy.is_alive():
			struck.append(enemy)
	var from: Vector3 = holder.shooter().global_position
	for node: Node in holder.get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == null or not other.is_alive():
			continue
		for enemy: Enemy in struck:
			if other.global_position.distance_to(enemy.global_position) <= Constants.RUTE_FLEE_RADIUS:
				other.flee(from, Constants.RUTE_FLEE_TIME)
				break
	return true


func hold_start() -> bool:
	_scan_left = 0.0
	Sound.play(&"chains")
	return true


func hold(delta: float) -> bool:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = Constants.LARVE_SCAN
		var from: Vector3 = holder.shooter().global_position
		for body: Dictionary in holder.bodies_ahead(data.secondary_range, data.area_angle):
			var enemy := (body.hurtbox as Hurtbox).receiver as Enemy
			if enemy:
				enemy.flee(from, Constants.LARVE_LINGER)
	return true
