class_name Flames
## Flame particles shared by everything that burns (the Brennkessel's stream and puddles, burning
## enemies): additive billboards that rise, swell and go from yellow through orange to nothing.


## A flame emitter, not yet emitting: `amount` flames living `lifetime` seconds, each a quad of `size`.
## World-space particles, so they stay where they were set off.
static func particles(amount: int, lifetime: float, size: Vector2) -> CPUParticles3D:
	var fx := CPUParticles3D.new()
	fx.amount = amount
	fx.lifetime = lifetime
	fx.local_coords = false
	fx.emitting = false
	fx.direction = Vector3.UP
	fx.spread = 15.0
	fx.gravity = Vector3(0.0, 2.5, 0.0)
	fx.initial_velocity_min = 0.4
	fx.initial_velocity_max = 1.0
	fx.scale_amount_min = 0.7
	fx.scale_amount_max = 1.3
	fx.angle_min = -30.0
	fx.angle_max = 30.0
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.5))
	swell.add_point(Vector2(0.3, 1.0))
	swell.add_point(Vector2(1.0, 0.3))
	fx.scale_amount_curve = swell
	fx.color_ramp = ramp()
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material()
	fx.mesh = quad
	return fx


## Bright yellow at the root, orange, a dark red, then gone.
static func ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 0.92, 0.55, 0.95), Color(1.0, 0.55, 0.12, 0.85), Color(0.7, 0.15, 0.04, 0.45), Color(0.15, 0.05, 0.02, 0.0)])
	return gradient


## Additive, unshaded, facing the camera, coloured by the ramp; a soft round blob, not a square.
static func material() -> StandardMaterial3D:
	var flame := StandardMaterial3D.new()
	flame.albedo_texture = _soft_dot()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame.vertex_color_use_as_albedo = true
	flame.cull_mode = BaseMaterial3D.CULL_DISABLED
	return flame


static func _soft_dot() -> GradientTexture2D:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var dot := GradientTexture2D.new()
	dot.gradient = fade
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 32
	dot.height = 32
	return dot
