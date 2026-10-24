extends Node
## Global signal bus for events that several unrelated systems care about (points, waves, stats).
## `source` is whoever caused it (the player who shot, swung or repaired), so co-op can credit the right player.

@warning_ignore("unused_signal")
signal enemy_damaged(enemy: Node3D, amount: int, is_headshot: bool, source: Node3D)
## An enemy came into the fight (out of the pool, on every screen: co-op puppets too).
@warning_ignore("unused_signal")
signal enemy_appeared(enemy: Node3D)
@warning_ignore("unused_signal")
signal enemy_killed(enemy: Node3D, is_headshot: bool, is_melee: bool, source: Node3D)
## Huat obschiaßn: `source` shot `enemy`'s hat off.
@warning_ignore("unused_signal")
signal hat_shot(enemy: Node3D, source: Node3D)
@warning_ignore("unused_signal")
signal player_died(player: Node3D)
@warning_ignore("unused_signal")
signal board_repaired(barricade: Node3D, source: Node3D)
## Countdown to the next wave started (also before wave 1).
@warning_ignore("unused_signal")
signal wave_break_started(next_wave: int, duration: float)
@warning_ignore("unused_signal")
signal wave_started(wave: int, is_boss_wave: bool)
@warning_ignore("unused_signal")
signal wave_cleared(wave: int)
## A boss (EnemyData.is_boss) entered the fight, for the announcement and its health bar.
@warning_ignore("unused_signal")
signal boss_spawned(enemy: Node3D)
## A door was bought and its zone is open (section 4). `source` is the player who paid.
@warning_ignore("unused_signal")
signal zone_unlocked(zone: StringName, source: Node3D)
## An event (section 8a) has news for every player: already translated, shown as a banner.
@warning_ignore("unused_signal")
signal event_announced(text: String)
