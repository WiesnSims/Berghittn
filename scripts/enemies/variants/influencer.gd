extends EnemyVariant
## Da Influencer (Die Bsundan, 1.2): with a player INFLU_RANGE_MIN..MAX off in sight he stops, holds
## his selfie stick up and goes live for INFLU_LIVE_TIME: a red LIVE over his head, every other
## enemy within INFLU_RADIUS gets the Likes (faster), and every INFLU_FLASH_EVERY his ring light
## flashes, dazzling a player looking at him (each screen checks its own camera). Then
## INFLU_COOLDOWN as a plain Tourist.

## Live now (every screen: puppets get it by cue).
var live: bool = false
var live_left: float = 0.0
var cool_left: float = 0.0
var _hype_left: float = 0.0
var _flash_left: float = 0.0
var _label: Label3D
var _light: OmniLight3D
var _screen: ColorRect
var _screen_tween: Tween


func activated() -> void:
	super()
	live_left = 0.0
	cool_left = 0.0
	_set_live(false)


func tick(delta: float) -> void:
	cool_left -= delta
	if not live:
		return
	live_left -= delta
	if live_left <= 0.0 or not enemy.free_to_act():
		stop()
		return
	_hype_left -= delta
	if _hype_left <= 0.0:
		_hype_left = 0.25
		for other: Enemy in others():
			if not other.data.is_boss and other.global_position.distance_to(enemy.global_position) <= Constants.INFLU_RADIUS:
				other.hype(0.5)


func chase(delta: float) -> bool:
	var target: Node3D = enemy.target()
	if live:
		enemy.hold(target.global_position, delta)
		return true
	if cool_left > 0.0 or not enemy.is_on_floor():
		return false
	var offset: Vector3 = target.global_position - enemy.global_position
	var distance: float = Vector2(offset.x, offset.z).length()
	if distance < Constants.INFLU_RANGE_MIN or distance > Constants.INFLU_RANGE_MAX:
		return false
	if not clear(enemy.mouth(), target.global_position + Vector3.UP * 1.4):
		return false
	go_live()
	enemy.hold(target.global_position, delta)
	return true


## On air (also used by tests).
func go_live() -> void:
	live_left = Constants.INFLU_LIVE_TIME
	_hype_left = 0.0
	enemy.pose(EnemyRig.Action.AIM, Constants.INFLU_LIVE_TIME)
	Gredn.now(enemy, Gredn.Moment.LIVE)
	signal_cue(&"live", true)


## Off air: back to a plain Tourist for a while.
func stop() -> void:
	cool_left = Constants.INFLU_COOLDOWN
	if enemy.rig() and enemy.rig().action() == EnemyRig.Action.AIM:
		enemy.pose(EnemyRig.Action.NONE)
	signal_cue(&"live", false)


func died(_source: Node3D) -> void:
	_set_live(false)


func show_cue(cue: StringName, arg: Variant) -> void:
	if cue == &"live":
		_set_live(arg)


func _set_live(on: bool) -> void:
	live = on
	_flash_left = Constants.INFLU_FLASH_EVERY * 0.5
	if on and _label == null:
		_build()
	if _label:
		_label.visible = on
		_light.visible = on


func _process(delta: float) -> void:
	if not live or not enemy.is_alive():
		return
	var lens: Vector3 = enemy.mouth()
	if enemy.rig():
		lens = enemy.rig().point_on(&"hand_r", Constants.INFLU_LIGHT_POINT * enemy.rig().build_scale)
	_light.global_position = lens
	_label.global_position = enemy.global_position + Vector3.UP * 2.35 * enemy.data.model_scale
	_light.light_energy = move_toward(_light.light_energy, 1.0, delta * 12.0)
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash_left = Constants.INFLU_FLASH_EVERY
		_light.light_energy = 8.0
		Sound.play_at(&"camera", lens)
		if dazzles(get_viewport().get_camera_3d(), lens):
			_dazzle()


## Whether a flash at `lens` dazzles whoever looks through `camera`: near enough, looked at, seen.
func dazzles(camera: Camera3D, lens: Vector3) -> bool:
	if camera == null:
		return false
	var to: Vector3 = lens - camera.global_position
	if to.length() > Constants.INFLU_RANGE_MAX or to.length() < 0.01:
		return false
	if rad_to_deg((-camera.global_basis.z).angle_to(to)) > Constants.INFLU_FLASH_ANGLE:
		return false
	return clear(camera.global_position, lens)


## White over this screen, fading.
func _dazzle() -> void:
	if _screen == null:
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_screen = ColorRect.new()
		_screen.color = Color.WHITE
		_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_screen)
	if _screen_tween:
		_screen_tween.kill()
	_screen.modulate.a = Constants.INFLU_FLASH_ALPHA
	_screen_tween = create_tween()
	_screen_tween.tween_property(_screen, "modulate:a", 0.0, Constants.INFLU_FLASH_TIME).set_ease(Tween.EASE_IN)


## The red LIVE over his head (also drawn by the shader warm-up).
static func live_label() -> Label3D:
	var label := Label3D.new()
	label.top_level = true
	label.text = "● LIVE"
	label.modulate = Color(1.0, 0.2, 0.2)
	label.outline_modulate = Color(0.1, 0.0, 0.0)
	label.outline_size = 10
	label.font_size = 64
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label


## How white this screen is now (tests).
func dazzled() -> float:
	return _screen.modulate.a if _screen else 0.0


func _build() -> void:
	_label = live_label()
	add_child(_label)
	_light = OmniLight3D.new()
	_light.top_level = true
	_light.light_color = Color(1.0, 0.95, 0.9)
	_light.omni_range = 4.0
	_light.light_energy = 1.0
	add_child(_light)
