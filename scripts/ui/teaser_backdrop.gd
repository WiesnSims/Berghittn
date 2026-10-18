class_name TeaserBackdrop
extends Control
## The title screen's background (#77): a still from the game (tools/teaser), alive in 2D only, so it
## costs no 3D shaders while the hut's are still being built behind it (#78). It drifts slowly like a
## camera, snow blows past, the Stube lamp flickers, and now and then the Jagdflinte goes off: a
## flash at its muzzle, the room lit up for a moment and a little kick. While the shaders are built
## it holds still (set_animated): those frames come in bursts, and motion would show every one.

const PICTURE: Texture2D = preload("res://assets/ui/teaser.jpg")
## Where the Jagdflinte's muzzle and the Stube lamp are in the picture (0..1; printed by tools/teaser).
const MUZZLE_AT: Vector2 = Vector2(0.513, 0.248)
const LAMP_AT: Vector2 = Vector2(0.693, 0.239)
## How far the picture drifts and zooms over one slow cycle (s).
const DRIFT_TIME: float = 24.0
const ZOOM: float = 1.08
const DRIFT: Vector2 = Vector2(0.025, 0.012)
## Seconds between shots, and how long a flash lasts.
const SHOT_GAP: Vector2 = Vector2(2.5, 5.5)
const FLASH_TIME: float = 0.12
const KICK: float = 6.0

var _picture: TextureRect
var _muzzle: TextureRect
var _lamp: TextureRect
var _flash_fill: ColorRect
var _snow_drift: CPUParticles2D
var _animated: bool = true
var _time: float = 0.0
var _shot_left: float = 1.5
var _flash_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.randomize()
	_picture = TextureRect.new()
	_picture.texture = PICTURE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_lamp = _glow(Color(1.0, 0.75, 0.45, 0.0), 260.0)
	_muzzle = _glow(Color(1.0, 0.85, 0.5, 0.0), 220.0)
	_flash_fill = ColorRect.new()
	_flash_fill.color = Color(1.0, 0.8, 0.5, 0.0)
	_flash_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash_fill.material = add
	add_child(_flash_fill)
	_snow_drift = _snow()
	add_child(_snow_drift)
	add_child(_shade())


## Still (the lamp at rest, no snow, no shots) or alive.
func set_animated(on: bool) -> void:
	_animated = on
	_snow_drift.emitting = on
	_snow_drift.visible = on
	if on:
		_snow_drift.restart()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _animated:
		delta = 0.0
	_time += delta
	# Cover the screen at any aspect, a bit larger than it, drifting slowly back and forth.
	var phase: float = sin(_time / DRIFT_TIME * TAU)
	var zoom: float = lerpf(1.0 + (ZOOM - 1.0) * 0.5, ZOOM, 0.5 + 0.5 * phase)
	var cover: float = maxf(size.x / PICTURE.get_width(), size.y / PICTURE.get_height()) * zoom
	var shown := Vector2(PICTURE.get_size()) * cover
	var offset: Vector2 = (size - shown) * 0.5 + Vector2(DRIFT.x * phase, DRIFT.y * cos(_time / DRIFT_TIME * TAU)) * size
	_shot(delta)
	if _flash_left > 0.0:
		offset += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * KICK * (_flash_left / FLASH_TIME)
	_picture.position = offset
	_picture.size = shown
	_place(_muzzle, offset + shown * MUZZLE_AT)
	_place(_lamp, offset + shown * LAMP_AT)
	# A paraffin lamp: a slow breath with a quick flutter on top.
	_lamp.modulate.a = 0.28 + 0.1 * sin(_time * 2.3) + 0.06 * sin(_time * 13.0 + sin(_time * 3.0))


func _shot(delta: float) -> void:
	_shot_left -= delta
	if _shot_left <= 0.0:
		_shot_left = _rng.randf_range(SHOT_GAP.x, SHOT_GAP.y)
		_flash_left = FLASH_TIME
	_flash_left = maxf(_flash_left - delta, 0.0)
	var flash: float = _flash_left / FLASH_TIME
	_muzzle.modulate.a = flash
	_flash_fill.color.a = 0.18 * flash


func _place(glow: TextureRect, at: Vector2) -> void:
	glow.position = at - glow.size * 0.5


func _glow(color: Color, diameter: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	var glow := TextureRect.new()
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2.ONE * diameter
	glow.self_modulate = Color(color.r, color.g, color.b, 1.0)
	glow.modulate.a = color.a
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	add_child(glow)
	return glow


## Snow blowing past the window side of the picture, in front of everything.
func _snow() -> CPUParticles2D:
	var snow := CPUParticles2D.new()
	snow.amount = 140
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(1400.0, 10.0)
	snow.position = Vector2(700.0, -20.0)
	snow.direction = Vector2(-0.35, 1.0)
	snow.spread = 12.0
	snow.gravity = Vector2.ZERO
	snow.initial_velocity_min = 70.0
	snow.initial_velocity_max = 150.0
	snow.scale_amount_min = 1.5
	snow.scale_amount_max = 4.0
	snow.color = Color(1.0, 1.0, 1.0, 0.7)
	return snow


## Darker towards the left, where the title and the buttons are, and at the bottom.
func _shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.04, 0.88))
	gradient.set_color(1, Color(0.02, 0.02, 0.04, 0.0))
	gradient.add_point(0.45, Color(0.02, 0.02, 0.04, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(0.75, 0.5)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade
