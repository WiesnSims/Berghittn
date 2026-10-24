class_name ScopeGlint
extends Node3D
## The glint off the Wilderer's scope while he aims (M9 part 5b): a bright star, the same size on
## screen near or far, pulsing faster as the shot comes, so a player can see where it comes from and
## when to take cover. Drawn over nothing it should not be (walls hide it). Hidden until shine().

# The star's texture, made once for every glint.
static var _texture: ImageTexture

## Warmup (ShaderWarmup): built and left showing.
var silent: bool = false

var _star: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.fixed_size = true
	_material.albedo_color = Color(1.0, 0.95, 0.75)
	_material.albedo_texture = _star_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	_star = MeshInstance3D.new()
	_star.mesh = quad
	_star.material_override = _material
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_star)
	visible = silent


## `share` of the aim gone (0..1): brighter and quicker towards the shot.
func shine(at: Vector3, share: float) -> void:
	visible = true
	global_position = at
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * lerpf(2.0, 7.0, share))
	_material.albedo_color.a = lerpf(0.55, 1.0, pulse)
	_star.scale = Vector3.ONE * lerpf(0.8, 1.4, pulse) * lerpf(1.0, 1.4, share)


## A four-pointed star with a soft middle, made once.
static func _star_texture() -> ImageTexture:
	if _texture:
		return _texture
	var size: int = 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = (size - 1) * 0.5
	for y: int in size:
		for x: int in size:
			var dx: float = absf(x - half) / half
			var dy: float = absf(y - half) / half
			var core: float = clampf(1.0 - sqrt(dx * dx + dy * dy) * 1.6, 0.0, 1.0)
			var rays: float = clampf(1.0 - dx * 6.0, 0.0, 1.0) * (1.0 - dy) + clampf(1.0 - dy * 6.0, 0.0, 1.0) * (1.0 - dx)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(core + rays, 0.0, 1.0)))
	_texture = ImageTexture.create_from_image(image)
	return _texture
