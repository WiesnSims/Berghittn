class_name ScopeOverlay
extends Control
## The view through a hunting scope: black around a round lens, a thin crosshair and the three thick
## posts of a classic hunting reticle (left, right, below), and a dark rim inside the lens.

## Lens radius as a share of the screen height.
@export var lens_radius: float = 0.46
@export var rim_width: float = 0.05
@export var line_width: float = 1.5
## Thick posts: width in pixels, and the gap they leave around the centre as a share of the lens radius.
@export var post_width: float = 7.0
@export var post_gap: float = 0.28
@export var reticle_color: Color = Color(0.02, 0.02, 0.02, 0.95)
@export var rim_color: Color = Color(0, 0, 0, 0.55)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = size.y * lens_radius
	# A ring as wide as the screen diagonal blacks out everything outside the lens.
	var cover: float = size.length()
	draw_arc(c, r + cover * 0.5, 0.0, TAU, 96, Color.BLACK, cover)
	var rim: float = size.y * rim_width
	draw_arc(c, r - rim * 0.5, 0.0, TAU, 96, rim_color, rim)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), reticle_color, line_width)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), reticle_color, line_width)
	var gap: float = r * post_gap
	draw_line(c + Vector2(-r, 0), c + Vector2(-gap, 0), reticle_color, post_width)
	draw_line(c + Vector2(r, 0), c + Vector2(gap, 0), reticle_color, post_width)
	draw_line(c + Vector2(0, r), c + Vector2(0, gap), reticle_color, post_width)
