extends EnemyVariant
## Die Schönperchte (Die Bsundan, 1.2): never attacks while she wears her Tafel. She keeps
## SCHOEN_KEEP from the nearest player and every SCHOEN_BLESS_EVERY jumps and rings her bells: every
## enemy within SCHOEN_RADIUS gets SCHOEN_HEAL of its health back. With the Tafel shot off the
## blessing is gone and she fights like a Perchte (her data has no lunge).

var blessing: bool = true
var bless_left: float = 0.0
var _hop: Tween


func activated() -> void:
	super()
	blessing = true
	bless_left = Constants.SCHOEN_BLESS_EVERY * 0.5


func hat_lost() -> void:
	blessing = false


func tick(delta: float) -> void:
	if not blessing:
		return
	bless_left -= delta
	if bless_left <= 0.0 and enemy.free_to_act():
		bless_left = Constants.SCHOEN_BLESS_EVERY
		bless()


func chase(delta: float) -> bool:
	if not blessing:
		return false
	var target: Node3D = enemy.target()
	var offset: Vector3 = target.global_position - enemy.global_position
	if Vector2(offset.x, offset.z).length() > Constants.SCHOEN_KEEP:
		enemy.walk(target.global_position, delta)
	else:
		enemy.hold(target.global_position, delta)
	return true


## She jumps and rings: every enemy near her is healed (also used by tests).
func bless() -> void:
	for other: Enemy in others():
		if other.global_position.distance_to(enemy.global_position) > Constants.SCHOEN_RADIUS:
			continue
		other.heal(roundi(other.max_health * Constants.SCHOEN_HEAL))
		other.sparkle()
		other.send_cue(&"healed", other.health)
	enemy.pose(EnemyRig.Action.DANCE, Constants.SCHOEN_JUMP_TIME)
	if _hop:
		_hop.kill()
	var visual: Node3D = enemy.visual()
	_hop = create_tween()
	_hop.tween_property(visual, "position:y", 0.45, Constants.SCHOEN_JUMP_TIME * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop.tween_property(visual, "position:y", 0.0, Constants.SCHOEN_JUMP_TIME * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop.tween_interval(Constants.SCHOEN_JUMP_TIME * 0.4)
	_hop.tween_callback(_landed)
	Gredn.now(enemy, Gredn.Moment.BLESS)
	signal_cue(&"bless")


func _landed() -> void:
	if enemy.is_alive() and enemy.rig() and enemy.rig().action() == EnemyRig.Action.DANCE:
		enemy.pose(EnemyRig.Action.NONE)


func show_cue(cue: StringName, _arg: Variant) -> void:
	if cue == &"bless":
		enemy.sparkle()
		Sound.play_at(&"perchten_schellen", enemy.mouth())
