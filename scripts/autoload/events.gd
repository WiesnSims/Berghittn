extends Node
## Global signal bus for events that several unrelated systems care about (points, waves, stats).

@warning_ignore("unused_signal")
signal enemy_damaged(enemy: Node3D, amount: int, is_headshot: bool)
@warning_ignore("unused_signal")
signal enemy_killed(enemy: Node3D, is_headshot: bool)
@warning_ignore("unused_signal")
signal player_died(player: Node3D)
