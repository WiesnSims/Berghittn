class_name MarkerArrows
extends Control
## Arrows at the screen edge for every MapMarker that is off screen (or behind), in its colour, with
## the distance, so an event is findable from any room (section 8a).

const MARGIN: float = 48.0
const SIZE: float = 18.0

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var center: Vector2 = size * 0.5
	var inner := Rect2(Vector2.ONE * MARGIN, size - Vector2.ONE * MARGIN * 2.0)
	for node: Node in get_tree().get_nodes_in_group("map_markers"):
		var marker := node as MapMarker
		if marker == null or not marker.is_visible_in_tree():
			continue
		var point: Vector3 = marker.focus()
		var behind: bool = camera.is_position_behind(point)
		var screen: Vector2 = camera.unproject_position(point)
		if not behind and inner.has_point(screen):
			continue
		var direction: Vector2 = screen - center
		if behind:
			direction = -direction
		if direction.length_squared() < 1.0:
			direction = Vector2.DOWN
		direction = direction.normalized()
		# Where the ray from the centre leaves the inner rectangle.
		var scale_x: float = (inner.size.x * 0.5) / maxf(absf(direction.x), 0.0001)
		var scale_y: float = (inner.size.y * 0.5) / maxf(absf(direction.y), 0.0001)
		var tip: Vector2 = center + direction * minf(scale_x, scale_y)
		var side := Vector2(-direction.y, direction.x)
		var points := PackedVector2Array([tip + direction * SIZE, tip - direction * SIZE * 0.4 + side * SIZE * 0.7, tip - direction * SIZE * 0.4 - side * SIZE * 0.7])
		draw_colored_polygon(points, marker.color)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.7), 2.0)
		var metres: String = "%d m" % roundi(camera.global_position.distance_to(point))
		var label_at: Vector2 = tip - direction * SIZE * 1.6 - Vector2(14, -5)
		draw_string_outline(_font, label_at, metres, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(_font, label_at, metres, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, marker.color)
