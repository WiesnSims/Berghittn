class_name PlayerPerks
extends Node
## The Schnaps this player has had (section 9) and what they add up to. Gone when the player goes down.

signal changed(perks: Array[PerkData])

var owned: Array[PerkData] = []
@onready var _health: PlayerHealth = get_parent().get_node("Health")


func _ready() -> void:
	_health.died.connect(clear)


func has(perk: PerkData) -> bool:
	return owned.any(func(p: PerkData) -> bool: return p.id == perk.id)


func add(perk: PerkData) -> void:
	if has(perk):
		return
	owned.append(perk)
	if perk.max_health_bonus > 0:
		_health.raise_max(perk.max_health_bonus)
	changed.emit(owned)


func clear() -> void:
	if owned.is_empty():
		return
	owned.clear()
	_health.reset_max()
	changed.emit(owned)


## Weapon damage factor.
func damage_multiplier() -> float:
	return 1.0 + _sum(func(p: PerkData) -> float: return p.damage_bonus)


## Reload time factor: +25 % reload speed makes a reload take 1 / 1.25 of the time.
func reload_time_multiplier() -> float:
	return 1.0 / (1.0 + _sum(func(p: PerkData) -> float: return p.reload_speed_bonus))


## Revive time factor (co-op, M7).
func revive_time_multiplier() -> float:
	return 1.0 / (1.0 + _sum(func(p: PerkData) -> float: return p.revive_speed_bonus))


func move_speed_multiplier() -> float:
	return 1.0 + _sum(func(p: PerkData) -> float: return p.move_speed_bonus)


func _sum(field: Callable) -> float:
	var total: float = 0.0
	for perk: PerkData in owned:
		total += field.call(perk)
	return total
