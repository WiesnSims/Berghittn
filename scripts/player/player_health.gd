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


func _physics_process(delta: float) -> void:
	if is_dead() or _health >= max_health:
		return
	_since_damage += delta
	if _since_damage < Constants.PLAYER_REGEN_DELAY:
		return
	var before: int = current()
	_health = minf(_health + Constants.PLAYER_REGEN_PER_SECOND * delta, max_health)
	if current() != before:
		changed.emit(current(), max_health)


func current() -> int:
	return ceili(_health)


func is_dead() -> bool:
	return _health <= 0.0


func take_damage(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	_health = maxf(_health - amount, 0.0)
	_since_damage = 0.0
	damaged.emit(amount)
	changed.emit(current(), max_health)
	if is_dead():
		died.emit()
