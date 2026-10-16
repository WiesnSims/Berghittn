class_name WaveEntry
extends Resource
## One enemy type in the wave mix: which enemy, from which wave on, and how often relative to the others.

@export var enemy: EnemyData
@export var first_wave: int = 1
## Relative chance against the other active entries; 0 = never picked.
@export var weight: float = 1.0
## 0 = no upper limit.
@export var last_wave: int = 0


func applies_to(wave: int) -> bool:
	return wave >= first_wave and (last_wave <= 0 or wave <= last_wave) and weight > 0.0
