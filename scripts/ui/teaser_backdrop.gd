class_name TeaserBackdrop
extends Control
## The title screen's background (#77): stills from the game (tools/teaser), alive in 2D only, so it
## costs no 3D shaders while the hut's are still being built behind it (#78). Since 1.1.2 there are
## seven (SCENES), a random one first and then the next every SLIDE_TIME, crossfading. Each drifts
## slowly like a camera and has its own life: the Jagdflinte going off in the Stube, gold glittering
## round the Venedigermandl, Bergdohlen circling, the Wilderer's scope glinting before his shot,
## sparks off the Dengelstock, three guns going off in turn, the lantern by the Krampus. Snow blows
## past in front of them all. While the shaders are built it holds still (set_animated): those
## frames come in bursts, and motion would show every one.

## Each scene: its picture and its effects, each [kind, spots on the picture (0..1; printed by
## tools/teaser)].
##   shot: a muzzle flash now and then, lighting the room with a little kick; lamp: a paraffin lamp's
##   flicker; volley: several muzzles taking turns; gold: glitter round a spot; birds: a flock
##   circling a spot; glint: a scope glinting faster until the shot; sparks: hammer blows on an
##   anvil, with the forge's glow; lantern: a lantern swinging a little from its hook.
const SCENES: Dictionary = {
	"stube": {"picture": "res://assets/ui/teaser_stube.jpg", "effects": [
		["lamp", [Vector2(0.693, 0.239)]], ["shot", [Vector2(0.513, 0.248)]]]},
	"mandl": {"picture": "res://assets/ui/teaser_mandl.jpg", "effects": [
		["gold", [Vector2(0.504, 0.474)]], ["shot", [Vector2(0.476, 0.192)]]]},
	"dohlen": {"picture": "res://assets/ui/teaser_dohlen.jpg", "effects": [
		["birds", [Vector2(0.46, 0.25)]]]},
	"wilderer": {"picture": "res://assets/ui/teaser_wilderer.jpg", "effects": [
		["lamp", [Vector2(0.6, 0.137)]], ["glint", [Vector2(0.48, 0.482)]]]},
	"dengel": {"picture": "res://assets/ui/teaser_dengel.jpg", "effects": [
		["sparks", [Vector2(0.446, 0.444), Vector2(0.445, 0.38)]], ["shot", [Vector2(0.76, 0.284)]]]},
	"coop": {"picture": "res://assets/ui/teaser_coop.jpg", "effects": [
		["lamp", [Vector2(0.47, 0.247)]], ["volley", [Vector2(0.686, 0.337), Vector2(0.349, 0.33), Vector2(0.516, 0.324)]]]},
	"krampus": {"picture": "res://assets/ui/teaser_krampus.jpg", "effects": [
		["lantern", [Vector2(0.667, 0.348), Vector2(0.666, 0.25)]]]},
}
## Seconds each picture shows, and how long the crossfade to the next takes.
const SLIDE_TIME: float = 20.0
const FADE_TIME: float = 2.5
## How far the picture drifts and zooms over one slow cycle (s).
const DRIFT_TIME: float = 24.0
const ZOOM: float = 1.08
const DRIFT: Vector2 = Vector2(0.025, 0.012)
## Seconds between shots, and how long a flash lasts.
const SHOT_GAP: Vector2 = Vector2(2.5, 5.5)
const FLASH_TIME: float = 0.12
const KICK: float = 6.0
## The pictures are made at this width; sizes in pixels below are for it.
const PICTURE_WIDTH: float = 1920.0

## The order the pictures come in (a random one first), and which is showing.
var order: Array[String] = []
var showing: int = 0
var _slide: Slide
var _next: Slide
var _fade_left: float = 0.0
var _slide_left: float = SLIDE_TIME
var _snow_drift: CPUParticles2D
var _animated: bool = true
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.randomize()
	for scene: String in SCENES:
		order.append(scene)
	# Shuffled with our own generator, so a test can seed it.
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: String = order[i]
		order[i] = order[j]
		order[j] = swap
	_slide = _make_slide(order[0], load(_picture(0)) as Texture2D)
	_request(1)
	_snow_drift = _snow()
	add_child(_snow_drift)
	add_child(_shade())


## Still (the lamps at rest, no snow, no shots, no change of picture) or alive.
func set_animated(on: bool) -> void:
	_animated = on
	_snow_drift.emitting = on
	_snow_drift.visible = on
	if on:
		_snow_drift.restart()


## The scene now showing.
func scene() -> String:
	return order[showing]


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _animated:
		delta = 0.0
	_slide_left -= delta
	if _slide_left <= 0.0 and _next == null:
		_begin_fade()
	if _next:
		_fade_left = maxf(_fade_left - delta, 0.0)
		_next.modulate.a = 1.0 - _fade_left / FADE_TIME
		_next.step(delta, size)
		if _fade_left <= 0.0:
			_end_fade()
	_slide.step(delta, size)


func _begin_fade() -> void:
	var index: int = (showing + 1) % order.size()
	var path: String = _picture(index)
	# Asked for when the last one came up; waits here only if it is not in yet.
	var picture := ResourceLoader.load_threaded_get(path) as Texture2D if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(path) as Texture2D
	_next = _make_slide(order[index], picture)
	_next.modulate.a = 0.0
	_fade_left = FADE_TIME


func _end_fade() -> void:
	_slide.queue_free()
	_slide = _next
	_next = null
	_slide.modulate.a = 1.0
	showing = (showing + 1) % order.size()
	_slide_left = SLIDE_TIME
	_request(showing + 1)


func _picture(index: int) -> String:
	return SCENES[order[index % order.size()]]["picture"]


## The picture after this one, loaded in the background meanwhile.
func _request(index: int) -> void:
	var path: String = _picture(index)
	if not ResourceLoader.has_cached(path):
		ResourceLoader.load_threaded_request(path)


func _make_slide(id: String, picture: Texture2D) -> Slide:
	var slide := Slide.new()
	slide.setup(id, picture, SCENES[id]["effects"], _rng)
	add_child(slide)
	# Over the one showing, under the snow and the shade.
	move_child(slide, _slide.get_index() + 1 if _slide else 0)
	return slide


## Snow blowing past in front of everything.
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


## A soft round glow, added to what is under it.
static func glow(color: Color, diameter: float) -> TextureRect:
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
	var light := TextureRect.new()
	light.texture = texture
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.size = Vector2.ONE * diameter
	light.self_modulate = Color(color.r, color.g, color.b, 1.0)
	light.modulate.a = color.a
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.material = _additive()
	return light


static func _additive() -> CanvasItemMaterial:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return add


## One picture with its effects, drifting on its own.
class Slide:
	extends Control

	var id: String
	var picture: Texture2D
	var _image: TextureRect
	var _flash_fill: ColorRect
	var _effects: Array = []
	var _rng: RandomNumberGenerator
	var _time: float = 0.0
	# The kick of the last shot (s left).
	var _kick_left: float = 0.0

	func setup(scene_id: String, texture: Texture2D, effects: Array, rng: RandomNumberGenerator) -> void:
		id = scene_id
		picture = texture
		_rng = rng
		# Each starts at its own point of the drift.
		_time = rng.randf_range(0.0, DRIFT_TIME)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_image = TextureRect.new()
		_image.texture = picture
		_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_image)
		for effect: Array in effects:
			_effects.append(Effect.make(effect[0], effect[1], self))
		_flash_fill = ColorRect.new()
		_flash_fill.color = Color(1.0, 0.8, 0.5, 0.0)
		_flash_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_fill.material = TeaserBackdrop._additive()
		add_child(_flash_fill)

	## The kinds of effect this picture has.
	func kinds() -> Array[String]:
		var out: Array[String] = []
		for effect: Effect in _effects:
			out.append(effect.kind)
		return out

	## A shot went off: the room lit up and a little kick.
	func flash(amount: float) -> void:
		_kick_left = maxf(_kick_left, FLASH_TIME * amount)

	func step(delta: float, area: Vector2) -> void:
		_time += delta
		# Cover the screen at any aspect, a bit larger than it, drifting slowly back and forth.
		var phase: float = sin(_time / DRIFT_TIME * TAU)
		var zoom: float = lerpf(1.0 + (ZOOM - 1.0) * 0.5, ZOOM, 0.5 + 0.5 * phase)
		var cover: float = maxf(area.x / picture.get_width(), area.y / picture.get_height()) * zoom
		var shown := Vector2(picture.get_size()) * cover
		var offset: Vector2 = (area - shown) * 0.5 + Vector2(DRIFT.x * phase, DRIFT.y * cos(_time / DRIFT_TIME * TAU)) * area
		_kick_left = maxf(_kick_left - delta, 0.0)
		var kick: float = _kick_left / FLASH_TIME
		if kick > 0.0:
			offset += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * KICK * kick
		_flash_fill.color.a = 0.18 * kick
		_image.position = offset
		_image.size = shown
		var scale_by: float = shown.x / PICTURE_WIDTH
		for effect: Effect in _effects:
			effect.step(delta, _time, offset, shown, scale_by)


## One of a picture's effects (SCENES): built over the picture, placed by its spots each frame.
class Effect:
	extends RefCounted

	var kind: String
	var spots: Array
	var slide: Slide
	var _lights: Array[TextureRect] = []
	var _particles: CPUParticles2D
	var _birds: Node2D
	var _left: Array[float] = []
	var _flash_left: Array[float] = []

	static func make(effect_kind: String, at: Array, owner: Slide) -> Effect:
		var effect := Effect.new()
		effect.kind = effect_kind
		effect.spots = at
		effect.slide = owner
		effect._build()
		return effect

	func _build() -> void:
		var rng: RandomNumberGenerator = slide._rng
		match kind:
			"lamp":
				_lights.append(_light(Color(1.0, 0.75, 0.45, 0.0), 260.0))
			"shot", "volley":
				for i: int in spots.size():
					_lights.append(_light(Color(1.0, 0.85, 0.5, 0.0), 220.0))
					# The first goes off soon; in a volley they take turns.
					_left.append(rng.randf_range(0.8, 1.6) + 0.9 * i)
					_flash_left.append(0.0)
			"gold":
				_lights.append(_light(Color(1.0, 0.82, 0.35, 0.0), 300.0))
				_particles = _sparkle(Color(1.0, 0.85, 0.35), 40, 1.2)
				_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
				_particles.emission_sphere_radius = 70.0
				_particles.gravity = Vector2(0.0, -12.0)
				_particles.initial_velocity_max = 20.0
				_particles.scale_amount_min = 2.0
				_particles.scale_amount_max = 4.5
			"birds":
				_birds = Flock.new()
				slide.add_child(_birds)
			"glint":
				_lights.append(_light(Color(1.0, 0.95, 0.75, 0.0), 90.0))
				_lights.append(_light(Color(1.0, 0.85, 0.5, 0.0), 240.0))
				_left.append(rng.randf_range(1.0, 2.0))
				_flash_left.append(0.0)
			"sparks":
				_lights.append(_light(Color(1.0, 0.55, 0.2, 0.0), 420.0))
				_lights.append(_light(Color(1.0, 0.75, 0.35, 0.0), 160.0))
				_particles = _sparkle(Color(1.0, 0.7, 0.3), 26, 0.6)
				_particles.one_shot = true
				_particles.emitting = false
				_particles.explosiveness = 0.95
				_particles.direction = Vector2.UP
				_particles.spread = 70.0
				_particles.gravity = Vector2(0.0, 500.0)
				_particles.initial_velocity_min = 120.0
				_particles.initial_velocity_max = 260.0
				_left.append(0.5)
				_flash_left.append(0.0)
			"lantern":
				_lights.append(_light(Color(1.0, 0.65, 0.35, 0.0), 360.0))

	func _light(color: Color, diameter: float) -> TextureRect:
		var light: TextureRect = TeaserBackdrop.glow(color, diameter)
		light.set_meta("diameter", diameter)
		slide.add_child(light)
		return light

	func _sparkle(color: Color, amount: int, lifetime: float) -> CPUParticles2D:
		var sparks := CPUParticles2D.new()
		sparks.amount = amount
		sparks.lifetime = lifetime
		sparks.color = color
		sparks.material = TeaserBackdrop._additive()
		slide.add_child(sparks)
		return sparks

	func step(delta: float, time: float, offset: Vector2, shown: Vector2, scale_by: float) -> void:
		for light: TextureRect in _lights:
			light.size = Vector2.ONE * float(light.get_meta("diameter")) * scale_by
		match kind:
			"lamp":
				# A paraffin lamp: a slow breath with a quick flutter on top.
				_place(_lights[0], offset + shown * spots[0])
				_lights[0].modulate.a = 0.28 + 0.1 * sin(time * 2.3) + 0.06 * sin(time * 13.0 + sin(time * 3.0))
			"shot", "volley":
				for i: int in spots.size():
					_left[i] -= delta
					if _left[i] <= 0.0:
						_left[i] = slide._rng.randf_range(SHOT_GAP.x, SHOT_GAP.y) * (0.6 if kind == "volley" else 1.0)
						_flash_left[i] = FLASH_TIME
						slide.flash(1.0 if kind == "shot" else 0.6)
					_flash_left[i] = maxf(_flash_left[i] - delta, 0.0)
					_place(_lights[i], offset + shown * spots[i])
					_lights[i].modulate.a = _flash_left[i] / FLASH_TIME
			"gold":
				var at: Vector2 = offset + shown * spots[0]
				_place(_lights[0], at)
				_lights[0].modulate.a = 0.35 + 0.15 * sin(time * 3.1)
				_particles.position = at
				_particles.scale = Vector2.ONE * scale_by
			"birds":
				_birds.position = offset + shown * spots[0]
				_birds.scale = Vector2.ONE * scale_by
				(_birds as Flock).fly(delta)
			"glint":
				# The scope glints, faster and brighter as the shot comes, then the shot.
				_left[0] -= delta
				var share: float = clampf(1.0 - _left[0] / 3.0, 0.0, 1.0)
				var pulse: float = 0.5 + 0.5 * sin(time * lerpf(4.0, 22.0, share))
				if _left[0] <= 0.0:
					_left[0] = slide._rng.randf_range(3.5, 5.0)
					_flash_left[0] = FLASH_TIME
					slide.flash(0.8)
				_flash_left[0] = maxf(_flash_left[0] - delta, 0.0)
				var at: Vector2 = offset + shown * spots[0]
				_place(_lights[0], at)
				_place(_lights[1], at)
				_lights[0].modulate.a = (0.25 + 0.75 * share) * pulse
				_lights[1].modulate.a = _flash_left[0] / FLASH_TIME
			"sparks":
				# The forge glows; the hammer comes down every blow, with sparks and a flash.
				_left[0] -= delta
				if _left[0] <= 0.0:
					_left[0] = Constants.DENGEL_BLOW_TIME
					_flash_left[0] = 0.18
					_particles.restart()
				_flash_left[0] = maxf(_flash_left[0] - delta, 0.0)
				_place(_lights[0], offset + shown * spots[1])
				_lights[0].modulate.a = 0.3 + 0.08 * sin(time * 7.0) + 0.05 * sin(time * 17.0)
				_place(_lights[1], offset + shown * spots[0])
				_lights[1].modulate.a = _flash_left[0] / 0.18
				_particles.position = offset + shown * spots[0]
				_particles.scale = Vector2.ONE * scale_by
			"lantern":
				# Swinging a little from its hook in the wind, and flickering.
				var hook: Vector2 = offset + shown * spots[1]
				var hang: Vector2 = shown * (spots[0] - spots[1])
				_place(_lights[0], hook + hang.rotated(0.12 * sin(time * 1.4)))
				_lights[0].modulate.a = 0.32 + 0.06 * sin(time * 9.0) + 0.04 * sin(time * 23.0)

	func _place(light: TextureRect, at: Vector2) -> void:
		light.position = at - light.size * 0.5


