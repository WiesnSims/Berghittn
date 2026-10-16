class_name WaveTable
extends Resource
## Wave sizes, pacing and enemy mix (section 8). Tune data/wave_table.tres, not the code.

## Enemies per wave (solo) = base_enemies + enemies_per_wave * n.
@export var base_enemies: int = 6
@export var enemies_per_wave: int = 2
## Co-op: the count is multiplied by 1 + coop_extra_per_player * (players - 1).
@export var coop_extra_per_player: float = 0.5
## Seconds between spawns = max(min_spawn_interval, start_spawn_interval - spawn_interval_step * n).
@export var start_spawn_interval: float = 2.5
@export var spawn_interval_step: float = 0.1
@export var min_spawn_interval: float = 0.6
## Seconds of break between waves.
@export var break_time: float = 10.0
@export var entries: Array[WaveEntry] = []


func enemy_count(wave: int, players: int) -> int:
	var solo: int = base_enemies + enemies_per_wave * wave
	return roundi(solo * (1.0 + coop_extra_per_player * (maxi(players, 1) - 1)))


func spawn_interval(wave: int) -> float:
	return maxf(min_spawn_interval, start_spawn_interval - spawn_interval_step * wave)


## Weighted random pick among the entries active in this wave; null if none are.
func pick_enemy(wave: int, rng: RandomNumberGenerator) -> EnemyData:
	var total: float = 0.0
	for entry: WaveEntry in entries:
		if entry.applies_to(wave):
			total += entry.weight
	var roll: float = rng.randf() * total
	for entry: WaveEntry in entries:
		if not entry.applies_to(wave):
			continue
		roll -= entry.weight
		if roll <= 0.0:
			return entry.enemy
	return null
