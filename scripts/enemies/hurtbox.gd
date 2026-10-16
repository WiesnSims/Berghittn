class_name Hurtbox
extends Area3D
## Damage receiving volume on an enemy. Separate from the movement capsule so heads can be told apart.

enum Result { IGNORED, HIT, KILLED }

@export var is_head: bool = false
## The node that owns the health; must implement receive_hit(amount, is_headshot, is_melee, source) -> Result.
@export var receiver: Node


func take_hit(damage: int, headshot_multiplier: float, is_melee: bool, source: Node3D) -> Result:
	var amount: int = roundi(damage * headshot_multiplier) if is_head else damage
	return receiver.receive_hit(amount, is_head, is_melee, source)
