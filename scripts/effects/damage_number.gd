extends Node3D
## One damage number over an enemy (M9 part 2, off by default): floats up and fades, then goes.
## White for a hit, gold for a headshot, bigger for a kill. Drawn through walls, always facing the
## camera. ShaderWarmup builds one with `silent` set, so the first real one does not stall.

const HIT_COLOR := Color(1.0, 1.0, 1.0)
const HEAD_COLOR := Color(1.0, 0.82, 0.3)
const KILL_COLOR := Color(1.0, 0.4, 0.3)

var amount: int = 0
var headshot: bool = false
var kill: bool = false
## Warmup: built and left standing, no tween.
var silent: bool = false


func _ready() -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = Constants.DAMAGE_NUMBER_PIXEL_SIZE
	label.font_size = 40 if kill else 30
	label.outline_size = 8
	label.modulate = HEAD_COLOR if headshot else (KILL_COLOR if kill else HIT_COLOR)
	label.render_priority = 10
	add_child(label)
	if silent:
		return
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + Constants.DAMAGE_NUMBER_RISE, Constants.DAMAGE_NUMBER_TIME)
	tween.tween_property(label, "modulate:a", 0.0, Constants.DAMAGE_NUMBER_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