## Bergdohlen circling, small and dark against the sky, beating their wings.
class Flock:
	extends Node2D

	const COUNT: int = 6
	var _time: float = 0.0
	var _birds: Array[Vector4] = []

	func _init() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i: int in COUNT:
			# Radius across, radius up, speed (rad/s), phase.
			_birds.append(Vector4(rng.randf_range(160.0, 420.0), rng.randf_range(40.0, 110.0), rng.randf_range(0.35, 0.6) * (1.0 if i % 3 else -1.0), rng.randf_range(0.0, TAU)))

	func fly(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for bird: Vector4 in _birds:
			var angle: float = bird.w + _time * bird.z
			var at := Vector2(cos(angle) * bird.x, sin(angle) * bird.y)
			# Nearer (lower on the ellipse) is bigger.
			var span: float = lerpf(11.0, 18.0, 0.5 + 0.5 * sin(angle))
			var beat: float = sin(_time * 9.0 + bird.w * 3.0)
			var tip := Vector2(span, -span * 0.5 * beat)
			var color := Color(0.12, 0.1, 0.12, 0.85)
			draw_polyline(PackedVector2Array([at + Vector2(-tip.x, tip.y), at + Vector2(-span * 0.35, -span * 0.15), at,
					at + Vector2(span * 0.35, -span * 0.15), at + tip]), color, 3.0, true)
