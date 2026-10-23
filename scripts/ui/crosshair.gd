class_name Crosshair
extends Control
## Drawn crosshair plus a hit marker that flashes on confirmed hits, and on every kill of ours a
## bigger X (M9 part 2): red, gold for a headshot kill. The arms move apart
## with the gun's bloom, so rapid fire visibly loosens the aim; the base gap stays small.
## A ring around it fills while the gun reloads or, for the Alphorn, between notes, and pulses
## once when it is ready again (play-test, Alphorn), so the wait can be read without looking away.

@export var gap: float = 5.0
@export var arm_length: float = 8.0
@export var thickness: float = 2.0
@export var color: Color = Color(0.95, 0.95, 0.9, 0.85)
@export var hit_color: Color = Color(1, 1, 1, 1)
@export var kill_color: Color = Color(1, 0.25, 0.2, 1)
@export var hit_inner: float = 7.0
@export var hit_outer: float = 14.0
@export var head_kill_color: Color = Color(1.0, 0.8, 0.25, 1)
@export var kill_inner: float = 9.0
@export var kill_outer: float = 22.0

## Most the arms may move out, in pixels.
@export var max_spread: float = 28.0
## Ready ring: radius and width in pixels, the colours for reloading, cycling and its faint track,
## and how far the ready pulse grows (pixels).
@export var ring_radius: float = 24.0
@export var ring_width: float = 3.0
@export var reload_color: Color = Color(1.0, 0.72, 0.3, 0.9)
@export var cycle_color: Color = Color(0.95, 0.95, 0.9, 0.7)
@export var track_color: Color = Color(0.0, 0.0, 0.0, 0.35)
@export var pulse_grow: float = 10.0

var _hit_left: float = 0.0
var _spread: float = 0.0
var _hit_is_kill: bool = false
var _kill_left: float = 0.0
var _kill_is_head: bool = false
# Ring fill (0..1, -1 = no ring), whether it is a reload, and seconds left of the ready pulse.
var _progress: float = -1.0
var _reloading: bool = false
var _pulse_left: float = 0.0


## Extra gap in pixels (the bloom projected onto the screen).
func set_spread(pixels: float) -> void:
	pixels = minf(pixels, max_spread)
	if not is_equal_approx(pixels, _spread):
		_spread = pixels
		queue_redraw()


## The ready ring: `reload` and `cycle` are shares done (0..1) or -1. A cycle only shows when
## `show_cycle` (WeaponData.cycle_ring).
func set_progress(reload: float, cycle: float, show_cycle: bool) -> void:
	var was: float = _progress
	_reloading = reload >= 0.0
	if _reloading:
		_progress = reload
	elif cycle >= 0.0 and show_cycle:
		_progress = cycle
	else:
		_progress = -1.0
	if was >= 0.0 and _progress < 0.0:
		_pulse_left = Constants.READY_PULSE_TIME
	if was >= 0.0 or _progress >= 0.0:
		queue_redraw()


func show_hit(_is_headshot: bool, killed: bool) -> void:
	_hit_left = Constants.HIT_MARKER_TIME
	_hit_is_kill = killed
	queue_redraw()


## A kill of ours, whatever did it (KillFeedback): the big X.
func show_kill(is_headshot: bool) -> void:
	_kill_left = Constants.KILL_MARKER_TIME
	_kill_is_head = is_headshot
	queue_redraw()


func _process(delta: float) -> void:
	if _kill_left > 0.0:
		_kill_left -= delta
		queue_redraw()
	if _hit_left > 0.0:
		_hit_left -= delta
		queue_redraw()
	if _pulse_left > 0.0:
		_pulse_left -= delta
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * (gap + _spread), c + dir * (gap + _spread + arm_length), color, thickness)
	var radius: float = maxf(ring_radius, gap + _spread + arm_length + 4.0)
	if _progress >= 0.0:
		draw_arc(c, radius, 0.0, TAU, 48, track_color, ring_width + 2.0, true)
		# Clockwise from the top.
		var fill: Color = reload_color if _reloading else cycle_color
		draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * _progress, 48, fill, ring_width, true)
	elif _pulse_left > 0.0:
		var t: float = 1.0 - _pulse_left / Constants.READY_PULSE_TIME
		var pulse: Color = cycle_color
		pulse.a *= 1.0 - t
		draw_arc(c, radius + pulse_grow * t, 0.0, TAU, 48, pulse, ring_width, true)
	if _kill_left > 0.0:
		var kill: Color = head_kill_color if _kill_is_head else kill_color
		var share: float = clampf(_kill_left / Constants.KILL_MARKER_TIME, 0.0, 1.0)
		kill.a = share
		# Pops out a little as it fades.
		var grow: float = (1.0 - share) * 4.0
		for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var d: Vector2 = dir.normalized()
			draw_line(c + d * (kill_inner + grow), c + d * (kill_outer + grow), kill, thickness + 2.0)
		return
	if _hit_left <= 0.0:
		return
	var marker: Color = kill_color if _hit_is_kill else hit_color
	marker.a = clampf(_hit_left / Constants.HIT_MARKER_TIME, 0.0, 1.0)
	for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d: Vector2 = dir.normalized()
		draw_line(c + d * hit_inner, c + d * hit_outer, marker, thickness + 1.0)
