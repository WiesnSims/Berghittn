extends Label
## FPS and position readout for checking performance and movement in browser builds. Toggle with F3.
## While it is on, F4 adds points, for testing doors and wall-buys without playing for them.

var _since_refresh: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible
	elif visible and event.is_action_pressed("debug_points"):
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			player.points.add(Constants.DEBUG_POINTS)


func _process(delta: float) -> void:
	_since_refresh += delta
	if _since_refresh < Constants.DEBUG_OVERLAY_REFRESH:
		return
	_since_refresh = 0.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var pos: Vector3 = player.global_position if player else Vector3.ZERO
	text = tr("UI_DEBUG_OVERLAY") % [Engine.get_frames_per_second(), pos.x, pos.y, pos.z]
