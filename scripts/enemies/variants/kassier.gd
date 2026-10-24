extends EnemyVariant
## Da Vereinskassier (Die Bsundan, 1.2): every blow collects the Mitgliedsbeitrag, KASSIER_FEE points
## off the player hit (taken in their own game, never below 0); his kill bursts the Kassa and pays
## the killer KASSIER_KILL plus every fee he took this life.

## Fees taken this life (co-op guests' puppets get it with each fee, so their killer is paid right).
var box: int = 0


func activated() -> void:
	super()
	box = 0


func landed(_target: Node3D) -> void:
	signal_cue(&"fee", box + Constants.KASSIER_FEE)
	Gredn.now(enemy, Gredn.Moment.FEE)


func struck(player: Player) -> void:
	player.points.lose(Constants.KASSIER_FEE)


func died(_source: Node3D) -> void:
	enemy.spill(true)
	Sound.play_at(&"kassa_ching", enemy.mouth())


func kill_bonus() -> int:
	return Constants.KASSIER_KILL + box


func show_cue(cue: StringName, arg: Variant) -> void:
	if cue == &"fee":
		box = arg
		enemy.spill(false)
		Sound.play_at(&"kassa_ching", enemy.mouth())
