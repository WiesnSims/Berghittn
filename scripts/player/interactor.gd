class_name Interactor
extends Node
## Finds the nearest thing the player can use with E (barricades now; doors and wall-buys later) and uses it.
## Interactables are nodes in group "interactables" with get_interact_position() -> Vector3,
## get_interact_prompt(player) -> String ("" = nothing to do right now), interact(player) and
## interact_repeat: float (seconds between uses while E is held; 0 = once per press).

## Emitted when the prompt to show changes; "" hides it.
signal prompt_changed(text: String)

@onready var _player: Player = get_parent()

var _target: Node3D
var _prompt: String = ""
var _repeat_left: float = 0.0


func _physics_process(delta: float) -> void:
	_target = null if _player.health.is_dead() else _find_target()
	var prompt: String = _target.get_interact_prompt(_player) if _target else ""
	if prompt != _prompt:
		_prompt = prompt
		prompt_changed.emit(_prompt)
	if _target == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed("interact"):
		_use()
	elif Input.is_action_pressed("interact") and _target.interact_repeat > 0.0:
		_repeat_left -= delta
		if _repeat_left <= 0.0:
			_use()


func _use() -> void:
	_target.interact(_player)
	_repeat_left = _target.interact_repeat


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_distance: float = Constants.INTERACT_RANGE
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		var candidate := node as Node3D
		if candidate.get_interact_prompt(_player) == "":
			continue
		var offset: Vector3 = candidate.get_interact_position() - _player.global_position
		if absf(offset.y) > Constants.INTERACT_MAX_HEIGHT:
			continue
		var distance: float = Vector2(offset.x, offset.z).length()
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best
