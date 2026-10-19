class_name Raurakl
extends Node3D
## Da Raurakl (M8 easter egg, user request 2026-10-19): the stuffed Wolpertinger on its shelf up on
## the Stube's gallery. Shot or struck, it spins round and grumbles; our own first hit earns the
## Raurakl-Kappl (HatUnlocks). Only on this screen: it is decoration, not part of the shared world.

const QUIPS: Array[String] = ["RAURAKL_1", "RAURAKL_2", "RAURAKL_3", "RAURAKL_4"]

var _quip: int = 0
var _tween: Tween
@onready var _model: Node3D = $Model
@onready var _bubble: Label3D = $Bubble


func _ready() -> void:
	_bubble.hide()


## Hurtbox receiver.
func receive_hit(_amount: int, _is_headshot: bool, _is_melee: bool, source: Node3D) -> Hurtbox.Result:
	if source is Player:
		HatUnlocks.earn(&"raurakl")
	if _tween and _tween.is_running():
		return Hurtbox.Result.HIT
	Sound.play_at(&"murmeltier_hit", global_position)
	_bubble.text = tr(QUIPS[_quip])
	_quip = (_quip + 1) % QUIPS.size()
	_bubble.show()
	_tween = create_tween()
	_tween.tween_property(_model, "rotation:y", _model.rotation.y + TAU * 2.0, Constants.RAURAKL_SPIN_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(Constants.RAURAKL_BUBBLE_TIME)
	_tween.tween_callback(_bubble.hide)
	return Hurtbox.Result.HIT
