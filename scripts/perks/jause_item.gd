class_name JauseItem
extends Node3D
## One thing on the Brettljause: look at it and press E for another helping (section 9).

@export var jause: JauseData
## Shows the next price and the helpings so far.
@export var price_label: Label3D

var interact_repeat: float = 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group("interactables")
	_update_label(0)


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return global_position


func get_interact_prompt(player: Node3D) -> String:
	var buyer := player as Player
	var level: int = buyer.perks.jause_level(jause)
	var item: String = tr(jause.display_name)
	if level >= jause.max_level:
		return tr("UI_JAUSE_FULL") % item
	var cost: int = jause.cost_at(level)
	if not buyer.points.can_afford(cost):
		return tr("UI_PERK_NEED") % [item, cost]
	return tr("UI_JAUSE_BUY") % [item, cost, tr(jause.description), level + 1, jause.max_level]


func interact(player: Node3D) -> void:
	var buyer := player as Player
	var level: int = buyer.perks.jause_level(jause)
	if level >= jause.max_level or not buyer.points.spend(jause.cost_at(level)):
		return
	buyer.perks.eat(jause)
	_update_label(level + 1)
	# A little hop, like a plate set down hard.
	if _tween:
		_tween.kill()
	scale = Vector3.ONE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE * 1.25, 0.08)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_label(level: int) -> void:
	if price_label == null:
		return
	# Price and helpings only; the name is in the prompt, and three names do not fit the table edge.
	if level >= jause.max_level:
		price_label.text = "%d/%d" % [level, jause.max_level]
	else:
		price_label.text = "%d\n%d/%d" % [jause.cost_at(level), level, jause.max_level]
