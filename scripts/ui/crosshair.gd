class_name Crosshair
extends Control
## Drawn crosshair plus a hit marker that flashes on confirmed hits (red on kills). The arms move apart
## with the gun's bloom, so rapid fire visibly loosens the aim; the base gap stays small.

@export var gap: float = 5.0
@export var arm_length: float = 8.0
@export var thickness: float = 2.0
@export var color: Color = Color(0.95, 0.95, 0.9, 0.85)
@export var hit_color: Color = Color(1, 1, 1, 1)
@export var kill_color: Color = Color(1, 0.25, 0.2, 1)
@export var hit_inner: float = 7.0
@export var hit_outer: float = 14.0

## Most the arms may move out, in pixels.
@export var max_spread: float = 28.0

var _hit_left: float = 0.0
var _spread: float = 0.0
var _hit_is_kill: bool = false


## Extra gap in pixels (the bloom projected onto the screen).
func set_spread(pixels: float) -> void:
	pixels = minf(pixels, max_spread)
	if not is_equal_approx(pixels, _spread):
		_spread = pixels
		queue_redraw()


func show_hit(_is_headshot: bool, killed: bool) -> void:
	_hit_left = Constants.HIT_MARKER_TIME
	_hit_is_kill = killed
	queue_redraw()


func _process(delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left -= delta
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * (gap + _spread), c + dir * (gap + _spread + arm_length), color, thickness)
	if _hit_left <= 0.0:
		return
	var marker: Color = kill_color if _hit_is_kill else hit_color
	marker.a = clampf(_hit_left / Constants.HIT_MARKER_TIME, 0.0, 1.0)
	for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d: Vector2 = dir.normalized()
		draw_line(c + d * hit_inner, c + d * hit_outer, marker, thickness + 1.0)
