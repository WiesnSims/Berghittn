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
## Boss waves (section 7): from boss_first_wave on, every boss_every-th wave is the boss plus
## boss_escort_count escorts instead of the usual mix. 0 boss_every = no boss waves.
@export var boss: EnemyData
@export var boss_escort: EnemyData
@export var boss_escort_count: int = 6
@export var boss_first_wave: int = 5
@export var boss_every: int = 5
## The Venedigermandl (M9 part 5a): now and then, outside the wave count (Constants.MANDL_*).
@export var treasure: EnemyData
## Die Bsundan (1.2): the rare variants, each from its first_wave (weights are not used: each is as
## likely as the others; Constants.VARIANT_*).
@export var variants: Array[WaveEntry] = []


func is_boss_wave(wave: int) -> bool:
	return boss != null and boss_every > 0 and wave >= boss_first_wave and (wave - boss_first_wave) % boss_every == 0


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


## A variant allowed in this wave, other than `last` if another one is; null if there is none.
func pick_variant(wave: int, last: EnemyData, rng: RandomNumberGenerator) -> EnemyData:
	var allowed: Array[EnemyData] = []
	for entry: WaveEntry in variants:
		if entry.applies_to(wave):
			allowed.append(entry.enemy)
	if allowed.size() > 1:
		allowed.erase(last)
	return allowed[rng.randi() % allowed.size()] if not allowed.is_empty() else null
