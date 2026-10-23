extends Node3D
## One enemy line over its head (M9 part 3, Gredn): the dialect text, facing the camera, riding along
## while the enemy is alive (staying where it fell after), then fading and gone. ShaderWarmup builds
## one with `silent` set, so the first real one does not stall.

const COLOR := Color(1.0, 0.95, 0.82)

var text: String = "…"
## Seconds it stays before fading.
var time: float = 2.0
var enemy: Enemy
## Warmup: built and left standing, no tween.
var silent: bool = false

var _label: Label3D


func _ready() -> void:
	_label = Label3D.new()
	_label.text = text
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = Constants.GREDN_PIXEL_SIZE
	_label.font_size = 28
	_label.outline_size = 10
	_label.outline_modulate = Color(0.08, 0.06, 0.05, 0.9)
	_label.modulate = COLOR
	_label.render_priority = 9
	_label.outline_render_priority = 8
	add_child(_label)
	_follow()
	if silent:
		return
	var tween: Tween = create_tween()
	tween.tween_interval(time)
	tween.tween_property(_label, "modulate:a", 0.0, Constants.GREDN_FADE_TIME).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_label, "outline_modulate:a", 0.0, Constants.GREDN_FADE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		enemy = null
		return
	global_position = enemy.global_position + Vector3.UP * Constants.GREDN_HEIGHT * enemy.data.model_scale
