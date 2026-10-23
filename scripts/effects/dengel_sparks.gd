class_name DengelSparks
extends Node3D
## A spray of sparks off the anvil, one per hammer blow (M9 part 4). Pooled: burst() starts it again.

var _particles: CPUParticles3D


func _ready() -> void:
	_particles = CPUParticles3D.new()
	_particles.one_shot = true
	_particles.emitting = false
	_particles.amount = 28
	_particles.lifetime = 0.55
	_particles.explosiveness = 0.95
	_particles.direction = Vector3.UP
	_particles.spread = 75.0
	_particles.initial_velocity_min = 2.0
	_particles.initial_velocity_max = 4.5
	_particles.gravity = Vector3(0.0, -9.8, 0.0)
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.05, 0.012)
	_particles.mesh = mesh
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.75, 0.3)
	_particles.material_override = glow
	_particles.particle_flag_align_y = true
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


func burst() -> void:
	_particles.restart()
