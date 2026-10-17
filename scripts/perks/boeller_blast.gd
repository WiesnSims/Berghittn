extends Node3D
## Böllerschuss (Marillenbrand): the look of a Schützen black-powder salute going off at the player's
## feet; the Handböller's shells burst with it too. A flash, a ring of grey powder smoke rolling
## outwards, sparks, and a shock ring on the floor. Built in code and gone after a few seconds; CPU
## particles because the web build is GLES3.

const LIFETIME: float = 3.0

## Metres the smoke and the shock ring reach; set before it enters the tree.
var radius: float = Constants.PERK_BOELLER_RADIUS


func _ready() -> void:
	add_child(_smoke(radius))
	add_child(_sparks())
	var ring := _shock_ring()
	add_child(ring)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 6.0
	flash.omni_range = radius * 2.0
	flash.position = Vector3.UP
	add_child(flash)
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "light_energy", 0.0, 0.35)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.45)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	# Deferred: whoever made it puts it in place right after adding it.
	_bang.call_deferred()


func _bang() -> void:
	Sound.play_at(&"boeller_bang", global_position)


func _smoke(radius: float) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.explosiveness = 0.95
	smoke.amount = 150
	smoke.lifetime = 2.4
	smoke.position = Vector3.UP * 0.4
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	smoke.emission_ring_axis = Vector3.UP
	smoke.emission_ring_radius = 0.6
	smoke.emission_ring_inner_radius = 0.3
	smoke.emission_ring_height = 0.4
	# Outwards along the floor, rising slowly as it slows down.
	smoke.direction = Vector3(1, 0.15, 0)
	smoke.spread = 180.0
	smoke.flatness = 0.85
	smoke.initial_velocity_min = radius * 1.6
	smoke.initial_velocity_max = radius * 2.2
	smoke.damping_min = radius * 1.4
	smoke.damping_max = radius * 1.8
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.6
	var grow := Curve.new()
	grow.max_value = 2.0
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.72, 0.68, 0.55))
	fade.set_color(1, Color(0.55, 0.53, 0.5, 0.0))
	smoke.color_ramp = fade
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	puff.material = material
	smoke.mesh = puff
	smoke.emitting = true
	return smoke


func _sparks() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 40
	sparks.lifetime = 0.6
	sparks.position = Vector3.UP * 0.6
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3(0, -12, 0)
	var spark := BoxMesh.new()
	spark.size = Vector3(0.04, 0.04, 0.04)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.75, 0.3)
	spark.material = material
	sparks.mesh = spark
	sparks.emitting = true
	return sparks


func _shock_ring() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.6, 0.8)
	ring.material_override = material
	ring.position = Vector3.UP * 0.15
	ring.scale = Vector3(0.3, 1.0, 0.3)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
