class_name PlayerHealth
extends Node
## Health with delayed regeneration (section 5). Solo: reaching 0 is game over.

signal changed(current: int, maximum: int)
signal damaged(amount: int)
signal died

var max_health: int = Constants.PLAYER_MAX_HEALTH
# Float so regeneration can accumulate fractions between frames; the UI sees whole numbers.
var _health: float = Constants.PLAYER_MAX_HEALTH
var _since_damage: float = 0.0
## Perks (PlayerPerks): seconds nothing gets through (Sturschädl), faster healing that starts at once
## (Gmiatlichkeit), and a last chance asked before a hit kills (returns true to survive at 1 HP).
var invincible_left: float = 0.0
var regen_multiplier: float = 1.0
var regen_skips_delay: bool = false
var death_guard: Callable


func _physics_process(delta: float) -> void:
	invincible_left = maxf(invincible_left - delta, 0.0)
	if is_dead() or _health >= max_health:
		return
	_since_damage += delta
	if _since_damage < Constants.PLAYER_REGEN_DELAY and not regen_skips_delay:
		return
	var before: int = current()
	_health = minf(_health + Constants.PLAYER_REGEN_PER_SECOND * regen_multiplier * delta, max_health)
	if current() != before:
		changed.emit(current(), max_health)


## Speck from the Brettljause raises the maximum, and the new health comes with it.
func raise_max(amount: int) -> void:
	max_health += amount
	_health += amount
	changed.emit(current(), max_health)


## Co-op (M7): up again after going down (revived, or back next wave) with this share of the maximum.
func revive(share: float) -> void:
	_health = maxf(max_health * share, 1.0)
	_since_damage = 0.0
	invincible_left = 0.0
	changed.emit(current(), max_health)


func heal_full() -> void:
	_health = max_health
	changed.emit(current(), max_health)


func current() -> int:
	return ceili(_health)


func is_dead() -> bool:
	return _health <= 0.0


func take_damage(amount: int) -> void:
	if is_dead() or amount <= 0 or invincible_left > 0.0:
		return
	var left: float = _health - amount
	if left <= 0.0 and death_guard.is_valid() and death_guard.call():
		left = 1.0
	_health = maxf(left, 0.0)
	_since_damage = 0.0
	damaged.emit(amount)
	changed.emit(current(), max_health)
	if is_dead():
		died.emit()
