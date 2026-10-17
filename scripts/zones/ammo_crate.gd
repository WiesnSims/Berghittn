class_name AmmoCrate
extends Node3D
## Munitionskiste in the Matratzenlager (user request, 2026-10-17: every room has a purpose):
## refills the reserve of every carried gun at once, the only refill for guns from the chest.

@export var cost: int = 1000

## Bought with one press, not held.
var interact_repeat: float = 0.0
var _tween: Tween
@onready var _lid: Node3D = $Lid


func _ready() -> void:
	add_to_group("interactables")


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return to_global(Vector3(0.0, 0.5, -0.9))


func get_interact_prompt(player: Node3D) -> String:
	var buyer := player as Player
	if not buyer.weapons.needs_any_ammo():
		return ""
	var key: String = "UI_AMMO_CRATE" if buyer.points.can_afford(cost) else "UI_AMMO_CRATE_NEED"
	return tr(key) % cost


func interact(player: Node3D) -> void:
	var buyer := player as Player
	if not buyer.weapons.needs_any_ammo() or not buyer.points.spend(cost):
		return
	buyer.weapons.refill_all()
	# The lid pops up and drops shut again.
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation:x", deg_to_rad(40.0), 0.15).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_lid, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
