class_name EnemyData
extends Resource
## Every enemy type is one of these, applied to the shared enemy scene.

@export var id: StringName
## Translation key, not display text.
@export var display_name: String
## HP = base_health + health_per_wave * wave.
@export var base_health: int = 100
@export var health_per_wave: int = 0
## Metres per second.
@export var speed: float = 2.5
@export var damage: int = 10
## Horizontal distance (m) from which a melee swing starts.
@export var attack_range: float = 1.4
## Seconds between the swing starting and the hit landing; leaves a moment to back off.
@export var attack_windup: float = 0.45
## Seconds between swings.
@export var attack_cooldown: float = 1.1
## Seconds to climb through a window opening.
@export var climb_time: float = 1.1
## Seconds to rip one board off a barricade (6 boards ≈ 3 s, section 4).
@export var board_break_time: float = 0.5
## A headshot kill dealing at least this much damage in one hit pops the head (stylized, section 7).
@export var head_pop_damage: int = 50
@export var model: PackedScene


func health_for_wave(wave: int) -> int:
	return base_health + health_per_wave * wave
