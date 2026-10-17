class_name PerkBottle
extends Node3D
## One bottle on the Schnaps shrine (section 9): look at it and press E to buy that perk.

@export var perk: PerkData

## Bought with one press, not held.
var interact_repeat: float = 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group("interactables")


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return global_position


func get_interact_prompt(player: Node3D) -> String:
	var buyer := player as Player
	if not buyer.perks.wants(perk):
		return ""
	var perk_name: String = tr(perk.display_name)
	if not buyer.points.can_afford(perk.cost):
		return tr("UI_PERK_NEED") % [perk_name, perk.cost]
	return tr("UI_PERK_BUY") % [perk_name, perk.cost, tr(perk.description)]


func interact(player: Node3D) -> void:
	var buyer := player as Player
	if not buyer.perks.wants(perk) or not buyer.points.spend(perk.cost):
		return
	buyer.perks.add(perk)
	# A little toast from the bottle: it tips, pours and stands back up.
	if _tween:
		_tween.kill()
	rotation = Vector3.ZERO
	_tween = create_tween()
	_tween.tween_property(self, "rotation:z", deg_to_rad(-35.0), 0.15).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "rotation:z", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
