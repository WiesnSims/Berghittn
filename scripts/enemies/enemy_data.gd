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
## Size of the model and its hit boxes (the body capsule and navigation stay human-sized, so big
## enemies still fit every path and window).
@export var model_scale: float = 1.0
## How far hits rock the model back (1 = full flinch); heavy enemies barely react.
@export var flinch_multiplier: float = 1.0
## Lunge (Perchte, section 7): from up to lunge_range metres away with a clear line, crouch for
## lunge_windup seconds, then leap at lunge_speed for at most lunge_time, striking for `damage` on
## contact. 0 range = no lunge. Seconds between lunges: lunge_cooldown.
@export var lunge_range: float = 0.0
@export var lunge_windup: float = 0.35
@export var lunge_speed: float = 11.0
@export var lunge_time: float = 0.35
@export var lunge_cooldown: float = 3.0
## Boss (Krampus): announced, gets a health bar, and is immune to crowd control (section 6a).
@export var is_boss: bool = false
## Left behind where it dies, for a player to pick up (the Krampus drops his Rute); null = nothing.
@export var drop: WeaponData
## Sounds (Sound ids, M6 part 2): groans now and then while it is about (one picked at random), its
## cry as it dies, and the pitch its attack grunt and death cry are played at.
@export var groan_sounds: Array[StringName] = []
@export var death_sound: StringName = &"enemy_death"
@export var voice_pitch: float = 1.0


func health_for_wave(wave: int) -> int:
	return base_health + health_per_wave * wave
