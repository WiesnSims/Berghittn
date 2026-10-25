class_name EnemyVariant
extends Node3D
## The trick of a rare variant (Die Bsundan, 1.2, GAME_DESIGN section 12): a node on the enemy, made
## from EnemyData.variant, kept while the enemy is pooled as the same variant. The enemy calls the
## hooks; tick and chase only run in solo and on the host, what every screen must see goes out with
## show (here) and the enemy's `cued` signal (co-op guests' puppets get it in cue).

var enemy: Enemy


## It came (again, out of the pool): reset, and the banner on this screen.
func activated() -> void:
	Events.event_announced.emit(tr("EVENT_VARIANT_" + String(enemy.data.id).to_upper()))


## Every step while it lives (solo and host), in any state.
func tick(_delta: float) -> void:
	pass


## While it chases a target it can see (solo and host): true if the trick moved it this step, so
## the usual chase is skipped.
func chase(_delta: float) -> bool:
	return false


## Whether it may start a lunge at a target `distance` m off (the base enemy's lunge rules hold too).
func may_lunge(_distance: float) -> bool:
	return true


## A step of its lunge's leap was taken (solo and host).
func lunge_moved() -> void:
	pass


## Its blow landed on `target` (solo and host).
func landed(_target: Node3D) -> void:
	pass


## It hurt `player`, our own Player, in our own game (solo, host or guest).
func struck(_player: Player) -> void:
	pass


## It died to `source` (every screen; a puppet too, so the damage it deals is for solo and the host).
func died(_source: Node3D) -> void:
	pass


## Its hat was shot off (solo and host).
func hat_lost() -> void:
	pass


## How many plain enemies of its base come along with it (the Bergführer's Seilschaft).
func followers() -> int:
	return 0


## The plain enemies that came along, behind it (solo and host).
func escort(_with: Array[Enemy]) -> void:
	pass


## Points on top of the kill for whoever kills it.
func kill_bonus() -> int:
	return 0


## Something every screen must see: shown here, and sent to co-op guests.
func signal_cue(cue: StringName, arg: Variant = null) -> void:
	show_cue(cue, arg)
	enemy.send_cue(cue, arg)


## A co-op guest's puppet got a cue from the host.
func cue(name: StringName, arg: Variant) -> void:
	show_cue(name, arg)


## What a cue looks and sounds like (every screen).
func show_cue(_cue: StringName, _arg: Variant) -> void:
	pass


## Solo and the host decide; a puppet only shows.
func deciding() -> bool:
	return not enemy.puppet


## The players and escorts it may affect, alive.
func targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("escorts"):
		var body := node as Node3D
		if body and body.is_targetable():
			out.append(body)
	return out


## The other enemies alive in the world (solo and host: the wave manager's).
func others() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node: Node in enemy.get_parent().get_children():
		var other := node as Enemy
		if other and other != enemy and other.is_alive():
			out.append(other)
	return out


## No wall between `from` and `to`.
func clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Constants.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
