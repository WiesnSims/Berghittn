class_name PerkData
extends Resource
## One Schnaps from the shrine (section 9). Bought once per life; lost when downed.

@export var id: StringName
## Translation keys: the Schnaps' name (stays dialect) and what it does.
@export var display_name: String
@export var description: String
@export var cost: int = 1000
## Bottle and HUD icon colour.
@export var color: Color = Color.WHITE
## Effects. Bonuses are shares (0.25 = +25 %); a perk only sets the ones it gives.
@export var max_health_bonus: int = 0
@export var reload_speed_bonus: float = 0.0
@export var revive_speed_bonus: float = 0.0
@export var move_speed_bonus: float = 0.0
@export var damage_bonus: float = 0.0
