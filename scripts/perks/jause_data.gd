class_name JauseData
extends Resource
## One thing on the Brettljause in the Speis (section 9): bought again and again, each helping raises a
## stat a little more and costs more than the last. Kept for the whole run, even when downed.

@export var id: StringName
## Translation keys: what it is (stays dialect) and what one helping gives.
@export var display_name: String
@export var description: String
@export var base_cost: int = 750
## Added to the price for every helping already eaten.
@export var cost_step: int = 750
@export var max_level: int = 5
## Per helping. Shares: 0.1 = +10 %.
@export var max_health_bonus: int = 0
@export var reload_speed_bonus: float = 0.0
@export var damage_bonus: float = 0.0


func cost_at(level: int) -> int:
	return base_cost + cost_step * level
