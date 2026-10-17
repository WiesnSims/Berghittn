class_name AlphornViewmodel
extends Viewmodel
## Alphorn: a long wooden horn held out in front, bell curving up at the far end. Blowing makes it
## shudder for the length of the note; the Echo swings the bell up to the sky; reloading is the player
## catching their breath, the horn lowered and heaving with each gasp.

## Degrees the horn shudders at the start of a note, and seconds the note lasts.
@export var shudder_angle: float = 2.5
@export var note_time: float = 0.6
## Degrees the bell is lifted for the Echo.
@export var sky_angle: float = 55.0
## Degrees the horn is lowered while catching breath, and how far each breath lifts it (metres).
@export var rest_angle: float = -14.0
@export var breath_lift: float = 0.025


func play_fire(_rounds: int = 1) -> void:
	_flash_and_kick(1.0)
	_shudder(_rest)


func play_secondary(_rounds: int) -> void:
	# Bell up to the sky, blow, and back down.
	_restart_tween()
	_flash_left = Constants.MUZZLE_FLASH_TIME
	_flash.visible = true
	var raised: Transform3D = _rest.rotated_local(Vector3.RIGHT, deg_to_rad(sky_angle))
	_tween.tween_property(_model, "transform", raised, note_time * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in 5:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var fade: float = 1.0 - i / 5.0
		_tween.tween_property(_model, "transform", raised.rotated_local(Vector3.FORWARD, deg_to_rad(shudder_angle * 1.5 * side * fade)), note_time * 0.1)
	_tween.tween_property(_model, "transform", _rest, note_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	# Horn down, three deep breaths that lift it, then back up to the lips.
	_restart_tween()
	var d: float = duration
	var lowered: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.RIGHT, deg_to_rad(rest_angle))
	_tween.tween_property(_model, "transform", lowered, d * 0.15).set_trans(Tween.TRANS_QUAD)
	for i: int in 3:
		_tween.tween_property(_model, "transform", lowered.translated(Vector3(0, breath_lift, 0)), d * 0.1).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(_model, "transform", lowered, d * 0.1).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_model, "transform", _rest, d * 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _shudder(base: Transform3D) -> void:
	# The kick from _flash_and_kick, then a quick rattle that fades over the note.
	var steps: int = 6
	for i: int in steps:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var fade: float = 1.0 - float(i) / steps
		var shook: Transform3D = base.rotated_local(Vector3.UP, deg_to_rad(shudder_angle * side * fade)).rotated_local(Vector3.RIGHT, deg_to_rad(shudder_angle * 0.5 * fade))
		_tween.tween_property(_model, "transform", shook, note_time / steps)
	_tween.tween_property(_model, "transform", base, kick_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
